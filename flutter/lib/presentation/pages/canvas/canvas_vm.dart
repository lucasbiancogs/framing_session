import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/base_exception.dart';
import '../../../domain/entities/shape.dart';
import '../../../domain/entities/shape_type.dart';
import '../../../domain/services/shape_services.dart';
import '../../view_models/global_providers.dart';
import 'models/edit_intent.dart';
import 'models/edit_operation.dart';

// =============================================================================
// Canvas State
// =============================================================================

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

  /// All shapes in the session (shared state — will come from DB later).
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

// =============================================================================
// Canvas Tool
// =============================================================================

/// Available tools for the canvas.
enum CanvasTool { select, rectangle, circle, triangle, text }

// =============================================================================
// Canvas ViewModel
// =============================================================================
//
// Architecture: ViewModel is the single source of truth.
// - Owns all shape state
// - Applies operations (immutable updates)
// - Emits updated state
// - Used by both local and remote updates
//
// Operations, not state, are broadcast. State is derived, not sent.
// =============================================================================

final canvasVM = StateNotifierProvider.autoDispose
    .family<CanvasVM, CanvasState, String>(
      (ref, sessionId) => CanvasVM(ref.watch(shapeServices), sessionId),
      name: 'canvasVM',
      dependencies: [shapeServices],
    );

class CanvasVM extends StateNotifier<CanvasState> {
  CanvasVM(this._shapeServices, this.sessionId) : super(const CanvasLoading()) {
    _loadShapes();
  }

  final ShapeServices _shapeServices;
  final String sessionId;

  /// Set of applied operation IDs (for deduplication).
  final Set<String> _appliedOpIds = {};

  // Type-safe state accessor
  CanvasLoaded get _loadedState => state as CanvasLoaded;

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
  // Both local gestures and remote updates go through here.
  //
  // This ensures:
  // - Deterministic updates
  // - Same code path for local and remote
  // - Replayable operations
  // ---------------------------------------------------------------------------

  /// Apply an operation to the shape state.
  ///
  /// This is the single entry point for all shape mutations.
  /// Operations are applied immutably — shapes are never mutated in place.
  void applyOperation(EditOperation operation) {
    if (state is! CanvasLoaded) return;

    // Deduplicate operations (for when server echoes back our own ops)
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

    // TODO: In later phases, broadcast the operation to other clients
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

  // ---------------------------------------------------------------------------
  // Shape Creation
  // ---------------------------------------------------------------------------

  /// Create a new shape at the given position using the current tool.
  void createShapeAt({
    required Offset position,
    required CanvasTool tool,
    double width = 100,
    double height = 100,
    String color = '#4ED09A',
  }) {
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

    // Add shape to state
    state = _loadedState.copyWith(
      shapes: [..._loadedState.shapes, shape],
      selectedShapeId: shape.id,
    );

    // TODO: Persist to service and broadcast CreateOperation
  }

  /// Delete the currently selected shape.
  void deleteSelectedShape() {
    if (state is! CanvasLoaded) return;

    final shapeId = _loadedState.selectedShapeId;
    if (shapeId == null) return;

    final operation = DeleteOperation(
      opId: const Uuid().v4(),
      shapeId: shapeId,
    );

    applyOperation(operation);
    selectShape(null);

    // TODO: Persist to service
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
