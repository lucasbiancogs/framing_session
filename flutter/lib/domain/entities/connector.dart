import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'anchor_point.dart';
import 'arrow_type.dart';
import 'waypoint.dart';

/// Represents a connector between two shapes on the whiteboard canvas.
///
/// This is a domain entity — immutable and contains only business data.
/// Matches the PostgreSQL table: connectors
@immutable
class Connector extends Equatable {
  const Connector({
    required this.id,
    required this.sessionId,
    required this.sourceShapeId,
    required this.targetShapeId,
    required this.sourceAnchor,
    required this.targetAnchor,
    required this.arrowType,
    required this.color,
    required this.waypoints,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String sourceShapeId;
  final String targetShapeId;
  final AnchorPoint sourceAnchor;
  final AnchorPoint targetAnchor;
  final ArrowType arrowType;
  final String color;
  final List<Waypoint> waypoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    sessionId,
    sourceShapeId,
    targetShapeId,
    sourceAnchor,
    targetAnchor,
    arrowType,
    color,
    waypoints,
    createdAt,
    updatedAt,
  ];
}
