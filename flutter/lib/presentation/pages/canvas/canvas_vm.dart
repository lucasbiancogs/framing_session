import 'dart:ui' show Offset, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_shape.dart';

import '../../../core/errors/base_faults.dart';
import '../../../core/utils/debouncer.dart';
import '../../../domain/entities/shape.dart';
import '../../../domain/entities/shape_type.dart';
import '../../../domain/services/shape_services.dart';
import '../../view_models/global_providers.dart';
import 'models/canvas_operation.dart';

final canvasVM = StateNotifierProvider.autoDispose<CanvasVM, CanvasState>(
  (ref) => CanvasVM(ref.watch(shapeServices), ref.watch(sessionIdProvider)),
  name: 'canvasVM',
  dependencies: [shapeServices, canvasServices, sessionIdProvider],
);

/// Available tools for the canvas.
enum CanvasTool { select, rectangle, circle, triangle, text }

class CanvasVM extends StateNotifier<CanvasState> {
  CanvasVM(this._shapeServices, this._sessionId)
    : super(const CanvasLoading()) {
    _loadShapes();
  }

  final ShapeServices _shapeServices;
  final String _sessionId;

  final double gridSize = 20.0;
  final double initialShapeSize = 150.0;

  /// Set of applied operation IDs (for deduplication).
  final Set<String> _appliedOpIds = {};

  /// Debouncer for update operations (move, resize, rotate, text).
  final Debouncer _updateDebouncer = Debouncer(
    duration: const Duration(milliseconds: 300),
  );

  /// Shape pending persistence after debounce.
  CanvasShape? _pendingShape;

  // Type-safe state accessor
  CanvasLoaded get _loadedState => state as CanvasLoaded;

  @override
  void dispose() {
    _updateDebouncer.cancel();
    super.dispose();
  }

  Future<void> _loadShapes() async {
    final result = await _shapeServices.getSessionShapes(_sessionId);

    result.fold(
      (exception) => state = CanvasError(exception),
      (shapes) => state = CanvasLoaded(
        shapes: shapes.map(CanvasShape.createCanvasShape).toList(),
      ),
    );
  }

  Future<void> retryLoading() async {
    state = const CanvasLoading();
    await _loadShapes();
  }

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

  /// Set the current color for new shapes.
  void setColor(String color) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(currentColor: color);
  }

  /// Toggle snap-to-grid mode.
  void toggleSnapToGrid() {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(snapToGrid: !_loadedState.snapToGrid);
  }

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
  void applyOperation(CanvasOperation operation) {
    if (state is! CanvasLoaded) return;

    // Deduplicate operations
    if (_appliedOpIds.contains(operation.opId)) return;
    _appliedOpIds.add(operation.opId);

    final newShapes = switch (operation) {
      MoveShapeOperation(:final shapeId, :final position) => _applyMove(
        shapeId,
        position,
      ),
      ResizeShapeOperation(:final shapeId, :final bounds) => _applyResize(
        shapeId,
        bounds,
      ),
      TextShapeOperation(:final shapeId, :final text) => _applyTextEdit(
        shapeId,
        text,
      ),
      CreateShapeOperation() => _applyCreate(operation),
      DeleteShapeOperation(:final shapeId) => _applyDelete(shapeId),
    };

    state = _loadedState.copyWith(shapes: newShapes);

    // Schedule debounced persistence for update operations
    _scheduleDebouncedPersist(operation);
  }

  /// Schedule debounced persistence for update operations.
  void _scheduleDebouncedPersist(CanvasOperation operation) {
    switch (operation) {
      case CreateShapeOperation():
        final shape = _loadedState.shapes.firstWhere(
          (s) => s.id == operation.shapeId,
          orElse: () =>
              throw StateError('Shape not found: ${operation.shapeId}'),
        );
        _shapeServices.createShape(shape.entity);
        return;
      case DeleteShapeOperation():
        _shapeServices.deleteShape(operation.shapeId);
        return;
      default:
        break;
    }

    // Only debounce move, resize, rotate, and text operations
    final shapeId = switch (operation) {
      MoveShapeOperation(:final shapeId) => shapeId,
      ResizeShapeOperation(:final shapeId) => shapeId,
      TextShapeOperation(:final shapeId) => shapeId,
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

    final result = await _shapeServices.updateShape(shape.entity);

    result.fold((exception) {
      state = _loadedState.toPersistError(exception);
    }, (_) {});
  }

  // ---------------------------------------------------------------------------
  // Snap-to-grid helpers
  // ---------------------------------------------------------------------------

  /// Snap a value to the nearest grid point.
  double _snapValue(double value) {
    return (value / gridSize).round() * gridSize;
  }

  /// Snap an offset to the grid.
  Offset _snapOffset(Offset offset) {
    return Offset(_snapValue(offset.dx), _snapValue(offset.dy));
  }

  /// Snap a rect to the grid.
  Rect _snapRect(Rect rect) {
    return Rect.fromLTRB(
      _snapValue(rect.left),
      _snapValue(rect.top),
      _snapValue(rect.right),
      _snapValue(rect.bottom),
    );
  }

  // ---------------------------------------------------------------------------
  // Operation application helpers
  // ---------------------------------------------------------------------------

  List<CanvasShape> _applyMove(String shapeId, Offset position) {
    final snappedPosition = _loadedState.snapToGrid
        ? _snapOffset(position)
        : position;

    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.applyMove(snappedPosition);
    }).toList();
  }

  List<CanvasShape> _applyResize(String shapeId, Rect bounds) {
    final snappedBounds = _loadedState.snapToGrid ? _snapRect(bounds) : bounds;

    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.applyResize(snappedBounds);
    }).toList();
  }

  List<CanvasShape> _applyTextEdit(String shapeId, String text) {
    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.copyWith(text: text);
    }).toList();
  }

  List<CanvasShape> _applyCreate(CreateShapeOperation operation) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final shape = Shape(
      id: operation.shapeId,
      sessionId: _sessionId,
      shapeType: operation.shapeType,
      x: operation.x,
      y: operation.y,
      width: initialShapeSize,
      height: initialShapeSize,
      color: operation.color,
      rotation: 0,
    );

    final canvasShape = CanvasShape.createCanvasShape(shape);

    return [..._loadedState.shapes, canvasShape];
  }

  /// Delete the currently selected shape.
  List<CanvasShape> _applyDelete(String shapeId) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final newShapes = _loadedState.shapes
        .where((s) => s.id != shapeId)
        .toList();

    selectShape(null);

    state = _loadedState.copyWith(shapes: newShapes);

    return newShapes;
  }

  ShapeType? toolToShapeType(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.rectangle => ShapeType.rectangle,
      CanvasTool.circle => ShapeType.circle,
      CanvasTool.triangle => ShapeType.triangle,
      CanvasTool.text => ShapeType.text,
      CanvasTool.select => null,
    };
  }
}

@immutable
sealed class CanvasState extends Equatable {
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
    this.currentColor = '#4ED09A',
    this.snapToGrid = false,
  });

  /// All shapes in the session.
  final List<CanvasShape> shapes;

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

  /// Currently selected color for new shapes.
  final String currentColor;

  /// Whether snap-to-grid is enabled.
  final bool snapToGrid;

  @override
  List<Object?> get props => [
    shapes,
    selectedShapeId,
    isEditingText,
    panOffset,
    zoom,
    currentTool,
    currentColor,
    snapToGrid,
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
      currentColor: currentColor,
      snapToGrid: snapToGrid,
    );
  }

  CanvasLoaded copyWith({
    List<CanvasShape>? shapes,
    String? selectedShapeId,
    bool? isEditingText,
    Offset? panOffset,
    double? zoom,
    CanvasTool? currentTool,
    String? currentColor,
    bool? snapToGrid,
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
      currentColor: currentColor ?? this.currentColor,
      snapToGrid: snapToGrid ?? this.snapToGrid,
    );
  }

  /// Get the currently selected shape (if any).
  CanvasShape? get selectedShape => selectedShapeId != null
      ? shapes.firstWhere((s) => s.id == selectedShapeId)
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
    super.currentColor,
    super.snapToGrid,
  });

  final BaseException exception;

  @override
  List<Object?> get props => [exception, ...super.props];
}
