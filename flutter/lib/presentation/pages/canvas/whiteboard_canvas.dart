import 'dart:ui' show Offset;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'canvas_vm.dart';
import 'models/edit_intent.dart';
import 'models/edit_operation.dart';
import 'painters/whiteboard_painter.dart';
import 'models/canvas_shape.dart';

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
  SystemMouseCursor? _hoverCursor;

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
        child: MouseRegion(
          cursor: _hoverCursor ?? SystemMouseCursors.basic,
          onHover: (event) => _handlePointerHover(event, state),
          child: CustomPaint(
            painter: WhiteboardPainter(
              shapes: state.shapes.map(createCanvasShape).toList(),
              selectedShapeId: state.selectedShapeId,
              panOffset: state.panOffset,
              zoom: state.zoom,
            ),
            size: Size.infinite,
          ),
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
    // TODO(lucasbiancogs): Revisit this creation process
    final position = _toCanvasPosition(details.localPosition, state);
    final tool = state.currentTool;

    if (tool == CanvasTool.select) return;

    // Create shape at position
    ref
        .read(canvasVM(widget.sessionId).notifier)
        .createShapeAt(position: position, tool: tool);
  }

  void _handlePointerHover(PointerHoverEvent event, CanvasLoaded state) {
    final position = _toCanvasPosition(event.localPosition, state);

    for (final shape in state.shapes.reversed) {
      final canvasShape = createCanvasShape(shape);
      final intent = canvasShape.getEditIntent(position);

      if (intent != null) {
        final newCursor = switch (intent) {
          final ResizeIntent intent => intent.handle.systemMouseCursor,
          _ => SystemMouseCursors.basic,
        };

        if (newCursor != _hoverCursor) {
          setState(() {
            _hoverCursor = newCursor;
          });
        }

        return;
      }
    }

    if (_hoverCursor != null) {
      setState(() {
        _hoverCursor = null;
      });
    }
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
      RotateIntent() => null,
    };
  }
}

extension on ResizeHandle {
  SystemMouseCursor get systemMouseCursor {
    return switch (this) {
      ResizeHandle.centerLeft ||
      ResizeHandle.centerRight => SystemMouseCursors.resizeLeftRight,
      ResizeHandle.topLeft ||
      ResizeHandle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
      ResizeHandle.topCenter ||
      ResizeHandle.bottomCenter => SystemMouseCursors.resizeUpDown,
      ResizeHandle.topRight ||
      ResizeHandle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
    };
  }
}
