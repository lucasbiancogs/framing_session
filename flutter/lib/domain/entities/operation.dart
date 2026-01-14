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

class MoveOperation extends Operation {
  const MoveOperation({
    required super.opId,
    required super.shapeId,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  @override
  List<Object?> get props => [...super.props, x, y];
}

class ResizeOperation extends Operation {
  const ResizeOperation({
    required super.opId,
    required super.shapeId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  List<Object?> get props => [...super.props, x, y, width, height];
}

class CreateOperation extends Operation {
  const CreateOperation({
    required super.opId,
    required super.shapeId,
    required this.shapeType,
    required this.color,
    required this.x,
    required this.y,
  });

  final ShapeType shapeType;
  final String color;
  final double x;
  final double y;

  @override
  List<Object?> get props => [...super.props, shapeType, x, y, color];
}

class DeleteOperation extends Operation {
  const DeleteOperation({required super.opId, required super.shapeId});

  @override
  List<Object?> get props => [...super.props];
}

class TextOperation extends Operation {
  const TextOperation({
    required super.opId,
    required super.shapeId,
    required this.text,
  });

  final String text;
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
