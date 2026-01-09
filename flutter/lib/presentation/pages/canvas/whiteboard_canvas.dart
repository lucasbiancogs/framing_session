import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/presentation/pages/canvas/painters/cursors_painter.dart';

import '../../../domain/entities/shape.dart';
import 'canvas_vm.dart';
import 'collaborative_canvas_vm.dart';
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
  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  // Gesture tracking state
  String? _activeShapeId;
  EditIntent? _activeIntent;
  Offset? _lastPointerPosition;
  SystemMouseCursor? _hoverCursor;

  // Text editing
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  CanvasVM get vm => ref.watch(canvasVM.notifier);
  CollaborativeCanvasVM get collaborativeVm =>
      ref.watch(collaborativeCanvasVM.notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(canvasVM);
    final collaborativeState = ref.watch(collaborativeCanvasVM);

    if (state is! CanvasLoaded) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Listener(
          onPointerDown: (event) =>
              _handlePointerDown(event.localPosition, state),
          onPointerMove: (event) =>
              _handlePointerMove(event.localPosition, state),
          onPointerUp: (event) => _handlePointerUp(event.localPosition, state),
          onPointerCancel: (event) =>
              _handlePointerUp(event.localPosition, state),
          child: GestureDetector(
            // Double-tap to create shape or edit text
            onDoubleTapDown: (details) =>
                _handleDoubleTap(details.localPosition, state),
            child: MouseRegion(
              cursor: _hoverCursor ?? SystemMouseCursors.basic,
              onHover: (event) =>
                  _handlePointerHover(event.localPosition, state),
              child: CustomPaint(
                painter: WhiteboardPainter(
                  shapes: state.shapes,
                  selectedShapeId: state.selectedShapeId,
                  isEditingText: state.isEditingText,
                  panOffset: state.panOffset,
                  zoom: state.zoom,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),

        if (collaborativeState is CollaborativeCanvasLoaded)
          CustomPaint(
            painter: CursorsPainter(
              cursors: collaborativeState.cursors,
              panOffset: state.panOffset,
              zoom: state.zoom,
            ),
          ),

        // Text editing overlay
        if (state.isEditingText && state.selectedShape != null)
          _buildTextEditingOverlay(state, state.selectedShape!),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pointer Event Handlers
  // ---------------------------------------------------------------------------

  void _handlePointerDown(Offset screenPosition, CanvasLoaded state) {
    final position = _toCanvasPosition(screenPosition, state);

    collaborativeVm.broadcastCursor(position);

    // If currently editing text, stop editing when clicking elsewhere
    if (state.isEditingText) {
      vm.stopTextEdit();
    }

    // Hit test shapes using CanvasShape (top-down, last shape is on top)
    for (final shape in state.shapes.reversed) {
      final intent = shape.getEditIntent(position);

      if (intent != null) {
        _activeShapeId = shape.id;
        _activeIntent = intent;
        _lastPointerPosition = position;

        // Select the shape
        vm.selectShape(shape.id);
        return;
      }
    }

    // Clicked on empty space — deselect
    _activeShapeId = null;
    _activeIntent = null;
    _lastPointerPosition = null;
    vm.selectShape(null);
  }

  void _handlePointerMove(Offset screenPosition, CanvasLoaded state) {
    final position = _toCanvasPosition(screenPosition, state);

    collaborativeVm.broadcastCursor(position);

    if (_activeShapeId == null || _activeIntent == null) return;

    final delta = position - (_lastPointerPosition ?? position);
    _lastPointerPosition = position;

    final operation = _createOperation(
      shapeId: _activeShapeId!,
      intent: _activeIntent!,
      delta: delta,
    );

    if (operation != null) {
      vm.applyOperation(operation);
    }
  }

  void _handlePointerUp(Offset screenPosition, CanvasLoaded state) {
    _activeShapeId = null;
    _activeIntent = null;
    _lastPointerPosition = null;
  }

  void _handleDoubleTap(Offset screenPosition, CanvasLoaded state) {
    final position = _toCanvasPosition(screenPosition, state);

    // First check if we're double-tapping on an existing shape to edit text
    for (final canvasShape in state.shapes.reversed) {
      if (canvasShape.hitTest(position)) {
        // Start text editing for this shape
        _textController.text = canvasShape.entity.text ?? '';
        vm.startTextEdit(canvasShape.id);
        // Request focus after the overlay is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _textFocusNode.requestFocus();
          // Select all text for easy replacement
          _textController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _textController.text.length,
          );
        });
        return;
      }
    }

    // If not on a shape, create a new shape (if tool is not select)
    final tool = state.currentTool;
    if (tool == CanvasTool.select) return;

    // Create shape at position
    vm.createShapeAt(position: position, tool: tool);
  }

  void _handlePointerHover(Offset screenPosition, CanvasLoaded state) {
    final position = _toCanvasPosition(screenPosition, state);

    collaborativeVm.broadcastCursor(position);

    for (final shape in state.shapes.reversed) {
      final intent = shape.getEditIntent(position);

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

  // ---------------------------------------------------------------------------
  // Text Editing Overlay
  // ---------------------------------------------------------------------------

  Widget _buildTextEditingOverlay(CanvasLoaded state, Shape shape) {
    final canvasShape = CanvasShape.createCanvasShape(shape);

    // Calculate the position of the text field in screen coordinates
    final screenX = shape.x * state.zoom + state.panOffset.dx;
    final screenY = shape.y * state.zoom + state.panOffset.dy;
    final screenWidth = shape.width * state.zoom;
    final screenHeight = shape.height * state.zoom;

    return Positioned(
      left: screenX,
      top: screenY,
      width: screenWidth,
      height: screenHeight,
      child: TextField(
        controller: _textController,
        focusNode: _textFocusNode,
        maxLines: null,
        expands: true,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          color: canvasShape.textColor,
          fontSize: 14 * state.zoom,
        ),
        cursorColor: canvasShape.textColor,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(8),
        ),
        onChanged: (text) {
          // Update text in real-time
          vm.updateShapeText(shape.id, text);
        },
        onSubmitted: (_) => vm.stopTextEdit(),
        onTapOutside: (_) => vm.stopTextEdit(),
      ),
    );
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
