import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/presentation/pages/canvas/painters/connectors_painter.dart';
import 'package:whiteboard/presentation/pages/canvas/painters/cursors_painter.dart';

import 'canvas_vm.dart';
import 'collaborative_canvas_vm.dart';
import 'models/edit_intent.dart';
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
class WhiteboardCanvas extends ConsumerStatefulWidget {
  const WhiteboardCanvas({super.key});

  @override
  ConsumerState<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends ConsumerState<WhiteboardCanvas> {
  // Gesture tracking state
  _ShapeInteractionState? _shapeInteractionState;
  _ConnectorInteractionState? _connectorInteractionState;
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

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _handlePointerDown(event.localPosition, state),
      onPointerMove: (event) => _handlePointerMove(event.localPosition, state),
      onPointerUp: (event) => _handlePointerUp(event.localPosition, state),
      onPointerCancel: (event) => _handlePointerUp(event.localPosition, state),
      onPointerHover: (event) =>
          _handlePointerHover(event.localPosition, state),
      onPointerSignal: (event) => _handlePointerSignal(event, state),
      child: GestureDetector(
        onScaleUpdate: (details) => _handleScaleUpdate(details, state),
        // Double-tap to create shape or edit text
        onDoubleTapDown: (details) =>
            _handleDoubleTap(details.localPosition, state),
        child: MouseRegion(
          cursor: _hoverCursor ?? SystemMouseCursors.basic,
          child: Stack(
            children: [
              // Connectors layer (behind shapes)
              CustomPaint(
                painter: ConnectorsPainter(
                  connectors: state.connectors,
                  shapes: state.shapes,
                  selectedConnectorId: state.selectedConnectorId,
                  selectedShapeId: state.selectedShapeId,
                  draggingConnectorId: _connectorInteractionState?.connectorId,
                  draggingNodeIndex: _connectorInteractionState?.nodeIndex,
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

              // Text editing overlay
              if (collaborativeState is CollaborativeCanvasLoaded)
                CustomPaint(
                  painter: CursorsPainter(
                    cursors: collaborativeState.cursors,
                    panOffset: state.panOffset,
                    zoom: state.zoom,
                  ),
                ),

              if (state.isEditingText && state.selectedShapeId != null)
                _buildTextEditingOverlay(state),
            ],
          ),
        ),
      ),
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

    // If in connecting mode, handle connection completion
    if (state.isConnecting) {
      _handleConnectingClick(position, state);
      return;
    }

    // Check if clicking on an anchor point of selected shape
    if (state.selectedShapeId != null) {
      final anchor = _hitTestAnchor(position, state);
      if (anchor != null) {
        vm.startConnecting(state.selectedShapeId!, anchor);
        return;
      }
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
      _connectorInteractionState = null;
      _panInteractionState = null;

      // Select the shape
      vm.selectShape(hitResult.shapeId);
      return;
    }

    // Hit test connectors
    final connectorId = vm.hitTestConnector(position);
    if (connectorId != null) {
      _shapeInteractionState = null;
      _panInteractionState = null;

      // Check if hitting a node on the connector (for dragging)
      final nodeIndex = vm.hitTestConnectorNode(connectorId, position);
      if (nodeIndex != null && nodeIndex > 0) {
        // Don't allow dragging anchor nodes (first and last)
        final connector = state.connectors.firstWhere(
          (c) => c.id == connectorId,
        );
        if (nodeIndex < connector.nodes.length - 1) {
          _connectorInteractionState = _ConnectorInteractionState.node(
            connectorId: connectorId,
            nodeIndex: nodeIndex,
            dragStartPosition: position,
          );
        }
      }

      // Select the connector
      vm.selectConnector(connectorId);
      return;
    }

    // Clicked on empty space — start panning and deselect
    _shapeInteractionState = null;
    _connectorInteractionState = null;
    _panInteractionState = _PanInteractionState(
      initialPanOffset: state.panOffset,
      dragStartScreenPosition: screenPosition,
    );
    vm.selectShape(null);
    vm.selectConnector(null);
  }

  /// Hit test anchor points on the selected shape.
  AnchorPoint? _hitTestAnchor(Offset position, CanvasLoaded state) {
    final selectedShape = state.selectedShape;
    if (selectedShape == null) return null;

    return selectedShape.hitTestAnchor(position);
  }

  /// Handle click while in connecting mode.
  void _handleConnectingClick(Offset position, CanvasLoaded state) {
    // Check if clicking on an anchor of another shape
    for (final shape in state.shapes) {
      if (shape.id == state.connectingFromShapeId) continue;

      final anchor = shape.hitTestAnchor(position);
      if (anchor != null) {
        final operation = vm.completeConnecting(shape.id, anchor);
        if (operation != null) {
          collaborativeVm.broadcastOperation(operation);
        }
        return;
      }
    }

    // Clicked on empty space — create new shape and connect
    final operations = vm.completeConnectingWithNewShape(position);
    if (operations != null) {
      collaborativeVm.broadcastOperation(operations.shape);
      collaborativeVm.broadcastOperation(operations.connector);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event, CanvasLoaded state) {
    final position = vm.toCanvasPosition(event.localPosition);
    collaborativeVm.broadcastCursor(position);

    if (event is PointerScrollEvent) {
      _handlePan(event.scrollDelta, state);
    }

    if (event is PointerScaleEvent) {
      _handleScale(event.localPosition, event.scale, state);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, CanvasLoaded state) {
    // Ignore scale updates when pointer is down (dragging something)
    if (_shapeInteractionState != null ||
        _connectorInteractionState != null ||
        _panInteractionState != null ||
        state.isConnecting) {
      return;
    }

    // Handle pan from two-finger drag
    if (details.focalPointDelta != Offset.zero) {
      _handlePan(-details.focalPointDelta, state);
    }

    // Handle scale from pinch gesture
    if (details.scale != 1.0) {
      _handleScale(details.focalPoint, details.scale, state);
    }
  }

  void _handlePan(Offset delta, CanvasLoaded state) {
    final newPanOffset = state.panOffset - delta;
    vm.setPanOffset(newPanOffset);
  }

  void _handleScale(Offset focalPoint, double scale, CanvasLoaded state) {
    // Dampen the scale change: reduce how much scale deviates from 1.0
    final dampedScale = 1.0 + (scale - 1.0) / vm.zoomDimifier;
    final newZoom = (state.zoom * dampedScale).clamp(vm.zoomMin, vm.zoomMax);

    // Skip if zoom hasn't actually changed (idempotent at limits)
    if (newZoom == state.zoom) return;

    final canvasPointAtFocal = (focalPoint - state.panOffset) / state.zoom;
    final newPanOffset = focalPoint - canvasPointAtFocal * newZoom;

    vm.setZoom(newZoom);
    vm.setPanOffset(newPanOffset);
  }

  void _handlePointerMove(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    collaborativeVm.broadcastCursor(position);

    // Handle connecting mode preview
    if (state.isConnecting) {
      final operation = UpdateConnectingPreviewOperation(
        opId: const Uuid().v4(),
        sourceShapeId: state.connectingFromShapeId!,
        sourceAnchor: state.connectingFromAnchor!,
        previewPosition: position,
      );
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
      return;
    }

    // Handle panning (when dragging on empty space)
    if (_panInteractionState != null) {
      final delta =
          screenPosition - _panInteractionState!.dragStartScreenPosition;
      final newPanOffset = _panInteractionState!.initialPanOffset + delta;
      vm.setPanOffset(newPanOffset);
      return;
    }

    // Handle connector node dragging
    if (_connectorInteractionState != null) {
      final operation = MoveConnectorNodeOperation(
        opId: const Uuid().v4(),
        connectorId: _connectorInteractionState!.connectorId,
        nodeIndex: _connectorInteractionState!.nodeIndex,
        position: position,
      );
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
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
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
    }
  }

  void _handlePointerUp(Offset screenPosition, CanvasLoaded state) {
    // Finalize connector node movement if dragging
    if (_connectorInteractionState != null) {
      final operation = vm.finalizeConnectorNodeMove(
        _connectorInteractionState!.connectorId,
        _connectorInteractionState!.nodeIndex,
      );
      if (operation != null) {
        collaborativeVm.broadcastOperation(operation);
      }
    }

    _shapeInteractionState = null;
    _connectorInteractionState = null;
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

    // If not on a shape, create a new shape
    final tool = state.currentTool;

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
    vm.applyOperation(operation, persist: true);
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
          final operation = TextShapeOperation(
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

/// Connector interaction state for node dragging.
class _ConnectorInteractionState {
  _ConnectorInteractionState.node({
    required this.connectorId,
    required this.nodeIndex,
    required this.dragStartPosition,
  });

  final String connectorId;
  final int nodeIndex;
  final Offset dragStartPosition;
}
