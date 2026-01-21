import 'dart:ui' show Offset, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/domain/entities/arrow_type.dart';
import 'package:whiteboard/domain/entities/connector.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_connector.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_shape.dart';
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
enum CanvasTool { select, rectangle, circle, triangle, text }

class CanvasVM extends StateNotifier<CanvasState> {
  CanvasVM(this._shapeServices, this._sessionId)
    : super(const CanvasLoading()) {
    _loadShapes();
  }

  final ShapeServices _shapeServices;
  final String _sessionId;

  final double gridSize = 20.0;
  final double initialShapeSize = 150.0;

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

    state = _loadedState.copyWith(isEditingText: false);
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
  void applyOperation(CanvasOperation operation) {
    if (state is! CanvasLoaded) return;

    // Deduplicate operations
    if (_appliedOpIds.contains(operation.opId)) return;
    _appliedOpIds.add(operation.opId);

    // Handle connector operations separately
    if (operation is CreateConnectorCanvasOperation ||
        operation is UpdateConnectorWaypointsCanvasOperation ||
        operation is DeleteConnectorCanvasOperation) {
      _applyConnectorOperation(operation);
      return;
    }

    final newShapes = switch (operation) {
      MoveShapeOperation(:final shapeId, :final position) => _applyMove(
        shapeId,
        position,
      ),
      ResizeShapeOperation(:final shapeId, :final bounds) => _applyResize(
        shapeId,
        bounds,
      ),
      TextShapeOperation(:final shapeId, :final text) => _applyTextEdit(
        shapeId,
        text,
      ),
      CreateShapeOperation() => _applyCreate(operation),
      DeleteShapeOperation(:final shapeId) => _applyDelete(shapeId),
      _ => _loadedState.shapes,
    };

    state = _loadedState.copyWith(shapes: newShapes);

    // Rebuild connectors when shapes move/resize
    if (operation is MoveShapeOperation || operation is ResizeShapeOperation) {
      _rebuildConnectors();
    }

    // Schedule debounced persistence for update operations
    _scheduleDebouncedPersist(operation);
  }

  CanvasOperation? getOperationByIntent({
    required String shapeId,
    required EditIntent intent,
    required Rect initialBounds,
    required Offset totalDelta,
  }) {
    final opId = const Uuid().v4();

    return switch (intent) {
      MoveIntent() => MoveShapeOperation(
        opId: opId,
        shapeId: shapeId,
        position: initialBounds.topLeft + totalDelta,
      ),
      ResizeIntent(:final handle) => ResizeShapeOperation(
        opId: opId,
        shapeId: shapeId,
        handle: handle,
        bounds: _calculateNewBounds(initialBounds, handle, totalDelta),
      ),
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
      case CreateShapeOperation():
        final shape = _loadedState.shapes.firstWhere(
          (s) => s.id == operation.shapeId,
          orElse: () =>
              throw StateError('Shape not found: ${operation.shapeId}'),
        );
        _shapeServices.createShape(shape.entity);
        return;
      case DeleteShapeOperation():
        _shapeServices.deleteShape(operation.shapeId);
        return;
      default:
        break;
    }

    // Only debounce move, resize, rotate, and text operations
    final shapeId = switch (operation) {
      MoveShapeOperation(:final shapeId) => shapeId,
      ResizeShapeOperation(:final shapeId) => shapeId,
      TextShapeOperation(:final shapeId) => shapeId,
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

    return _loadedState.shapes.map((shape) {
      if (shape.id != shapeId) return shape;

      return shape.applyMove(snappedPosition);
    }).toList();
  }

  List<CanvasShape> _applyResize(String shapeId, Rect bounds) {
    final snappedBounds = _loadedState.snapToGrid ? _snapRect(bounds) : bounds;

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

  List<CanvasShape> _applyCreate(CreateShapeOperation operation) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final shape = Shape(
      id: operation.shapeId,
      sessionId: _sessionId,
      shapeType: operation.shapeType,
      x: operation.x,
      y: operation.y,
      width: initialShapeSize,
      height: initialShapeSize,
      color: operation.color,
      rotation: 0,
    );

    final canvasShape = CanvasShape.createCanvasShape(shape);

    return [..._loadedState.shapes, canvasShape];
  }

  /// Delete the currently selected shape.
  List<CanvasShape> _applyDelete(String shapeId) {
    if (state is! CanvasLoaded) return _loadedState.shapes;

    final newShapes = _loadedState.shapes
        .where((s) => s.id != shapeId)
        .toList();

    selectShape(null);

    state = _loadedState.copyWith(shapes: newShapes);

    return newShapes;
  }

  ShapeType? toolToShapeType(CanvasTool tool) {
    return switch (tool) {
      CanvasTool.rectangle => ShapeType.rectangle,
      CanvasTool.circle => ShapeType.circle,
      CanvasTool.triangle => ShapeType.triangle,
      CanvasTool.text => ShapeType.text,
      CanvasTool.select => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Connector Methods
  // ---------------------------------------------------------------------------

  /// Start connecting mode from a shape anchor.
  void startConnecting(String shapeId, AnchorPoint anchor) {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(
      isConnecting: true,
      connectingFromShapeId: shapeId,
      connectingFromAnchor: anchor,
      selectedShapeId: shapeId,
    );
  }

  /// Update the connecting preview position.
  void updateConnectingPreview(Offset position) {
    if (state is! CanvasLoaded || !_loadedState.isConnecting) return;

    state = _loadedState.copyWith(connectingPreviewEnd: position);
  }

  /// Cancel connecting mode.
  void cancelConnecting() {
    if (state is! CanvasLoaded) return;

    state = _loadedState.copyWith(clearConnecting: true);
  }

  /// Complete connecting to a target shape anchor.
  void completeConnecting(String targetShapeId, AnchorPoint targetAnchor) {
    if (state is! CanvasLoaded || !_loadedState.isConnecting) return;

    final sourceShapeId = _loadedState.connectingFromShapeId;
    final sourceAnchor = _loadedState.connectingFromAnchor;

    if (sourceShapeId == null || sourceAnchor == null) return;

    // Don't allow self-connections
    if (sourceShapeId == targetShapeId) {
      cancelConnecting();
      return;
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

    applyOperation(operation);

    state = _loadedState.copyWith(clearConnecting: true);
  }

  /// Complete connecting by creating a new shape and connector.
  void completeConnectingWithNewShape(Offset position) {
    if (state is! CanvasLoaded || !_loadedState.isConnecting) return;

    final sourceShapeId = _loadedState.connectingFromShapeId;
    final sourceAnchor = _loadedState.connectingFromAnchor;

    if (sourceShapeId == null || sourceAnchor == null) return;

    // Determine the target anchor based on source anchor (opposite side)
    final targetAnchor = _getOppositeAnchor(sourceAnchor);

    // Create new shape
    final shapeId = const Uuid().v4();
    final shapeOperation = CreateShapeOperation(
      opId: const Uuid().v4(),
      shapeId: shapeId,
      shapeType: ShapeType.rectangle,
      color: _loadedState.currentColor,
      x: position.dx - initialShapeSize / 2,
      y: position.dy - initialShapeSize / 2,
    );

    applyOperation(shapeOperation);

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

    applyOperation(connectorOperation);

    state = _loadedState.copyWith(clearConnecting: true);
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

    state = _loadedState.copyWith(
      selectedConnectorId: connectorId,
      selectedShapeId: null,
    );
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

    applyOperation(operation);
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

  // ---------------------------------------------------------------------------
  // Extended applyOperation to handle connector operations
  // ---------------------------------------------------------------------------

  /// Apply a connector operation.
  void _applyConnectorOperation(CanvasOperation operation) {
    switch (operation) {
      case CreateConnectorCanvasOperation():
        _applyCreateConnector(operation);
      case UpdateConnectorWaypointsCanvasOperation():
        _applyUpdateConnectorWaypoints(operation);
      case DeleteConnectorCanvasOperation():
        _applyDeleteConnector(operation);
      default:
        break;
    }
  }

  void _applyCreateConnector(CreateConnectorCanvasOperation operation) {
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

    // Persist to database
    _shapeServices.createConnector(connector);
  }

  void _applyUpdateConnectorWaypoints(
    UpdateConnectorWaypointsCanvasOperation operation,
  ) {
    if (state is! CanvasLoaded) return;

    final shapesById = _loadedState.shapesById;

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

      // Rebuild connector with new waypoints
      return _buildCanvasConnector(
        entity: updatedEntity,
        sourceShape: sourceShape,
        targetShape: targetShape,
      );
    }).toList();

    state = _loadedState.copyWith(connectors: updatedConnectors);
  }

  void _applyDeleteConnector(DeleteConnectorCanvasOperation operation) {
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

    // Persist to database
    _shapeServices.deleteConnector(operation.connectorId);
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

class CanvasLoaded extends CanvasState {
  const CanvasLoaded({
    required this.shapes,
    this.connectors = const [],
    this.selectedShapeId,
    this.selectedConnectorId,
    this.isEditingText = false,
    this.panOffset = Offset.zero,
    this.zoom = 1.0,
    this.currentTool = CanvasTool.select,
    this.currentColor = '#4ED09A',
    this.snapToGrid = false,
    // Connecting mode state
    this.isConnecting = false,
    this.connectingFromShapeId,
    this.connectingFromAnchor,
    this.connectingPreviewEnd,
  });

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
  final double zoom;

  /// Currently selected drawing tool.
  final CanvasTool currentTool;

  /// Currently selected color for new shapes.
  final String currentColor;

  /// Whether snap-to-grid is enabled.
  final bool snapToGrid;

  // --- Connecting mode state ---

  /// Whether the user is currently creating a connector.
  final bool isConnecting;

  /// The shape ID being connected from.
  final String? connectingFromShapeId;

  /// The anchor point being connected from.
  final AnchorPoint? connectingFromAnchor;

  /// The current cursor position for preview line.
  final Offset? connectingPreviewEnd;

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
    isConnecting,
    connectingFromShapeId,
    connectingFromAnchor,
    connectingPreviewEnd,
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
      isConnecting: isConnecting,
      connectingFromShapeId: connectingFromShapeId,
      connectingFromAnchor: connectingFromAnchor,
      connectingPreviewEnd: connectingPreviewEnd,
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
    bool? isConnecting,
    String? connectingFromShapeId,
    AnchorPoint? connectingFromAnchor,
    Offset? connectingPreviewEnd,
    bool clearSelection = false,
    bool clearConnecting = false,
  }) {
    return CanvasLoaded(
      shapes: shapes ?? this.shapes,
      connectors: connectors ?? this.connectors,
      selectedShapeId: clearSelection
          ? null
          : (selectedShapeId ?? this.selectedShapeId),
      selectedConnectorId: clearSelection
          ? null
          : (selectedConnectorId ?? this.selectedConnectorId),
      isEditingText: clearSelection
          ? false
          : (isEditingText ?? this.isEditingText),
      panOffset: panOffset ?? this.panOffset,
      zoom: zoom ?? this.zoom,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      isConnecting: clearConnecting
          ? false
          : (isConnecting ?? this.isConnecting),
      connectingFromShapeId: clearConnecting
          ? null
          : (connectingFromShapeId ?? this.connectingFromShapeId),
      connectingFromAnchor: clearConnecting
          ? null
          : (connectingFromAnchor ?? this.connectingFromAnchor),
      connectingPreviewEnd: clearConnecting
          ? null
          : (connectingPreviewEnd ?? this.connectingPreviewEnd),
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
    super.isConnecting,
    super.connectingFromShapeId,
    super.connectingFromAnchor,
    super.connectingPreviewEnd,
  });

  final BaseException exception;

  @override
  List<Object?> get props => [exception, ...super.props];
}
