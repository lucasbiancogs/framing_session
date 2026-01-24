import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/presentation/pages/canvas/painters/connectors_painter.dart';
import 'package:whiteboard/presentation/pages/canvas/painters/cursors_painter.dart';

import 'canvas_vm.dart';
import 'collaborative_canvas_vm.dart';
import 'controllers/gesture_controller.dart';
import 'controllers/keyboard_controller.dart';
import 'controllers/pointer_controller.dart';
import 'models/canvas_operation.dart';
import 'painters/whiteboard_painter.dart';

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
///
/// Input handling is delegated to controllers:
/// - PointerController: pointer events (down, move, up, hover, signal)
/// - GestureController: gesture events (scale, double-tap)
/// - KeyboardController: keyboard events (delete, escape, enter)
class WhiteboardCanvas extends ConsumerStatefulWidget {
  const WhiteboardCanvas({super.key});

  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  // Controllers
  late PointerController _pointerController;
  late GestureController _gestureController;
  late KeyboardController _keyboardController;

  // Focus node for keyboard events
  final FocusNode _canvasFocusNode = FocusNode();

  // Text editing
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Controllers will be initialized in didChangeDependencies
    // because they need access to the ViewModels from ref
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initControllers();
  }

  void _initControllers() {
    final vm = ref.read(canvasVM.notifier);
    final collaborativeVm = ref.read(collaborativeCanvasVM.notifier);

    _pointerController = PointerController(
      vm: vm,
      collaborativeVm: collaborativeVm,
      onCursorChanged: () => setState(() {}),
    );

    _gestureController = GestureController(
      vm: vm,
      collaborativeVm: collaborativeVm,
      pointerController: _pointerController,
      textController: _textController,
      textFocusNode: _textFocusNode,
    );

    _keyboardController = KeyboardController(
      vm: vm,
      collaborativeVm: collaborativeVm,
      onStartTextEdit: _startTextEditOnSelectedShape,
    );
  }

  @override
  void dispose() {
    _canvasFocusNode.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  CanvasVM get vm => ref.watch(canvasVM.notifier);
  CollaborativeCanvasVM get collaborativeVm =>
      ref.watch(collaborativeCanvasVM.notifier);

  /// Start text editing on the currently selected shape.
  /// Called by KeyboardController when Enter is pressed.
  void _startTextEditOnSelectedShape(CanvasLoaded state) {
    final shapeId = state.selectedShapeId;
    if (shapeId == null) return;

    final shape = state.shapes.firstWhere((s) => s.id == shapeId);
    _textController.text = shape.entity.text ?? '';
    vm.startTextEdit(shapeId);

    // Request focus after the overlay is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
      // Select all text for easy replacement
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(canvasVM);
    final collaborativeState = ref.watch(collaborativeCanvasVM);

    if (state is! CanvasLoaded) {
      return const SizedBox.shrink();
    }

    return Focus(
      focusNode: _canvasFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) =>
          _keyboardController.handleKeyEvent(event, state),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) =>
            _pointerController.handlePointerDown(event.localPosition, state),
        onPointerMove: (event) =>
            _pointerController.handlePointerMove(event.localPosition, state),
        onPointerUp: (event) =>
            _pointerController.handlePointerUp(event.localPosition, state),
        onPointerCancel: (event) =>
            _pointerController.handlePointerUp(event.localPosition, state),
        onPointerHover: (event) =>
            _pointerController.handlePointerHover(event.localPosition, state),
        onPointerSignal: (event) =>
            _pointerController.handlePointerSignal(event, state),
        child: GestureDetector(
          onScaleUpdate: (details) =>
              _gestureController.handleScaleUpdate(details, state),
          // Double-tap to create shape or edit text
          onDoubleTapDown: (details) =>
              _gestureController.handleDoubleTap(details.localPosition, state),
          child: MouseRegion(
            cursor:
                _pointerController.currentCursor ?? SystemMouseCursors.basic,
            child: Stack(
              children: [
                // Connectors layer (behind shapes)
                CustomPaint(
                  painter: ConnectorsPainter(
                    connectors: state.connectors,
                    shapes: state.shapes,
                    selectedConnectorId: state.selectedConnectorId,
                    selectedShapeId: state.selectedShapeId,
                    draggingConnectorId: _pointerController.draggingConnectorId,
                    draggingNodeIndex: _pointerController.draggingNodeIndex,
                    isConnecting: state.isConnecting,
                    connectingFromShape: state.connectingFromShape,
                    connectingFromAnchor: state.connectingFromAnchor,
                    connectingPreviewEnd: state.connectingPreviewEnd,
                    panOffset: state.panOffset,
                    zoom: state.zoom,
                  ),
                  size: Size.infinite,
                ),

                // Shapes layer with interaction
                CustomPaint(
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

                // Cursors layer
                if (collaborativeState is CollaborativeCanvasLoaded)
                  CustomPaint(
                    painter: CursorsPainter(
                      cursors: collaborativeState.cursors,
                      panOffset: state.panOffset,
                      zoom: state.zoom,
                    ),
                  ),

                // Text editing overlay
                if (state.isEditingText && state.selectedShapeId != null)
                  _buildTextEditingOverlay(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text Editing Overlay
  // ---------------------------------------------------------------------------

  Widget _buildTextEditingOverlay(CanvasLoaded state) {
    final shape = state.selectedShape!;

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
          final operation = TextShapeCanvasOperation(
            opId: const Uuid().v4(),
            shapeId: shape.id,
            text: text,
          );

          vm.applyOperation(operation, persist: true);
          collaborativeVm.broadcastOperation(operation);
        },
        onSubmitted: (_) => vm.stopTextEdit(),
        onTapOutside: (_) => vm.stopTextEdit(),
      ),
    );
  }
}
