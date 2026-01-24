import 'dart:ui' show Offset, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/domain/entities/arrow_type.dart';
import 'package:whiteboard/domain/entities/connector.dart';
import 'package:whiteboard/domain/entities/waypoint.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_connector.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_shape.dart';
import 'package:whiteboard/presentation/pages/canvas/models/connector_node.dart';
import 'package:whiteboard/presentation/pages/canvas/models/connector_router.dart';

import '../../../core/errors/base_faults.dart';
import '../../../core/utils/debouncer.dart';
import '../../../domain/entities/shape.dart';
import '../../../domain/entities/shape_type.dart';
import '../../../domain/services/shape_services.dart';
import '../../view_models/global_providers.dart';
import 'models/canvas_operation.dart';
import 'models/edit_intent.dart';

final canvasVM = StateNotifierProvider.autoDispose<CanvasVM, CanvasState>(
  (ref) => CanvasVM(ref.watch(shapeServices), ref.watch(sessionIdProvider)),
  name: 'canvasVM',
  dependencies: [shapeServices, canvasServices, sessionIdProvider],
);

/// Available tools for the canvas.
enum CanvasTool { rectangle, circle, triangle, text }

const double _zoomMin = 0.5;
const double _zoomMax = 4.0;

class CanvasVM extends StateNotifier<CanvasState> {
  CanvasVM(this._shapeServices, this._sessionId)
    : super(const CanvasLoading()) {
    _loadShapes();
  }

  final ShapeServices _shapeServices;
  final String _sessionId;

  final double gridSize = 20.0;
  final double initialShapeSize = 150.0;
  final double sensitivity = 2;
  final double zoomSensitivity = 0.25;
  final double zoomMin = _zoomMin;
  final double zoomMax = _zoomMax;

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

  /// The router used for connector path calculations.
  final ConnectorRouter _router = const LinearConnectorRouter();

  Future<void> _loadShapes() async {
    final shapesResult = await _shapeServices.getSessionShapes(_sessionId);
    final connectorsResult = await _shapeServices.getSessionConnectors(
      _sessionId,
    );

    shapesResult.fold((exception) => state = CanvasError(exception), (shapes) {
      final canvasShapes = shapes.map(CanvasShape.createCanvasShape).toList();

      connectorsResult.fold((exception) => state = CanvasError(exception), (
        connectors,
      ) {
        final shapesById = {for (final shape in canvasShapes) shape.id: shape};
        if (shapesById.length != canvasShapes.length) {
          return;
        }

        // Create canvas connectors, filtering out any with missing shapes
        final canvasConnectors = connectors
            .map((c) {
              final sourceShape = shapesById[c.sourceShapeId];
              final targetShape = shapesById[c.targetShapeId];
              if (sourceShape == null || targetShape == null) return null;

              return _buildCanvasConnector(
                entity: c,
                sourceShape: sourceShape,
                targetShape: targetShape,
              );
            })
            .whereType<CanvasConnector>()
            .toList();

        state = CanvasLoaded(
          shapes: canvasShapes,
          connectors: canvasConnectors,
        );
      });
    });
  }

  /// Build a CanvasConnector from entity and shapes using the router.
  ///
  /// This is the single point where connectors are created, ensuring
  /// consistent use of the router for node and path calculation.
  CanvasConnector _buildCanvasConnector({
    required Connector entity,
    required CanvasShape sourceShape,
    required CanvasShape targetShape,
  }) {
    final nodes = _router.createInitialNodes(
      sourcePosition: sourceShape.getAnchorPosition(entity.sourceAnchor),
      targetPosition: targetShape.getAnchorPosition(entity.targetAnchor),
      sourceAnchor: entity.sourceAnchor,
      targetAnchor: entity.targetAnchor,
      waypoints: entity.waypoints,
    );

    final path = _router.route(nodes);

    return CanvasConnector(entity: entity, nodes: nodes, path: path);
  }

  Future<void> retryLoading() async {
    state = const CanvasLoading();
    await _loadShapes();
  }

  /// Select a shape by ID.
  void selectShape(String? shapeId) {
    if (state is! CanvasLoaded) return;

    if (shapeId == _loadedState.selectedShapeId) return;

    if (shapeId == null) {
      // Clear selection
      state = _loadedState.copyWith(clearSelections: true);
      return;
    }

    state = _loadedState
        .copyWith(clearSelections: true)
        .copyWith(selectedShapeId: shapeId);
  }

  /// Change the current tool.
  void setTool(CanvasTool? tool) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(currentTool: tool, clearTool: tool == null);
  }

  /// Clear the current tool (one-shot tool behavior).
  void clearTool() {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(clearTool: true);
  }

  /// Update pan offset.
  void setPanOffset(Offset offset) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(panOffset: offset);
  }

  /// Update zoom level.
  void setZoom(double zoom) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(zoom: zoom);
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

    // state = _loadedState.copyWith(isEditingText: false);
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
  /// This is the single entry point for all shape and connector mutations.
  /// Operations are applied immutably — shapes/connectors are never mutated in place.
  ///
  /// [persist] controls whether the operation should be persisted to the database.
  /// - `true` for local operations (user-initiated)
  /// - `false` for remote operations (received from other clients)
  void applyOperation(CanvasOperation operation, {bool persist = false}) {
    if (state is! CanvasLoaded) return;

    // Deduplicate operations
    if (_appliedOpIds.contains(operation.opId)) return;
    _appliedOpIds.add(operation.opId);

    switch (operation) {
      case CreateConnectorCanvasOperation():
        _applyCreateConnector(operation, persist: persist);
        return;
      case UpdateConnectorWaypointsCanvasOperation():
        _applyUpdateConnectorWaypoints(operation, persist: persist);
        return;
      case DeleteConnectorCanvasOperation():
        _applyDeleteConnector(operation, persist: persist);
        return;
      // Ephemeral operations (never persisted)
      case UpdateConnectingPreviewCanvasOperation():
        _applyUpdateConnectingPreview(operation);
        return;
      case MoveConnectorNodeCanvasOperation():
        _applyMoveConnectorNode(operation);
        return;
      default:
        break;
    }

    final newShapes = switch (operation) {
      MoveShapeCanvasOperation(:final shapeId, :final position) => _applyMove(
        shapeId,
        position,
      ),
      ResizeShapeCanvasOperation(:final shapeId, :final bounds) => _applyResize(
        shapeId,
        bounds,
      ),
      TextShapeCanvasOperation(:final shapeId, :final text) => _applyTextEdit(
        shapeId,
        text,
      ),
      CreateShapeCanvasOperation() => _applyCreate(operation),
      PasteShapeCanvasOperation() => _applyPaste(operation),
      DeleteShapeCanvasOperation(:final shapeId) => _applyDelete(
        shapeId,
        persist: persist,
      ),
      _ => _loadedState.shapes,
    };

    state = _loadedState.copyWith(shapes: newShapes);

    // Schedule debounced persistence for update operations (only for local)
    if (persist) {
      _scheduleDebouncedPersist(operation);
    }
  }

  CanvasOperation? getOperationByIntent({
    required String shapeId,
    required EditIntent intent,
    required Rect initialBounds,
    required Offset totalDelta,
  }) {
    final opId = const Uuid().v4();

    return switch (intent) {
      MoveIntent() => MoveShapeCanvasOperation(
        opId: opId,
        shapeId: shapeId,
        position: initialBounds.topLeft + totalDelta,
      ),
      ResizeIntent(:final handle) => ResizeShapeCanvasOperation(
        opId: opId,
        shapeId: shapeId,
        handle: handle,
        bounds: _calculateNewBounds(initialBounds, handle, totalDelta),
      ),
      // Connector intents are not handled here (shape-specific method)
      MoveConnectorNodeIntent() || SelectConnectorIntent() => null,
    };
  }

  Rect _calculateNewBounds(
    Rect initialBounds,
    ResizeHandle handle,
    Offset totalDelta,
  ) {
    var left = initialBounds.left;
    var top = initialBounds.top;
    var right = initialBounds.right;
    var bottom = initialBounds.bottom;

    switch (handle) {
      case ResizeHandle.topLeft:
        left += totalDelta.dx;
        top += totalDelta.dy;
      case ResizeHandle.topCenter:
        top += totalDelta.dy;
      case ResizeHandle.topRight:
        right += totalDelta.dx;
        top += totalDelta.dy;
      case ResizeHandle.centerLeft:
        left += totalDelta.dx;
      case ResizeHandle.centerRight:
        right += totalDelta.dx;
      case ResizeHandle.bottomLeft:
        left += totalDelta.dx;
        bottom += totalDelta.dy;
      case ResizeHandle.bottomCenter:
        bottom += totalDelta.dy;
      case ResizeHandle.bottomRight:
        right += totalDelta.dx;
        bottom += totalDelta.dy;
    }

    // Ensure minimum size and prevent inverted bounds
    const minSize = 20.0;
    if (right - left < minSize) {
      if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.centerLeft ||
          handle == ResizeHandle.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }
    if (bottom - top < minSize) {
      if (handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.topCenter ||
          handle == ResizeHandle.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Convert screen position to canvas position (accounting for pan/zoom).
  Offset toCanvasPosition(Offset screenPosition) {
    return (screenPosition - _loadedState.panOffset) / _loadedState.zoom;
  }

  /// Get the edit intent at a canvas position.
  /// Returns a tuple of (shapeId, intent, bounds) if a shape is hit, null otherwise.
  ({String shapeId, EditIntent intent, Rect bounds})? getIntentAtPosition(
    Offset canvasPosition,
  ) {
    if (state is! CanvasLoaded) return null;

    for (final shape in _loadedState.shapes.reversed) {
      final intent = shape.getEditIntent(canvasPosition);
      if (intent != null) {
        return (shapeId: shape.id, intent: intent, bounds: shape.bounds);
      }
    }
    return null;
  }

  /// Hit test a canvas position and return the shape ID if found.
  String? hitTestPosition(Offset canvasPosition) {
    if (state is! CanvasLoaded) return null;

    for (final shape in _loadedState.shapes.reversed) {
      if (shape.hitTest(canvasPosition)) {
        return shape.id;
      }
    }
    return null;
  }

  /// Schedule debounced persistence for update operations.
  void _scheduleDebouncedPersist(CanvasOperation operation) {
    switch (operation) {
      case CreateShapeCanvasOperation():
      case PasteShapeCanvasOperation():
        final shape = _loadedState.shapes.firstWhere(
          (s) => s.id == operation.shapeId,
          orElse: () =>
              throw StateError('Shape not found: ${operation.shapeId}'),
        );
        _shapeServices.createShape(shape.entity);
        return;
      case DeleteShapeCanvasOperation():
        _shapeServices.deleteShape(operation.shapeId);
        return;
      default:
        break;
    }

    // Only debounce move, resize, rotate, and text operations
    final shapeId = switch (operation) {
      MoveShapeCanvasOperation(:final shapeId) => shapeId,
      ResizeShapeCanvasOperation(:final shapeId) => shapeId,
      TextShapeCanvasOperation(:final shapeId) => shapeId,
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

    _rebuildConnectors();

    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.applyMove(snappedPosition);
    }).toList();
  }

  List<CanvasShape> _applyResize(String shapeId, Rect bounds) {
    final snappedBounds = _loadedState.snapToGrid ? _snapRect(bounds) : bounds;

    _rebuildConnectors();

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

  List<CanvasShape> _applyCreate(CreateShapeCanvasOperation operation) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final shape = Shape(
      id: operation.shapeId,
      sessionId: _sessionId,
      shapeType: operation.shapeType,
      x: operation.position.dx,
      y: operation.position.dy,
      width: initialShapeSize,
      height: initialShapeSize,
      color: operation.color,
    );

    final canvasShape = CanvasShape.createCanvasShape(shape);

    return [..._loadedState.shapes, canvasShape];
  }

  /// Paste a shape with all properties preserved.
  List<CanvasShape> _applyPaste(PasteShapeCanvasOperation operation) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final shape = Shape(
      id: operation.shapeId,
      sessionId: _sessionId,
      shapeType: operation.shapeType,
      x: operation.x,
      y: operation.y,
      width: operation.width,
      height: operation.height,
      color: operation.color,
      text: operation.text,
    );

    final canvasShape = CanvasShape.createCanvasShape(shape);

    return [..._loadedState.shapes, canvasShape];
  }

  /// Delete the currently selected shape.
  ///
  /// Also deletes any connectors that reference this shape.
  List<CanvasShape> _applyDelete(String shapeId, {bool persist = false}) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final newShapes = _loadedState.shapes
        .where((s) => s.id != shapeId)
        .toList();

    // Find and delete connectors connected to this shape
    final connectorsToDelete = _loadedState.connectors
        .where(
          (c) =>
              c.entity.sourceShapeId == shapeId ||
              c.entity.targetShapeId == shapeId,
        )
        .toList();

    final newConnectors = _loadedState.connectors
        .where(
          (c) =>
              c.entity.sourceShapeId != shapeId &&
              c.entity.targetShapeId != shapeId,
        )
        .toList();

    // Delete connectors from database (only for local operations)
    if (persist) {
      for (final connector in connectorsToDelete) {
        _shapeServices.deleteConnector(connector.id);
      }
    }

    state = _loadedState
        .copyWith(clearSelections: true)
        .copyWith(shapes: newShapes, connectors: newConnectors);

    return newShapes;
  }

  ShapeType? toolToShapeType(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.rectangle => ShapeType.rectangle,
      CanvasTool.circle => ShapeType.circle,
      CanvasTool.triangle => ShapeType.triangle,
      CanvasTool.text => ShapeType.text,
    };
  }

  // ---------------------------------------------------------------------------
  // Connector Methods
  // ---------------------------------------------------------------------------

  /// Start connecting mode from a shape anchor.
  void startConnecting(String shapeId, AnchorPoint anchor) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(
      connectingMode: ConnectingModeState(
        fromShapeId: shapeId,
        fromAnchor: anchor,
      ),
      selectedShapeId: shapeId,
    );
  }

  /// Apply an update connecting preview operation (ephemeral, not persisted).
  void _applyUpdateConnectingPreview(
    UpdateConnectingPreviewCanvasOperation operation,
  ) {
    if (state is! CanvasLoaded) return;

    // Start or update connecting mode based on operation
    state = _loadedState.copyWith(
      connectingMode: ConnectingModeState(
        fromShapeId: operation.sourceShapeId,
        fromAnchor: operation.sourceAnchor,
        previewEnd: operation.previewPosition,
      ),
    );
  }

  /// Cancel connecting mode.
  void cancelConnecting() {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(clearSelections: true);
  }

  /// Complete connecting to a target shape anchor.
  ///
  /// Returns the created operation for broadcasting, or null if invalid.
  CreateConnectorCanvasOperation? completeConnecting(
    String targetShapeId,
    AnchorPoint targetAnchor,
  ) {
    if (state is! CanvasLoaded || !_loadedState.isConnecting) return null;

    final sourceShapeId = _loadedState.connectingFromShapeId;
    final sourceAnchor = _loadedState.connectingFromAnchor;

    if (sourceShapeId == null || sourceAnchor == null) return null;

    // Don't allow self-connections
    if (sourceShapeId == targetShapeId) {
      cancelConnecting();
      return null;
    }

    final operation = CreateConnectorCanvasOperation(
      opId: const Uuid().v4(),
      connectorId: const Uuid().v4(),
      sourceShapeId: sourceShapeId,
      targetShapeId: targetShapeId,
      sourceAnchor: sourceAnchor,
      targetAnchor: targetAnchor,
      arrowType: ArrowType.end,
      color: _loadedState.currentColor,
    );

    applyOperation(operation, persist: true);

    state = _loadedState.copyWith(clearSelections: true);

    return operation;
  }

  /// Complete connecting by creating a new shape and connector.
  ///
  /// Returns both operations for broadcasting, or null if invalid.
  ({
    CreateShapeCanvasOperation shape,
    CreateConnectorCanvasOperation connector,
  })?
  completeConnectingWithNewShape(Offset position) {
    if (state is! CanvasLoaded || !_loadedState.isConnecting) return null;

    final sourceShapeId = _loadedState.connectingFromShapeId;
    final sourceAnchor = _loadedState.connectingFromAnchor;

    if (sourceShapeId == null || sourceAnchor == null) return null;

    // Determine the target anchor based on source anchor (opposite side)
    final targetAnchor = _getOppositeAnchor(sourceAnchor);

    // Create new shape
    final shapeId = const Uuid().v4();
    final shapeOperation = CreateShapeCanvasOperation(
      opId: const Uuid().v4(),
      shapeId: shapeId,
      shapeType: ShapeType.rectangle,
      color: _loadedState.currentColor,
      position: Offset(
        position.dx - initialShapeSize / 2,
        position.dy - initialShapeSize / 2,
      ),
    );

    applyOperation(shapeOperation, persist: true);

    // Create connector
    final connectorOperation = CreateConnectorCanvasOperation(
      opId: const Uuid().v4(),
      connectorId: const Uuid().v4(),
      sourceShapeId: sourceShapeId,
      targetShapeId: shapeId,
      sourceAnchor: sourceAnchor,
      targetAnchor: targetAnchor,
      arrowType: ArrowType.end,
      color: _loadedState.currentColor,
    );

    applyOperation(connectorOperation, persist: true);

    state = _loadedState.copyWith(clearSelections: true);

    return (shape: shapeOperation, connector: connectorOperation);
  }

  /// Get the opposite anchor point.
  AnchorPoint _getOppositeAnchor(AnchorPoint anchor) {
    return switch (anchor) {
      AnchorPoint.top => AnchorPoint.bottom,
      AnchorPoint.bottom => AnchorPoint.top,
      AnchorPoint.left => AnchorPoint.right,
      AnchorPoint.right => AnchorPoint.left,
    };
  }

  /// Select a connector by ID.
  void selectConnector(String? connectorId) {
    if (state is! CanvasLoaded) return;

    if (connectorId == null) {
      // Just clear connector selection
      state = _loadedState.copyWith(clearSelections: true);
    } else {
      // Select connector and clear shape selection
      state = _loadedState
          .copyWith(clearSelections: true)
          .copyWith(selectedConnectorId: connectorId);
    }
  }

  /// Delete the currently selected connector.
  void deleteSelectedConnector() {
    if (state is! CanvasLoaded) return;

    final connectorId = _loadedState.selectedConnectorId;
    if (connectorId == null) return;

    final operation = DeleteConnectorCanvasOperation(
      opId: const Uuid().v4(),
      connectorId: connectorId,
    );

    applyOperation(operation, persist: true);
  }

  /// Hit test connectors at a canvas position.
  ///
  /// Returns the connector ID if a node or segment is hit.
  String? hitTestConnector(Offset canvasPosition) {
    if (state is! CanvasLoaded) return null;

    for (final connector in _loadedState.connectors.reversed) {
      // Check if hitting a node (waypoint or anchor)
      if (connector.hitTestNode(canvasPosition) != null) {
        return connector.id;
      }
      // Check if hitting a path segment
      if (connector.hitTestSegment(canvasPosition) != null) {
        return connector.id;
      }
    }

    return null;
  }

  /// Hit test a specific connector's nodes.
  ///
  /// Returns the node index if hit, null otherwise.
  int? hitTestConnectorNode(String connectorId, Offset canvasPosition) {
    if (state is! CanvasLoaded) return null;

    final connector = _loadedState.connectors.firstWhere(
      (c) => c.id == connectorId,
      orElse: () => throw StateError('Connector not found: $connectorId'),
    );

    final node = connector.hitTestNode(canvasPosition);
    if (node == null) return null;

    return connector.nodes.indexOf(node);
  }

  /// Get the edit intent for a connector at a canvas position.
  ///
  /// Returns a tuple of (connectorId, intent) if a connector is hit, null otherwise.
  /// This follows the same pattern as [getIntentAtPosition] for shapes.
  ({String connectorId, EditIntent intent})? getConnectorIntentAtPosition(
    Offset canvasPosition,
  ) {
    if (state is! CanvasLoaded) return null;

    for (final connector in _loadedState.connectors.reversed) {
      final intent = connector.getEditIntent(canvasPosition);
      if (intent != null) {
        return (connectorId: connector.id, intent: intent);
      }
    }
    return null;
  }

  /// Apply a move connector node operation (ephemeral, not persisted).
  ///
  /// This only updates the node position without optimization.
  /// Call [finalizeConnectorNodeMove] on release to persist waypoints.
  void _applyMoveConnectorNode(MoveConnectorNodeCanvasOperation operation) {
    if (state is! CanvasLoaded) return;

    final connectorIndex = _loadedState.connectors.indexWhere(
      (c) => c.id == operation.connectorId,
    );
    if (connectorIndex == -1) return;

    final connector = _loadedState.connectors[connectorIndex];

    // Apply snap-to-grid if enabled
    final snappedPosition = _loadedState.snapToGrid
        ? _snapOffset(operation.position)
        : operation.position;

    // Just update the node position (no optimization during drag)
    final newNodes = List<ConnectorNode>.from(connector.nodes);
    final node = newNodes[operation.nodeIndex];

    // Update position based on node type
    if (node is WaypointNode) {
      newNodes[operation.nodeIndex] = WaypointNode(position: snappedPosition);
    } else if (node is SegmentMidNode) {
      // During drag, keep it as SegmentMidNode (will be converted on finalize)
      newNodes[operation.nodeIndex] = SegmentMidNode(position: snappedPosition);
    }

    // Build path: skip SegmentMidNodes EXCEPT the one being dragged
    final newPath = <Offset>[];
    for (int i = 0; i < newNodes.length; i++) {
      final n = newNodes[i];
      // Include: anchors, waypoints, and the specific node being dragged
      if (n is! SegmentMidNode || i == operation.nodeIndex) {
        newPath.add(n.position);
      }
    }

    // Update connector
    final updatedConnector = connector.copyWith(nodes: newNodes, path: newPath);

    final updatedConnectors = List<CanvasConnector>.from(
      _loadedState.connectors,
    );
    updatedConnectors[connectorIndex] = updatedConnector;

    state = _loadedState.copyWith(connectors: updatedConnectors);
  }

  /// Finalize connector node movement (on release).
  ///
  /// This runs the router's optimization logic locally, then creates
  /// an operation that goes through applyOperation (same as remote).
  ///
  /// Returns the operation for broadcasting, or null if invalid.
  UpdateConnectorWaypointsCanvasOperation? finalizeConnectorNodeMove(
    String connectorId,
    int nodeIndex,
  ) {
    if (state is! CanvasLoaded) return null;

    final connector = _loadedState.connectors.firstWhere(
      (c) => c.id == connectorId,
      orElse: () => throw StateError('Connector not found'),
    );

    final node = connector.nodes[nodeIndex];

    // Use router to optimize nodes (convert mid → waypoint, add new mids, etc.)
    // This is local-only logic - remote operations receive final waypoints
    final optimizedNodes = _router.onMovedWaypoint(
      connector.nodes,
      nodeIndex,
      node.position,
    );

    // Extract waypoints from nodes (only WaypointNodes, not SegmentMidNodes)
    final waypoints = _extractWaypointsFromNodes(optimizedNodes);

    // Create operation and apply through the standard path
    final operation = UpdateConnectorWaypointsCanvasOperation(
      opId: const Uuid().v4(),
      connectorId: connectorId,
      waypoints: waypoints,
    );

    // Apply through applyOperation (local operation, persist)
    applyOperation(operation, persist: true);

    return operation;
  }

  /// Extract waypoints from nodes (only WaypointNodes, indexed by position).
  List<Waypoint> _extractWaypointsFromNodes(List<ConnectorNode> nodes) {
    final waypoints = <Waypoint>[];
    int waypointIndex = 0;

    for (final node in nodes) {
      if (node is WaypointNode) {
        waypoints.add(
          Waypoint(
            index: waypointIndex,
            x: node.position.dx,
            y: node.position.dy,
          ),
        );
        waypointIndex++;
      }
    }

    return waypoints;
  }

  /// Hit test anchor points on the selected shape.
  AnchorPoint? hitTestAnchor(Offset canvasPosition) {
    if (state is! CanvasLoaded) return null;

    final selectedShape = _loadedState.selectedShape;
    if (selectedShape == null) return null;

    return selectedShape.hitTestAnchor(canvasPosition);
  }

  /// Rebuild connectors after shapes have moved.
  ///
  /// This updates the connector anchor positions and recalculates routes
  /// using the router.
  void _rebuildConnectors() {
    if (state is! CanvasLoaded) return;

    final shapesById = _loadedState.shapesById;

    final updatedConnectors = _loadedState.connectors
        .map((connector) {
          final sourceShape = shapesById[connector.entity.sourceShapeId];
          final targetShape = shapesById[connector.entity.targetShapeId];

          if (sourceShape == null || targetShape == null) {
            return null;
          }

          // Rebuild connector with updated anchor positions
          return _buildCanvasConnector(
            entity: connector.entity,
            sourceShape: sourceShape,
            targetShape: targetShape,
          );
        })
        .whereType<CanvasConnector>()
        .toList();

    state = _loadedState.copyWith(connectors: updatedConnectors);
  }

  void _applyCreateConnector(
    CreateConnectorCanvasOperation operation, {
    bool persist = false,
  }) {
    if (state is! CanvasLoaded) return;

    final shapesById = _loadedState.shapesById;
    final sourceShape = shapesById[operation.sourceShapeId];
    final targetShape = shapesById[operation.targetShapeId];

    if (sourceShape == null || targetShape == null) return;

    final connector = Connector(
      id: operation.connectorId,
      sessionId: _sessionId,
      sourceShapeId: operation.sourceShapeId,
      targetShapeId: operation.targetShapeId,
      sourceAnchor: operation.sourceAnchor,
      targetAnchor: operation.targetAnchor,
      waypoints: [],
      arrowType: operation.arrowType,
      color: operation.color,
    );

    final canvasConnector = _buildCanvasConnector(
      entity: connector,
      sourceShape: sourceShape,
      targetShape: targetShape,
    );

    state = _loadedState.copyWith(
      connectors: [..._loadedState.connectors, canvasConnector],
    );

    if (persist) {
      _shapeServices.createConnector(connector);
    }
  }

  void _applyUpdateConnectorWaypoints(
    UpdateConnectorWaypointsCanvasOperation operation, {
    bool persist = false,
  }) {
    if (state is! CanvasLoaded) return;

    final shapesById = _loadedState.shapesById;
    Connector? entityToUpdate;

    final updatedConnectors = _loadedState.connectors.map((connector) {
      if (connector.id != operation.connectorId) return connector;

      final sourceShape = shapesById[connector.entity.sourceShapeId];
      final targetShape = shapesById[connector.entity.targetShapeId];

      if (sourceShape == null || targetShape == null) return connector;

      final updatedEntity = Connector(
        id: connector.entity.id,
        sessionId: connector.entity.sessionId,
        sourceShapeId: connector.entity.sourceShapeId,
        targetShapeId: connector.entity.targetShapeId,
        sourceAnchor: connector.entity.sourceAnchor,
        targetAnchor: connector.entity.targetAnchor,
        arrowType: connector.entity.arrowType,
        color: connector.entity.color,
        waypoints: operation.waypoints,
      );

      entityToUpdate = updatedEntity;

      // Rebuild connector with new waypoints
      return _buildCanvasConnector(
        entity: updatedEntity,
        sourceShape: sourceShape,
        targetShape: targetShape,
      );
    }).toList();

    state = _loadedState.copyWith(connectors: updatedConnectors);

    if (persist && entityToUpdate != null) {
      _shapeServices.updateConnector(entityToUpdate!);
    }
  }

  void _applyDeleteConnector(
    DeleteConnectorCanvasOperation operation, {
    bool persist = false,
  }) {
    if (state is! CanvasLoaded) return;

    final newConnectors = _loadedState.connectors
        .where((c) => c.id != operation.connectorId)
        .toList();

    state = _loadedState.copyWith(
      connectors: newConnectors,
      selectedConnectorId:
          _loadedState.selectedConnectorId == operation.connectorId
          ? null
          : _loadedState.selectedConnectorId,
    );

    if (persist) {
      _shapeServices.deleteConnector(operation.connectorId);
    }
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

/// Metadata for connector creation mode.
///
/// Groups all state related to drawing a new connector between shapes.
@immutable
class ConnectingModeState extends Equatable {
  const ConnectingModeState({
    required this.fromShapeId,
    required this.fromAnchor,
    this.previewEnd,
  });

  /// The shape ID being connected from.
  final String fromShapeId;

  /// The anchor point being connected from.
  final AnchorPoint fromAnchor;

  /// The current cursor position for preview line.
  final Offset? previewEnd;

  @override
  List<Object?> get props => [fromShapeId, fromAnchor, previewEnd];

  ConnectingModeState copyWith({Offset? previewEnd}) {
    return ConnectingModeState(
      fromShapeId: fromShapeId,
      fromAnchor: fromAnchor,
      previewEnd: previewEnd ?? this.previewEnd,
    );
  }
}

class CanvasLoaded extends CanvasState {
  const CanvasLoaded({
    required this.shapes,
    this.connectors = const [],
    this.selectedShapeId,
    this.selectedConnectorId,
    this.isEditingText = false,
    this.panOffset = Offset.zero,
    double zoom = 1.0,
    this.currentTool,
    this.currentColor = '#19191f',
    this.snapToGrid = true,
    this.connectingMode,
  }) : _zoom = zoom;

  /// All shapes in the session.
  final List<CanvasShape> shapes;

  /// All connectors in the session.
  final List<CanvasConnector> connectors;

  /// Currently selected shape ID.
  final String? selectedShapeId;

  /// Currently selected connector ID.
  final String? selectedConnectorId;

  /// Whether the selected shape's text is being edited (shows TextField overlay).
  final bool isEditingText;

  // --- Local state (UI-only, not persisted) ---

  /// Current pan offset of the canvas.
  final Offset panOffset;

  /// Current zoom level (1.0 = 100%).
  final double _zoom;

  double get zoom => _zoom.clamp(_zoomMin, _zoomMax);

  /// Currently selected drawing tool.
  final CanvasTool? currentTool;

  /// Currently selected color for new shapes.
  final String currentColor;

  /// Whether snap-to-grid is enabled.
  final bool snapToGrid;

  /// Connector creation mode state (null when not connecting).
  final ConnectingModeState? connectingMode;

  // --- Convenience getters for connecting mode ---

  /// Whether the user is currently creating a connector.
  bool get isConnecting => connectingMode != null;

  /// The shape ID being connected from (if in connecting mode).
  String? get connectingFromShapeId => connectingMode?.fromShapeId;

  /// The anchor point being connected from (if in connecting mode).
  AnchorPoint? get connectingFromAnchor => connectingMode?.fromAnchor;

  /// The current cursor position for preview line (if in connecting mode).
  Offset? get connectingPreviewEnd => connectingMode?.previewEnd;

  @override
  List<Object?> get props => [
    shapes,
    connectors,
    selectedShapeId,
    selectedConnectorId,
    isEditingText,
    panOffset,
    zoom,
    currentTool,
    currentColor,
    snapToGrid,
    connectingMode,
  ];

  CanvasPersistError toPersistError(BaseException exception) {
    return CanvasPersistError(
      exception: exception,
      shapes: shapes,
      connectors: connectors,
      selectedShapeId: selectedShapeId,
      selectedConnectorId: selectedConnectorId,
      isEditingText: isEditingText,
      panOffset: panOffset,
      zoom: zoom,
      currentTool: currentTool,
      currentColor: currentColor,
      snapToGrid: snapToGrid,
      connectingMode: connectingMode,
    );
  }

  CanvasLoaded copyWith({
    List<CanvasShape>? shapes,
    List<CanvasConnector>? connectors,
    String? selectedShapeId,
    String? selectedConnectorId,
    bool? isEditingText,
    Offset? panOffset,
    double? zoom,
    CanvasTool? currentTool,
    String? currentColor,
    bool? snapToGrid,
    ConnectingModeState? connectingMode,
    bool clearSelections = false,
    bool clearTool = false,
  }) {
    return CanvasLoaded(
      shapes: shapes ?? this.shapes,
      connectors: connectors ?? this.connectors,
      selectedShapeId: clearSelections
          ? null
          : (selectedShapeId ?? this.selectedShapeId),
      selectedConnectorId: clearSelections
          ? null
          : (selectedConnectorId ?? this.selectedConnectorId),
      isEditingText: clearSelections
          ? false
          : (isEditingText ?? this.isEditingText),
      panOffset: panOffset ?? this.panOffset,
      zoom: zoom ?? this.zoom,
      currentTool: clearTool ? null : (currentTool ?? this.currentTool),
      currentColor: currentColor ?? this.currentColor,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      connectingMode: clearSelections
          ? null
          : (connectingMode ?? this.connectingMode),
    );
  }

  /// Get the currently selected shape (if any).
  CanvasShape? get selectedShape => selectedShapeId != null
      ? shapes.firstWhere((s) => s.id == selectedShapeId)
      : null;

  /// Get the currently selected connector (if any).
  CanvasConnector? get selectedConnector => selectedConnectorId != null
      ? connectors.firstWhere((c) => c.id == selectedConnectorId)
      : null;

  /// Get the shape being connected from (if in connecting mode).
  CanvasShape? get connectingFromShape => connectingFromShapeId != null
      ? shapes.firstWhere((s) => s.id == connectingFromShapeId)
      : null;

  /// Get shapes indexed by ID for quick lookup.
  Map<String, CanvasShape> get shapesById => {
    for (final shape in shapes) shape.id: shape,
  };
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
    super.connectors,
    super.selectedShapeId,
    super.selectedConnectorId,
    super.isEditingText,
    super.panOffset,
    super.zoom,
    super.currentTool,
    super.currentColor,
    super.snapToGrid,
    super.connectingMode,
  });

  final BaseException exception;

  @override
  List<Object?> get props => [exception, ...super.props];
}
