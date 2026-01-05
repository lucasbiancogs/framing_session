import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'canvas_vm.dart';
import 'models/edit_intent.dart';
import 'models/edit_operation.dart';
import 'painters/whiteboard_painter.dart';
import 'shapes/canvas_shape.dart';

/// The main whiteboard canvas widget.
///
/// Architecture principles:
/// - Canvas handles input, not logic
/// - Canvas receives pointer events
/// - Canvas performs hit testing (via CanvasShape.hitTest)
/// - Canvas detects edit intent (via CanvasShape.getEditIntent)
/// - Canvas emits semantic operations
///
/// No shape is a Flutter widget. All shapes are drawn in a single CustomPainter.
/// Gestures are handled centrally — there are no gesture detectors per shape.
class WhiteboardCanvas extends ConsumerStatefulWidget {
  const WhiteboardCanvas({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  // Gesture tracking state
  String? _activeShapeId;
  EditIntent? _activeIntent;
  Offset? _lastPointerPosition;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(canvasVM(widget.sessionId));

    if (state is! CanvasLoaded) {
      return const SizedBox.shrink();
    }

    return Listener(
      onPointerDown: (event) => _handlePointerDown(event, state),
      onPointerMove: (event) => _handlePointerMove(event, state),
      onPointerUp: (event) => _handlePointerUp(event, state),
      onPointerCancel: (event) => _handlePointerUp(event, state),
      child: GestureDetector(
        // Double-tap to create shape
        onDoubleTapDown: (details) => _handleDoubleTap(details, state),
        child: CustomPaint(
          painter: WhiteboardPainter(
            shapes: state.shapes,
            selectedShapeId: state.selectedShapeId,
            panOffset: state.panOffset,
            zoom: state.zoom,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pointer Event Handlers
  // ---------------------------------------------------------------------------

  void _handlePointerDown(PointerDownEvent event, CanvasLoaded state) {
    final position = _toCanvasPosition(event.localPosition, state);

    // Hit test shapes using CanvasShape (top-down, last shape is on top)
    for (final shape in state.shapes.reversed) {
      final canvasShape = createCanvasShape(shape);
      final intent = canvasShape.getEditIntent(position);

      if (intent != null) {
        _activeShapeId = shape.id;
        _activeIntent = intent;
        _lastPointerPosition = position;

        // Select the shape
        ref.read(canvasVM(widget.sessionId).notifier).selectShape(shape.id);
        return;
      }
    }

    // Clicked on empty space — deselect
    _activeShapeId = null;
    _activeIntent = null;
    _lastPointerPosition = null;
    ref.read(canvasVM(widget.sessionId).notifier).selectShape(null);
  }

  void _handlePointerMove(PointerMoveEvent event, CanvasLoaded state) {
    if (_activeShapeId == null || _activeIntent == null) return;

    final position = _toCanvasPosition(event.localPosition, state);
    final delta = position - (_lastPointerPosition ?? position);
    _lastPointerPosition = position;

    // Convert intent + delta to operation
    final operation = _createOperation(
      shapeId: _activeShapeId!,
      intent: _activeIntent!,
      delta: delta,
    );

    if (operation != null) {
      ref.read(canvasVM(widget.sessionId).notifier).applyOperation(operation);
    }
  }

  void _handlePointerUp(PointerEvent event, CanvasLoaded state) {
    _activeShapeId = null;
    _activeIntent = null;
    _lastPointerPosition = null;
  }

  void _handleDoubleTap(TapDownDetails details, CanvasLoaded state) {
    final position = _toCanvasPosition(details.localPosition, state);
    final tool = state.currentTool;

    if (tool == CanvasTool.select) return;

    // Create shape at position
    ref
        .read(canvasVM(widget.sessionId).notifier)
        .createShapeAt(position: position, tool: tool);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convert screen position to canvas position (accounting for pan/zoom).
  Offset _toCanvasPosition(Offset screenPosition, CanvasLoaded state) {
    return (screenPosition - state.panOffset) / state.zoom;
  }

  /// Create an operation from an intent and delta.
  EditOperation? _createOperation({
    required String shapeId,
    required EditIntent intent,
    required Offset delta,
  }) {
    final opId = const Uuid().v4();

    return switch (intent) {
      MoveIntent() => MoveOperation(opId: opId, shapeId: shapeId, delta: delta),
      ResizeIntent(:final handle) => ResizeOperation(
        opId: opId,
        shapeId: shapeId,
        handle: handle,
        delta: delta,
      ),
      RotateIntent() => null, // TODO: Implement rotation
    };
  }
}
