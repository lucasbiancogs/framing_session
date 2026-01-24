import 'package:equatable/equatable.dart';
import 'package:whiteboard/domain/entities/anchor_point.dart';
import 'package:whiteboard/domain/entities/arrow_type.dart';
import 'package:whiteboard/domain/entities/shape_type.dart';
import 'package:whiteboard/domain/entities/waypoint.dart';

sealed class Operation extends Equatable {
  const Operation({required this.opId, required this.shapeId});

  final String opId;
  final String shapeId;

  @override
  List<Object?> get props => [opId, shapeId];
}

class MoveShapeOperation extends Operation {
  const MoveShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.x,
    required this.y,
  });

  final double x, y;

  @override
  List<Object?> get props => [...super.props, x, y];
}

class ResizeShapeOperation extends Operation {
  const ResizeShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x, y, width, height;

  @override
  List<Object?> get props => [...super.props, x, y, width, height];
}

class CreateShapeOperation extends Operation {
  const CreateShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.shapeType,
    required this.color,
    required this.x,
    required this.y,
  });

  final ShapeType shapeType;
  final String color;
  final double x, y;

  @override
  List<Object?> get props => [...super.props, shapeType, x, y, color];
}

class DeleteShapeOperation extends Operation {
  const DeleteShapeOperation({required super.opId, required super.shapeId});

  @override
  List<Object?> get props => [...super.props];
}

class TextShapeOperation extends Operation {
  const TextShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
  });

  final String text;
}

/// Paste a shape with all properties (for copy/paste and duplicate).
class PasteShapeOperation extends Operation {
  const PasteShapeOperation({
    required super.opId,
    required super.shapeId,
    required this.shapeType,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    this.text,
  });

  final ShapeType shapeType;
  final double x, y, width, height;
  final String color;
  final String? text;

  @override
  List<Object?> get props => [
    ...super.props,
    shapeType,
    x,
    y,
    width,
    height,
    color,
    text,
  ];
}

// -------------------------------------------------------------------------
// Connector Operations
// -------------------------------------------------------------------------

/// Create a new connector between two shapes.
class CreateConnectorOperation extends Operation {
  const CreateConnectorOperation({
    required super.opId,
    required super.shapeId, // This is the connector ID
    required this.sourceShapeId,
    required this.targetShapeId,
    required this.sourceAnchor,
    required this.targetAnchor,
    required this.arrowType,
    required this.color,
  });

  final String sourceShapeId;
  final String targetShapeId;
  final AnchorPoint sourceAnchor;
  final AnchorPoint targetAnchor;
  final ArrowType arrowType;
  final String color;

  @override
  List<Object?> get props => [
    ...super.props,
    sourceShapeId,
    targetShapeId,
    sourceAnchor,
    targetAnchor,
    arrowType,
    color,
  ];
}

/// Update connector waypoints (during segment dragging).
class UpdateConnectorWaypointsOperation extends Operation {
  const UpdateConnectorWaypointsOperation({
    required super.opId,
    required super.shapeId, // This is the connector ID
    required this.waypoints,
  });

  final List<Waypoint> waypoints;

  @override
  List<Object?> get props => [...super.props, waypoints];
}

/// Delete a connector.
class DeleteConnectorOperation extends Operation {
  const DeleteConnectorOperation({
    required super.opId,
    required super.shapeId, // This is the connector ID
  });
}

// -------------------------------------------------------------------------
// Ephemeral Operations (broadcast but not persisted)
// -------------------------------------------------------------------------

/// Update the connecting preview position (ephemeral, not persisted).
class UpdateConnectingPreviewOperation extends Operation {
  const UpdateConnectingPreviewOperation({
    required super.opId,
    required super.shapeId, // This is the source shape ID
    required this.sourceAnchor,
    required this.x,
    required this.y,
  });

  final AnchorPoint sourceAnchor;
  final double x, y;

  @override
  List<Object?> get props => [...super.props, sourceAnchor, x, y];
}

/// Move a connector node during drag (ephemeral, not persisted).
class MoveConnectorNodeOperation extends Operation {
  const MoveConnectorNodeOperation({
    required super.opId,
    required super.shapeId, // This is the connector ID
    required this.nodeIndex,
    required this.x,
    required this.y,
  });

  final int nodeIndex;
  final double x, y;

  @override
  List<Object?> get props => [...super.props, nodeIndex, x, y];
}
