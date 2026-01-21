import 'package:whiteboard/data/dtos/waypoint_dto.dart';
import 'package:whiteboard/data/dtos/anchor_point_dto.dart';
import 'package:whiteboard/data/dtos/arrow_type_dto.dart';
import 'package:whiteboard/domain/entities/connector.dart';

class ConnectorDto {
  const ConnectorDto({
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
  final AnchorPointDto sourceAnchor;
  final AnchorPointDto targetAnchor;
  final ArrowTypeDto arrowType;
  final String color;
  final List<WaypointDto> waypoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConnectorDto.fromJson(Map<String, dynamic> json) => ConnectorDto(
    id: json['id'] as String,
    sessionId: json['session_id'] as String,
    sourceShapeId: json['source_shape_id'] as String,
    targetShapeId: json['target_shape_id'] as String,
    sourceAnchor: AnchorPointDto.fromString(json['source_anchor'] as String),
    targetAnchor: AnchorPointDto.fromString(json['target_anchor'] as String),
    arrowType: ArrowTypeDto.fromString(json['arrow_type'] as String),
    color: json['color'] as String,
    waypoints: (json['waypoints'] as List<dynamic>)
        .map((wp) => WaypointDto.fromJson(wp))
        .toList(),
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'source_shape_id': sourceShapeId,
    'target_shape_id': targetShapeId,
    'source_anchor': sourceAnchor.raw,
    'target_anchor': targetAnchor.raw,
    'arrow_type': arrowType.raw,
    'color': color,
    'waypoints': waypoints,
  };

  /// Convert to domain entity
  Connector toEntity() => Connector(
    id: id,
    sessionId: sessionId,
    sourceShapeId: sourceShapeId,
    targetShapeId: targetShapeId,
    sourceAnchor: sourceAnchor.toEntity(),
    targetAnchor: targetAnchor.toEntity(),
    arrowType: arrowType.toEntity(),
    color: color,
    waypoints: waypoints.map((wp) => wp.toEntity()).toList(),
  );

  /// Create from domain entity
  factory ConnectorDto.fromEntity(Connector entity) => ConnectorDto(
    id: entity.id,
    sessionId: entity.sessionId,
    sourceShapeId: entity.sourceShapeId,
    targetShapeId: entity.targetShapeId,
    sourceAnchor: AnchorPointDto.fromString(entity.sourceAnchor.name),
    targetAnchor: AnchorPointDto.fromString(entity.targetAnchor.name),
    arrowType: ArrowTypeDto.fromString(entity.arrowType.name),
    color: entity.color,
    waypoints: entity.waypoints
        .map((wp) => WaypointDto.fromEntity(wp))
        .toList(),
  );
}
