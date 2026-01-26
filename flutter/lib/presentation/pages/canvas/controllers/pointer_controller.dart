import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';

import '../canvas_vm.dart';
import '../collaborative_canvas_vm.dart';
import '../models/canvas_operation.dart';
import '../models/edit_intent.dart';

/// Tracks shape interaction during drag operations.
class ShapeInteractionState {
  const ShapeInteractionState({
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

/// Tracks multi-shape interaction during drag operations.
class MultiShapeInteractionState {
  const MultiShapeInteractionState({
    required this.shapeIds,
    required this.dragStartPosition,
    required this.initialPositions,
  });

  final Set<String> shapeIds;
  final Offset dragStartPosition;
  final Map<String, Offset> initialPositions;
}

/// Tracks pan interaction during canvas panning.
class PanInteractionState {
  const PanInteractionState({
    required this.initialPanOffset,
    required this.dragStartScreenPosition,
  });

  final Offset initialPanOffset;
  final Offset dragStartScreenPosition;
}

/// Tracks marquee selection interaction.
class SelectionInteractionState {
  const SelectionInteractionState({required this.dragStartPosition});

  final Offset dragStartPosition;
}

/// Tracks connector interaction during node dragging.
class ConnectorInteractionState {
  const ConnectorInteractionState.node({
    required this.connectorId,
    required this.nodeIndex,
    required this.dragStartPosition,
  });

  final String connectorId;
  final int nodeIndex;
  final Offset dragStartPosition;
}

/// Handles all pointer events for the whiteboard canvas.
///
/// This controller owns the interaction state (shape, connector, pan) and
/// delegates operations to the ViewModels. It notifies the widget when
/// the cursor needs to change.
class PointerController {
  PointerController({
    required this.vm,
    required this.collaborativeVm,
    required this.onCursorChanged,
  });

  final CanvasVM vm;
  final CollaborativeCanvasVM collaborativeVm;
  final VoidCallback onCursorChanged;

  // Interaction state
  ShapeInteractionState? _shapeInteractionState;
  MultiShapeInteractionState? _multiShapeInteractionState;
  ConnectorInteractionState? _connectorInteractionState;
  PanInteractionState? _panInteractionState;
  SelectionInteractionState? _selectionInteractionState;
  SystemMouseCursor? _hoverCursor;

  /// The current cursor to display based on hover state.
  SystemMouseCursor? get currentCursor => _hoverCursor;

  /// Whether any drag operation is in progress.
  bool get isDragging =>
      _shapeInteractionState != null ||
      _multiShapeInteractionState != null ||
      _connectorInteractionState != null ||
      _panInteractionState != null ||
      _selectionInteractionState != null;

  /// The ID of the connector being dragged (if any).
  String? get draggingConnectorId => _connectorInteractionState?.connectorId;

  /// The index of the connector node being dragged (if any).
  int? get draggingNodeIndex => _connectorInteractionState?.nodeIndex;

  /// Whether connecting mode is active (from state).
  bool isConnecting(CanvasLoaded state) => state.isConnecting;

  /// Check if Command (Mac) or Control (Windows/Linux) is pressed.
  bool _isModifierPressed() {
    return HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
  }

  // ---------------------------------------------------------------------------
  // Public Event Handlers
  // ---------------------------------------------------------------------------

  void handlePointerDown(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);
    final isModifier = _isModifierPressed();

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

    // Check if clicking on an anchor point of selected shape (single selection only)
    if (state.selectedShapeIds.length == 1) {
      final anchor = _hitTestAnchor(position, state);
      if (anchor != null) {
        vm.startConnecting(state.selectedShapeIds.first, anchor);
        return;
      }
    }

    // Hit test shapes using ViewModel
    final hitResult = vm.getIntentAtPosition(position);

    if (hitResult != null) {
      _clearInteractionStates();

      // Handle modifier key for additive selection
      if (isModifier) {
        vm.toggleShapeSelection(hitResult.shapeId);
        // Don't start drag when toggling selection
        return;
      }

      // Check if clicking on an already selected shape (potential multi-drag)
      if (state.selectedShapeIds.contains(hitResult.shapeId) &&
          state.selectedShapeIds.length > 1 &&
          hitResult.intent is MoveIntent) {
        // Start multi-shape drag
        final initialPositions = <String, Offset>{};
        for (final shape in state.selectedShapes) {
          initialPositions[shape.id] = shape.bounds.topLeft;
        }

        _multiShapeInteractionState = MultiShapeInteractionState(
          shapeIds: state.selectedShapeIds,
          dragStartPosition: position,
          initialPositions: initialPositions,
        );
        return;
      }

      // Single shape interaction
      _shapeInteractionState = ShapeInteractionState(
        shapeId: hitResult.shapeId,
        intent: hitResult.intent,
        dragStartPosition: position,
        initialBounds: hitResult.bounds,
      );

      // Select the shape (replaces selection)
      vm.selectShape(hitResult.shapeId);
      return;
    }

    // Hit test connectors using the intent pattern
    final connectorHit = vm.getConnectorIntentAtPosition(position);
    if (connectorHit != null) {
      _clearInteractionStates();

      // Handle modifier key for additive selection
      if (isModifier) {
        vm.toggleConnectorSelection(connectorHit.connectorId);
        return;
      }

      // Handle connector interaction based on intent
      switch (connectorHit.intent) {
        case MoveConnectorNodeIntent(:final nodeIndex):
          _connectorInteractionState = ConnectorInteractionState.node(
            connectorId: connectorHit.connectorId,
            nodeIndex: nodeIndex,
            dragStartPosition: position,
          );
        case SelectConnectorIntent():
          // Just selecting, no drag state needed
          _connectorInteractionState = null;
        default:
          _connectorInteractionState = null;
      }

      // Select the connector
      vm.selectConnector(connectorHit.connectorId);
      return;
    }

    // Clicked on empty space
    _clearInteractionStates();

    // If a tool is selected, create shape and clear tool (one-shot behavior)
    if (state.currentTool != null) {
      _createShapeWithTool(position, state);
      return;
    }

    // Clear selection only if modifier not pressed
    if (!isModifier) {
      vm.clearSelection();
    }

    // Start marquee selection instead of panning
    _selectionInteractionState = SelectionInteractionState(
      dragStartPosition: position,
    );
  }

  /// Clear all interaction states.
  void _clearInteractionStates() {
    _shapeInteractionState = null;
    _multiShapeInteractionState = null;
    _connectorInteractionState = null;
    _panInteractionState = null;
    _selectionInteractionState = null;
  }

  void handlePointerMove(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    collaborativeVm.broadcastCursor(position);

    // Handle connecting mode preview
    if (state.isConnecting) {
      final operation = UpdateConnectingPreviewCanvasOperation(
        opId: const Uuid().v4(),
        sourceShapeId: state.connectingFromShapeId!,
        sourceAnchor: state.connectingFromAnchor!,
        previewPosition: position,
      );
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
      return;
    }

    // Handle marquee selection
    if (_selectionInteractionState != null) {
      final startPos = _selectionInteractionState!.dragStartPosition;
      final selectionRect = Rect.fromPoints(startPos, position);
      vm.updateSelectionRect(selectionRect);
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
      final operation = MoveConnectorNodeCanvasOperation(
        opId: const Uuid().v4(),
        connectorId: _connectorInteractionState!.connectorId,
        nodeIndex: _connectorInteractionState!.nodeIndex,
        position: position,
      );
      vm.applyOperation(operation, persist: true);
      collaborativeVm.broadcastOperation(operation);
      return;
    }

    // Handle multi-shape dragging
    if (_multiShapeInteractionState != null) {
      final totalDelta =
          position - _multiShapeInteractionState!.dragStartPosition;

      for (final shapeId in _multiShapeInteractionState!.shapeIds) {
        final initialPos =
            _multiShapeInteractionState!.initialPositions[shapeId];
        if (initialPos == null) continue;

        final operation = MoveShapeCanvasOperation(
          opId: const Uuid().v4(),
          shapeId: shapeId,
          position: initialPos + totalDelta,
        );
        vm.applyOperation(operation, persist: true);
        collaborativeVm.broadcastOperation(operation);
      }
      return;
    }

    // Handle single shape interaction
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

  void handlePointerUp(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    // Finalize marquee selection
    if (_selectionInteractionState != null) {
      final startPos = _selectionInteractionState!.dragStartPosition;
      final selectionRect = Rect.fromPoints(startPos, position);

      // Only select if the rect is large enough (avoid accidental clicks)
      if (selectionRect.width > 5 || selectionRect.height > 5) {
        vm.selectItemsInRect(selectionRect);
      } else {
        vm.clearSelectionRect();
      }
    }

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

    _clearInteractionStates();
  }

  void handlePointerHover(Offset screenPosition, CanvasLoaded state) {
    final position = vm.toCanvasPosition(screenPosition);

    collaborativeVm.broadcastCursor(position);

    final hitResult = vm.getIntentAtPosition(position);

    if (hitResult != null) {
      final newCursor = switch (hitResult.intent) {
        final ResizeIntent intent => intent.handle.systemMouseCursor,
        _ => SystemMouseCursors.basic,
      };

      if (newCursor != _hoverCursor) {
        _hoverCursor = newCursor;
        onCursorChanged();
      }
      return;
    }

    if (_hoverCursor != null) {
      _hoverCursor = null;
      onCursorChanged();
    }
  }

  void handlePointerSignal(PointerSignalEvent event, CanvasLoaded state) {
    final position = vm.toCanvasPosition(event.localPosition);
    collaborativeVm.broadcastCursor(position);

    if (event is PointerScrollEvent) {
      handlePan(event.scrollDelta, state);
    }

    if (event is PointerScaleEvent) {
      handleScale(event.localPosition, event.scale, state);
    }
  }

  // ---------------------------------------------------------------------------
  // Pan and Scale (shared with GestureController)
  // ---------------------------------------------------------------------------

  void handlePan(Offset delta, CanvasLoaded state) {
    final newPanOffset = state.panOffset - delta * vm.sensitivity;
    vm.setPanOffset(newPanOffset);
  }

  void handleScale(Offset focalPoint, double scale, CanvasLoaded state) {
    // Dampen the scale change: reduce how much scale deviates from 1.0
    final dampedScale = 1.0 + (scale - 1.0) * vm.zoomSensitivity;
    final newZoom = (state.zoom * dampedScale).clamp(vm.zoomMin, vm.zoomMax);

    // Skip if zoom hasn't actually changed (idempotent at limits)
    if (newZoom == state.zoom) return;

    final canvasPointAtFocal = (focalPoint - state.panOffset) / state.zoom;
    final newPanOffset = focalPoint - canvasPointAtFocal * newZoom;

    vm.setZoom(newZoom);
    vm.setPanOffset(newPanOffset);
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Create a shape at position using the current tool, then clear the tool.
  void _createShapeWithTool(Offset position, CanvasLoaded state) {
    final tool = state.currentTool;
    if (tool == null) return;

    final shapeType = vm.toolToShapeType(tool);
    if (shapeType == null) return;

    final operation = CreateShapeCanvasOperation(
      opId: const Uuid().v4(),
      shapeId: const Uuid().v4(),
      shapeType: shapeType,
      color: state.currentColor,
      position: position,
    );

    // Create shape and broadcast
    vm.applyOperation(operation, persist: true);
    collaborativeVm.broadcastOperation(operation);

    // Clear the tool (one-shot behavior)
    vm.clearTool();
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
