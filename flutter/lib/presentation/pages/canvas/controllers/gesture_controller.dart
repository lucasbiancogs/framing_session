import 'package:flutter/widgets.dart';

import '../canvas_vm.dart';
import '../collaborative_canvas_vm.dart';
import 'pointer_controller.dart';

/// Handles gesture events (scale, double-tap) for the whiteboard canvas.
///
/// This controller delegates pan/scale operations to the PointerController
/// and handles text editing initiation on double-tap.
class GestureController {
  GestureController({
    required this.vm,
    required this.collaborativeVm,
    required this.pointerController,
    required this.textController,
    required this.textFocusNode,
  });

  final CanvasVM vm;
  final CollaborativeCanvasVM collaborativeVm;
  final PointerController pointerController;
  final TextEditingController textController;
  final FocusNode textFocusNode;

  /// Handle scale/pinch gesture updates.
  ///
  /// This handles both two-finger panning and pinch-to-zoom.
  /// Ignored when the pointer controller is dragging something.
  void handleScaleUpdate(ScaleUpdateDetails details, CanvasLoaded state) {
    // Ignore scale updates when pointer is down (dragging something)
    if (pointerController.isDragging || state.isConnecting) {
      return;
    }

    // Handle pan from two-finger drag
    if (details.focalPointDelta != Offset.zero) {
      pointerController.handlePan(-details.focalPointDelta, state);
    }

    // Handle scale from pinch gesture
    if (details.scale != 1.0) {
      pointerController.handleScale(details.focalPoint, details.scale, state);
    }
  }

  /// Handle double-tap to edit text on existing shape.
  void handleDoubleTap(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    // Check if we're double-tapping on an existing shape to edit text
    final hitShapeId = vm.hitTestPosition(position);

    if (hitShapeId != null) {
      final shape = state.shapes.firstWhere((s) => s.id == hitShapeId);
      textController.text = shape.entity.text ?? '';
      vm.startTextEdit(hitShapeId);
      // Request focus after the overlay is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        textFocusNode.requestFocus();
        // Select all text for easy replacement
        textController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: textController.text.length,
        );
      });
    }
  }
}
