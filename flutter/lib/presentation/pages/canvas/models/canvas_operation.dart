import 'dart:ui' show Offset, Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/domain/entities/arrow_type.dart';
import 'package:whiteboard/domain/entities/operation.dart';
import 'package:whiteboard/domain/entities/shape_type.dart';
import 'package:whiteboard/domain/entities/waypoint.dart';

import 'edit_intent.dart';

/// An immutable operation that describes a change to a shape.
///
/// Operations use **absolute values** (not deltas) so that the last operation
/// always represents the correct final state. This is a "Last Write Wins" (LWW)
/// approach that ensures consistency even if intermediate updates are lost.
///
/// Operations are:
/// - Applied locally (optimistic update)
/// - Broadcast to other clients
/// - Consumed by all clients (including the sender)
///
/// Operations, not state, are the unit of collaboration.
@immutable
sealed class CanvasOperation extends Equatable {
  const CanvasOperation({required this.opId, required this.shapeId});

  /// Unique identifier for this operation (for deduplication).
  final String opId;

  /// The shape this operation targets.
  final String shapeId;

  factory CanvasOperation.fromEntity(Operation entity) {
    return switch (entity) {
      MoveShapeOperation() => MoveShapeCanvasOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        position: Offset(entity.x, entity.y),
      ),
      ResizeShapeOperation() => ResizeShapeCanvasOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        handle: ResizeHandle.topLeft,
        bounds: Rect.fromLTWH(entity.x, entity.y, entity.width, entity.height),
      ),
      CreateShapeOperation() => CreateShapeCanvasOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        shapeType: entity.shapeType,
        color: entity.color,
        position: Offset(entity.x, entity.y),
      ),
      DeleteShapeOperation() => DeleteShapeCanvasOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
      ),
      TextShapeOperation() => TextShapeCanvasOperation(
        opId: entity.opId,
        shapeId: entity.shapeId,
        text: entity.text,
      ),
      // Connector operations
      CreateConnectorOperation() => CreateConnectorCanvasOperation(
        opId: entity.opId,
        connectorId: entity.shapeId,
        sourceShapeId: entity.sourceShapeId,
        targetShapeId: entity.targetShapeId,
        sourceAnchor: entity.sourceAnchor,
        targetAnchor: entity.targetAnchor,
        arrowType: entity.arrowType,
        color: entity.color,
      ),
      UpdateConnectorWaypointsOperation() =>
        UpdateConnectorWaypointsCanvasOperation(
          opId: entity.opId,
          connectorId: entity.shapeId,
          waypoints: entity.waypoints,
        ),
      DeleteConnectorOperation() => DeleteConnectorCanvasOperation(
        opId: entity.opId,
        connectorId: entity.shapeId,
      ),
      // Ephemeral operations
      UpdateConnectingPreviewOperation() =>
        UpdateConnectingPreviewCanvasOperation(
          opId: entity.opId,
          sourceShapeId: entity.shapeId,
          sourceAnchor: entity.sourceAnchor,
          previewPosition: Offset(entity.x, entity.y),
        ),
      MoveConnectorNodeOperation() => MoveConnectorNodeCanvasOperation(
        opId: entity.opId,
        connectorId: entity.shapeId,
        nodeIndex: entity.nodeIndex,
        position: Offset(entity.x, entity.y),
      ),
    };
  }

  Operation toEntity();

  @override
  List<Object?> get props => [opId, shapeId];
}

/// Move a shape to an absolute position.
class MoveShapeCanvasOperation extends CanvasOperation {
  const MoveShapeCanvasOperation({
    required super.opId,
    required super.shapeId,
    required this.position,
  });

  /// The final absolute position (top-left corner) of the shape.
  final Offset position;

  @override
  Operation toEntity() => MoveShapeOperation(
    opId: opId,
    shapeId: shapeId,
    x: position.dx,
    y: position.dy,
  );

  @override
  List<Object?> get props => [...super.props, position];
}

/// Resize a shape to absolute bounds.
class ResizeShapeCanvasOperation extends CanvasOperation {
  const ResizeShapeCanvasOperation({
    required super.opId,
    required super.shapeId,
    required this.handle,
    required this.bounds,
  });

  /// The handle used for the resize (for cursor feedback).
  final ResizeHandle handle;

  /// The final absolute bounds (x, y, width, height) of the shape.
  final Rect bounds;

  @override
  Operation toEntity() => ResizeShapeOperation(
    opId: opId,
    shapeId: shapeId,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );

  @override
  List<Object?> get props => [...super.props, handle, bounds];
}

/// Create a new shape.
class CreateShapeCanvasOperation extends CanvasOperation {
  const CreateShapeCanvasOperation({
    required super.opId,
    required super.shapeId,
    required this.shapeType,
    required this.color,
    required this.position,
  });

  final Offset position;
  final String color;
  final ShapeType shapeType;

  @override
  Operation toEntity() => CreateShapeOperation(
    opId: opId,
    shapeId: shapeId,
    color: color,
    x: position.dx,
    y: position.dy,
    shapeType: shapeType,
  );

  @override
  List<Object?> get props => [...super.props, position, shapeType, color];
}

/// Delete a shape.
class DeleteShapeCanvasOperation extends CanvasOperation {
  const DeleteShapeCanvasOperation({
    required super.opId,
    required super.shapeId,
  });

  @override
  Operation toEntity() => DeleteShapeOperation(opId: opId, shapeId: shapeId);
}

/// Update a shape's text content.
class TextShapeCanvasOperation extends CanvasOperation {
  const TextShapeCanvasOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
  });

  /// The new text content for the shape.
  final String text;

  @override
  Operation toEntity() =>
      TextShapeOperation(opId: opId, shapeId: shapeId, text: text);

  @override
  List<Object?> get props => [...super.props, text];
}

// -------------------------------------------------------------------------
// Connector Operations
// -------------------------------------------------------------------------

/// Create a new connector between two shapes.
class CreateConnectorCanvasOperation extends CanvasOperation {
  const CreateConnectorCanvasOperation({
    required super.opId,
    required this.connectorId,
    required this.sourceShapeId,
    required this.targetShapeId,
    required this.sourceAnchor,
    required this.targetAnchor,
    required this.arrowType,
    required this.color,
  }) : super(shapeId: connectorId);

  final String connectorId;
  final String sourceShapeId;
  final String targetShapeId;
  final AnchorPoint sourceAnchor;
  final AnchorPoint targetAnchor;
  final ArrowType arrowType;
  final String color;

  @override
  Operation toEntity() => CreateConnectorOperation(
    opId: opId,
    shapeId: connectorId,
    sourceShapeId: sourceShapeId,
    targetShapeId: targetShapeId,
    sourceAnchor: sourceAnchor,
    targetAnchor: targetAnchor,
    arrowType: arrowType,
    color: color,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    connectorId,
    sourceShapeId,
    targetShapeId,
    sourceAnchor,
    targetAnchor,
    arrowType,
    color,
  ];
}

/// Update connector waypoints.
class UpdateConnectorWaypointsCanvasOperation extends CanvasOperation {
  const UpdateConnectorWaypointsCanvasOperation({
    required super.opId,
    required this.connectorId,
    required this.waypoints,
  }) : super(shapeId: connectorId);

  final String connectorId;
  final List<Waypoint> waypoints;

  @override
  Operation toEntity() => UpdateConnectorWaypointsOperation(
    opId: opId,
    shapeId: connectorId,
    waypoints: waypoints,
  );

  @override
  List<Object?> get props => [...super.props, connectorId, waypoints];
}

/// Delete a connector.
class DeleteConnectorCanvasOperation extends CanvasOperation {
  const DeleteConnectorCanvasOperation({
    required super.opId,
    required this.connectorId,
  }) : super(shapeId: connectorId);

  final String connectorId;

  @override
  Operation toEntity() =>
      DeleteConnectorOperation(opId: opId, shapeId: connectorId);

  @override
  List<Object?> get props => [...super.props, connectorId];
}

// -------------------------------------------------------------------------
// Ephemeral Operations (broadcast but not persisted)
// -------------------------------------------------------------------------

/// Update the connecting preview position (ephemeral, not persisted).
///
/// This shows other users where a connector is being drawn to.
class UpdateConnectingPreviewCanvasOperation extends CanvasOperation {
  const UpdateConnectingPreviewCanvasOperation({
    required super.opId,
    required this.sourceShapeId,
    required this.sourceAnchor,
    required this.previewPosition,
  }) : super(shapeId: sourceShapeId);

  final String sourceShapeId;
  final AnchorPoint sourceAnchor;
  final Offset previewPosition;

  @override
  Operation toEntity() => UpdateConnectingPreviewOperation(
    opId: opId,
    shapeId: sourceShapeId,
    sourceAnchor: sourceAnchor,
    x: previewPosition.dx,
    y: previewPosition.dy,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    sourceShapeId,
    sourceAnchor,
    previewPosition,
  ];
}

/// Move a connector node during drag (ephemeral, not persisted).
///
/// This shows other users the intermediate position while dragging a node.
/// The final position is persisted via [UpdateConnectorWaypointsCanvasOperation].
class MoveConnectorNodeCanvasOperation extends CanvasOperation {
  const MoveConnectorNodeCanvasOperation({
    required super.opId,
    required this.connectorId,
    required this.nodeIndex,
    required this.position,
  }) : super(shapeId: connectorId);

  final String connectorId;
  final int nodeIndex;
  final Offset position;

  @override
  Operation toEntity() => MoveConnectorNodeOperation(
    opId: opId,
    shapeId: connectorId,
    nodeIndex: nodeIndex,
    x: position.dx,
    y: position.dy,
  );

  @override
  List<Object?> get props => [...super.props, connectorId, nodeIndex, position];
}
