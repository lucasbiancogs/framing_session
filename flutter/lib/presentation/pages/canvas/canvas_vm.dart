import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';

import '../../../core/errors/base_faults.dart';
import '../../../core/utils/debouncer.dart';
import '../../../domain/entities/shape.dart';
import '../../../domain/entities/shape_type.dart';
import '../../../domain/services/shape_services.dart';
import '../../view_models/global_providers.dart';
import 'models/edit_intent.dart';
import 'models/edit_operation.dart';

final canvasVM = StateNotifierProvider.autoDispose<CanvasVM, CanvasState>(
  (ref) => CanvasVM(ref.watch(shapeServices), ref.watch(sessionIdProvider)),
  name: 'canvasVM',
  dependencies: [shapeServices, sessionIdProvider],
);

@immutable
abstract class CanvasState extends Equatable {
  const CanvasState();

  @override
  List<Object?> get props => [];
}

class CanvasLoading extends CanvasState {
  const CanvasLoading();
}

class CanvasLoaded extends CanvasState {
  const CanvasLoaded({
    required this.shapes,
    this.selectedShapeId,
    this.isEditingText = false,
    this.panOffset = Offset.zero,
    this.zoom = 1.0,
    this.currentTool = CanvasTool.select,
  });

  /// All shapes in the session.
  final List<Shape> shapes;

  /// Currently selected shape ID.
  final String? selectedShapeId;

  /// Whether the selected shape's text is being edited (shows TextField overlay).
  final bool isEditingText;

  // --- Local state (UI-only, not persisted) ---

  /// Current pan offset of the canvas.
  final Offset panOffset;

  /// Current zoom level (1.0 = 100%).
  final double zoom;

  /// Currently selected drawing tool.
  final CanvasTool currentTool;

  @override
  List<Object?> get props => [
    shapes,
    selectedShapeId,
    isEditingText,
    panOffset,
    zoom,
    currentTool,
  ];

  CanvasPersistError toPersistError(BaseException exception) {
    return CanvasPersistError(
      exception: exception,
      shapes: shapes,
      selectedShapeId: selectedShapeId,
      isEditingText: isEditingText,
      panOffset: panOffset,
      zoom: zoom,
      currentTool: currentTool,
    );
  }

  CanvasLoaded copyWith({
    List<Shape>? shapes,
    String? selectedShapeId,
    bool? isEditingText,
    Offset? panOffset,
    double? zoom,
    CanvasTool? currentTool,
    bool clearSelection = false,
  }) {
    return CanvasLoaded(
      shapes: shapes ?? this.shapes,
      selectedShapeId: clearSelection
          ? null
          : (selectedShapeId ?? this.selectedShapeId),
      isEditingText: clearSelection
          ? false
          : (isEditingText ?? this.isEditingText),
      panOffset: panOffset ?? this.panOffset,
      zoom: zoom ?? this.zoom,
      currentTool: currentTool ?? this.currentTool,
    );
  }

  /// Get the currently selected shape (if any).
  Shape? get selectedShape => selectedShapeId != null
      ? shapes.cast<Shape?>().firstWhere(
          (s) => s?.id == selectedShapeId,
          orElse: () => null,
        )
      : null;
}

class CanvasError extends CanvasState {
  const CanvasError(this.exception);

  final BaseException exception;

  @override
  List<Object?> get props => [exception];
}

class CanvasPersistError extends CanvasLoaded {
  const CanvasPersistError({
    required this.exception,
    required super.shapes,
    super.selectedShapeId,
    super.isEditingText,
    super.panOffset,
    super.zoom,
    super.currentTool,
  });

  final BaseException exception;

  @override
  List<Object?> get props => [exception, ...super.props];
}

/// Available tools for the canvas.
enum CanvasTool { select, rectangle, circle, triangle, text }

class CanvasVM extends StateNotifier<CanvasState> {
  CanvasVM(this._shapeServices, this.sessionId) : super(const CanvasLoading()) {
    _loadShapes();
  }

  final ShapeServices _shapeServices;
  final String sessionId;

  /// Set of applied operation IDs (for deduplication).
  final Set<String> _appliedOpIds = {};

  /// Debouncer for update operations (move, resize, rotate, text).
  final Debouncer _updateDebouncer = Debouncer(
    duration: const Duration(milliseconds: 300),
  );

  /// Shape pending persistence after debounce.
  Shape? _pendingShape;

  // Type-safe state accessor
  CanvasLoaded get _loadedState => state as CanvasLoaded;

  // ---------------------------------------------------------------------------
  // Initialization & Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _updateDebouncer.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadShapes() async {
    final result = await _shapeServices.getSessionShapes(sessionId);

    result.fold(
      (exception) => state = CanvasError(exception),
      (shapes) => state = CanvasLoaded(shapes: shapes),
    );
  }

  Future<void> retryLoading() async {
    state = const CanvasLoading();
    await _loadShapes();
  }

  // ---------------------------------------------------------------------------
  // Local State (UI only)
  // ---------------------------------------------------------------------------

  /// Select a shape by ID.
  void selectShape(String? shapeId) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(
      selectedShapeId: shapeId,
      clearSelection: shapeId == null,
    );
  }

  /// Change the current tool.
  void setTool(CanvasTool tool) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(currentTool: tool);
  }

  /// Update pan offset.
  void setPanOffset(Offset offset) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(panOffset: offset);
  }

  /// Update zoom level.
  void setZoom(double zoom) {
    if (state is! CanvasLoaded) return;

    // Clamp zoom between 25% and 400%
    final clampedZoom = zoom.clamp(0.25, 4.0);
    state = _loadedState.copyWith(zoom: clampedZoom);
  }

  // ---------------------------------------------------------------------------
  // Text Editing
  // ---------------------------------------------------------------------------

  /// Start editing text for the currently selected shape.
  void startTextEdit(String shapeId) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(
      selectedShapeId: shapeId,
      isEditingText: true,
    );
  }

  /// Stop editing text (commit current text).
  void stopTextEdit() {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(isEditingText: false);
  }

  /// Update the text of a shape.
  void updateShapeText(String shapeId, String text) {
    if (state is! CanvasLoaded) return;

    final operation = TextEditOperation(
      opId: const Uuid().v4(),
      shapeId: shapeId,
      text: text,
    );

    applyOperation(operation);
  }

  // ---------------------------------------------------------------------------
  // Operation Application (Core of the architecture)
  // ---------------------------------------------------------------------------
  //
  // applyOperation is the SINGLE entry point for all shape mutations.
  //
  // This ensures:
  // - Deterministic updates
  // - Replayable operations
  // ---------------------------------------------------------------------------

  /// Apply an operation to the shape state.
  ///
  /// This is the single entry point for all shape mutations.
  /// Operations are applied immutably — shapes are never mutated in place.
  void applyOperation(EditOperation operation) {
    if (state is! CanvasLoaded) return;

    // Deduplicate operations
    if (_appliedOpIds.contains(operation.opId)) return;
    _appliedOpIds.add(operation.opId);

    final newShapes = switch (operation) {
      MoveOperation(:final shapeId, :final delta) => _applyMove(shapeId, delta),
      ResizeOperation(:final shapeId, :final handle, :final delta) =>
        _applyResize(shapeId, handle, delta),
      RotateOperation(:final shapeId, :final angleDelta) => _applyRotate(
        shapeId,
        angleDelta,
      ),
      TextEditOperation(:final shapeId, :final text) => _applyTextEdit(
        shapeId,
        text,
      ),
      CreateOperation() => _loadedState.shapes, // Create is handled separately
      DeleteOperation(:final shapeId) =>
        _loadedState.shapes.where((s) => s.id != shapeId).toList(),
    };

    state = _loadedState.copyWith(shapes: newShapes);

    // Schedule debounced persistence for update operations
    _scheduleDebouncedPersist(operation);
  }

  /// Schedule debounced persistence for update operations.
  void _scheduleDebouncedPersist(EditOperation operation) {
    // Only debounce move, resize, rotate, and text operations
    final shapeId = switch (operation) {
      MoveOperation(:final shapeId) => shapeId,
      ResizeOperation(:final shapeId) => shapeId,
      RotateOperation(:final shapeId) => shapeId,
      TextEditOperation(:final shapeId) => shapeId,
      _ => null,
    };

    if (shapeId == null) return;

    // Find the current shape state
    final shape = _loadedState.shapes.firstWhere(
      (s) => s.id == shapeId,
      orElse: () => throw StateError('Shape not found: $shapeId'),
    );

    _pendingShape = shape;

    _updateDebouncer.run(() {
      _persistPendingShape();
    });
  }

  /// Persist the pending shape after debounce delay.
  Future<void> _persistPendingShape() async {
    final shape = _pendingShape;
    if (shape == null) return;

    _pendingShape = null;

    final result = await _shapeServices.updateShape(shape);

    result.fold((exception) {
      state = _loadedState.toPersistError(exception);
    }, (_) {});
  }

  List<Shape> _applyMove(String shapeId, Offset delta) {
    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.copyWith(x: shape.x + delta.dx, y: shape.y + delta.dy);
    }).toList();
  }

  List<Shape> _applyResize(String shapeId, ResizeHandle handle, Offset delta) {
    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      var newX = shape.x;
      var newY = shape.y;
      var newWidth = shape.width;
      var newHeight = shape.height;

      // Apply delta based on which handle is being dragged
      switch (handle) {
        case ResizeHandle.topLeft:
          newX += delta.dx;
          newY += delta.dy;
          newWidth -= delta.dx;
          newHeight -= delta.dy;
        case ResizeHandle.topCenter:
          newY += delta.dy;
          newHeight -= delta.dy;
        case ResizeHandle.topRight:
          newY += delta.dy;
          newWidth += delta.dx;
          newHeight -= delta.dy;
        case ResizeHandle.centerLeft:
          newX += delta.dx;
          newWidth -= delta.dx;
        case ResizeHandle.centerRight:
          newWidth += delta.dx;
        case ResizeHandle.bottomLeft:
          newX += delta.dx;
          newWidth -= delta.dx;
          newHeight += delta.dy;
        case ResizeHandle.bottomCenter:
          newHeight += delta.dy;
        case ResizeHandle.bottomRight:
          newWidth += delta.dx;
          newHeight += delta.dy;
      }

      // Enforce minimum size
      const minSize = 20.0;
      if (newWidth < minSize) {
        newWidth = minSize;
        if (handle == ResizeHandle.topLeft ||
            handle == ResizeHandle.centerLeft ||
            handle == ResizeHandle.bottomLeft) {
          newX = shape.x + shape.width - minSize;
        }
      }
      if (newHeight < minSize) {
        newHeight = minSize;
        if (handle == ResizeHandle.topLeft ||
            handle == ResizeHandle.topCenter ||
            handle == ResizeHandle.topRight) {
          newY = shape.y + shape.height - minSize;
        }
      }

      return shape.copyWith(
        x: newX,
        y: newY,
        width: newWidth,
        height: newHeight,
      );
    }).toList();
  }

  List<Shape> _applyRotate(String shapeId, double angleDelta) {
    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.copyWith(rotation: shape.rotation + angleDelta);
    }).toList();
  }

  List<Shape> _applyTextEdit(String shapeId, String text) {
    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.copyWith(text: text);
    }).toList();
  }

  /// Create a new shape at the given position using the current tool.
  Future<void> createShapeAt({
    required Offset position,
    required CanvasTool tool,
    double width = 100,
    double height = 100,
    String color = '#4ED09A',
  }) async {
    if (state is! CanvasLoaded) return;

    final shapeType = _toolToShapeType(tool);
    if (shapeType == null) return;

    final shape = Shape(
      id: const Uuid().v4(),
      sessionId: sessionId,
      shapeType: shapeType,
      x: position.dx - width / 2, // Center on tap
      y: position.dy - height / 2,
      width: width,
      height: height,
      color: color,
      rotation: 0,
    );

    state = _loadedState.copyWith(
      shapes: [..._loadedState.shapes, shape],
      selectedShapeId: shape.id,
    );

    final result = await _shapeServices.createShape(shape);

    result.fold((exception) {
      state = _loadedState.toPersistError(exception);
    }, (_) {});
  }

  /// Delete the currently selected shape.
  Future<void> deleteSelectedShape() async {
    if (state is! CanvasLoaded) return;

    final shapeId = _loadedState.selectedShapeId;
    if (shapeId == null) return;

    final operation = DeleteOperation(
      opId: const Uuid().v4(),
      shapeId: shapeId,
    );

    applyOperation(operation);
    selectShape(null);

    final result = await _shapeServices.deleteShape(shapeId);

    result.fold((exception) {
      state = _loadedState.toPersistError(exception);
    }, (_) {});
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ShapeType? _toolToShapeType(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.rectangle => ShapeType.rectangle,
      CanvasTool.circle => ShapeType.circle,
      CanvasTool.triangle => ShapeType.triangle,
      CanvasTool.text => ShapeType.text,
      CanvasTool.select => null,
    };
  }
}
