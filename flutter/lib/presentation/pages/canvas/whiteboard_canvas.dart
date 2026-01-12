import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/presentation/pages/canvas/painters/cursors_painter.dart';

import 'canvas_vm.dart';
import 'collaborative_canvas_vm.dart';
import 'models/edit_intent.dart';
import 'models/canvas_operation.dart';
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
  const WhiteboardCanvas({super.key});

  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  // Gesture tracking state
  _ShapeInteractionState? _shapeInteractionState;
  _PanInteractionState? _panInteractionState;
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
          onPointerSignal: (event) => _handlePointerSignal(event, state),
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
                  gridSize: vm.gridSize,
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
    final position = vm.toCanvasPosition(screenPosition);

    collaborativeVm.broadcastCursor(position);

    // If currently editing text, stop editing when clicking elsewhere
    if (state.isEditingText) {
      vm.stopTextEdit();
    }

    // Hit test shapes using ViewModel
    final hitResult = vm.getIntentAtPosition(position);

    if (hitResult != null) {
      _shapeInteractionState = _ShapeInteractionState(
        shapeId: hitResult.shapeId,
        intent: hitResult.intent,
        dragStartPosition: position,
        initialBounds: hitResult.bounds,
      );
      _panInteractionState = null;

      // Select the shape
      vm.selectShape(hitResult.shapeId);
      return;
    }

    // Clicked on empty space — start panning and deselect
    _shapeInteractionState = null;
    _panInteractionState = _PanInteractionState(
      initialPanOffset: state.panOffset,
      dragStartScreenPosition: screenPosition,
    );
    vm.selectShape(null);
  }

  void _handlePointerSignal(PointerSignalEvent event, CanvasLoaded state) {
    final position = vm.toCanvasPosition(event.localPosition);
    collaborativeVm.broadcastCursor(position);

    if (event is PointerScrollEvent) {
      final newPanOffset = state.panOffset - event.scrollDelta;
      vm.setPanOffset(newPanOffset);
    }

    if (event is PointerScaleEvent) {
      final focalPoint = event.localPosition;
      final newZoom = state.zoom * event.scale;
      final canvasPointAtFocal = (focalPoint - state.panOffset) / state.zoom;
      final newPanOffset = focalPoint - canvasPointAtFocal * newZoom;
      vm.setZoom(newZoom);
      vm.setPanOffset(newPanOffset);
    }
  }

  void _handlePointerMove(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    collaborativeVm.broadcastCursor(position);

    // Handle panning (when dragging on empty space)
    if (_panInteractionState != null) {
      final delta =
          screenPosition - _panInteractionState!.dragStartScreenPosition;
      final newPanOffset = _panInteractionState!.initialPanOffset + delta;
      vm.setPanOffset(newPanOffset);
      return;
    }

    // Handle shape interaction
    if (_shapeInteractionState == null) {
      return;
    }

    // Calculate the total delta from the drag start
    final totalDelta = position - _shapeInteractionState!.dragStartPosition;

    final operation = vm.getOperationByIntent(
      shapeId: _shapeInteractionState!.shapeId,
      intent: _shapeInteractionState!.intent,
      initialBounds: _shapeInteractionState!.initialBounds,
      totalDelta: totalDelta,
    );

    if (operation != null) {
      vm.applyOperation(operation);
      collaborativeVm.broadcastOperation(operation);
    }
  }

  void _handlePointerUp(Offset screenPosition, CanvasLoaded state) {
    _shapeInteractionState = null;
    _panInteractionState = null;
  }

  void _handleDoubleTap(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    // First check if we're double-tapping on an existing shape to edit text
    final hitShapeId = vm.hitTestPosition(position);

    if (hitShapeId != null) {
      final shape = state.shapes.firstWhere((s) => s.id == hitShapeId);
      _textController.text = shape.entity.text ?? '';
      vm.startTextEdit(hitShapeId);
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

    // If not on a shape, create a new shape (if tool is not select)
    final tool = state.currentTool;
    if (tool == CanvasTool.select) return;

    final shapeType = vm.toolToShapeType(tool);

    if (shapeType == null) return;

    final operation = CreateShapeOperation(
      opId: const Uuid().v4(),
      shapeId: const Uuid().v4(),
      shapeType: shapeType,
      color: state.currentColor,
      x: position.dx,
      y: position.dy,
    );

    // Create shape at position
    vm.applyOperation(operation);
    collaborativeVm.broadcastOperation(operation);
  }

  void _handlePointerHover(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    collaborativeVm.broadcastCursor(position);

    final hitResult = vm.getIntentAtPosition(position);

    if (hitResult != null) {
      final newCursor = switch (hitResult.intent) {
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

    if (_hoverCursor != null) {
      setState(() {
        _hoverCursor = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Text Editing Overlay
  // ---------------------------------------------------------------------------

  Widget _buildTextEditingOverlay(CanvasLoaded state, CanvasShape shape) {
    // Calculate the position of the text field in screen coordinates
    final screenX = shape.entity.x * state.zoom + state.panOffset.dx;
    final screenY = shape.entity.y * state.zoom + state.panOffset.dy;
    final screenWidth = shape.entity.width * state.zoom;
    final screenHeight = shape.entity.height * state.zoom;

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
        style: TextStyle(color: shape.textColor, fontSize: 14 * state.zoom),
        cursorColor: shape.textColor,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(8),
        ),
        onChanged: (text) {
          final operation = TextShapeOperation(
            opId: const Uuid().v4(),
            shapeId: shape.id,
            text: text,
          );

          vm.applyOperation(operation);
          collaborativeVm.broadcastOperation(operation);
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

class _ShapeInteractionState {
  _ShapeInteractionState({
    required this.shapeId,
    required this.intent,
    required this.dragStartPosition,
    required this.initialBounds,
  });

  final String shapeId;
  final EditIntent intent;
  final Offset dragStartPosition;
  final Rect initialBounds;
}

class _PanInteractionState {
  _PanInteractionState({
    required this.initialPanOffset,
    required this.dragStartScreenPosition,
  });

  final Offset initialPanOffset;
  final Offset dragStartScreenPosition;
}
