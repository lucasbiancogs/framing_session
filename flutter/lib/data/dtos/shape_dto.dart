import 'package:whiteboard/domain/entities/shape.dart';
import 'package:whiteboard/domain/entities/shape_type.dart';

class ShapeDto {
  const ShapeDto({
    required this.id,
    required this.sessionId,
    required this.shapeType,
    required this.height,
    required this.width,
    required this.x,
    required this.y,
    required this.color,
    this.text,
  });

  final String id;
  final String sessionId;
  final String shapeType; // Raw string from database enum
  final double height;
  final double width;
  final double x;
  final double y;
  final String color;
  final String? text;

  /// Create from database map (Supabase response)
  factory ShapeDto.fromJson(Map<String, dynamic> json) => ShapeDto(
    id: json['id'] as String,
    sessionId: json['session_id'] as String,
    shapeType: json['shape_type'] as String,
    height: (json['height'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    color: json['color'] as String,
    text: json['text'] as String?,
  );

  /// Convert to database map (for INSERT/UPDATE)
  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'shape_type': shapeType,
    'height': height,
    'width': width,
    'x': x,
    'y': y,
    'color': color,
    'text': text,
  };

  /// Convert to domain entity
  Shape toEntity() => Shape(
    id: id,
    sessionId: sessionId,
    shapeType: ShapeType.values.byName(shapeType),
    height: height,
    width: width,
    x: x,
    y: y,
    color: color,
    text: text,
  );

  /// Create from domain entity
  factory ShapeDto.fromEntity(Shape entity) => ShapeDto(
    id: entity.id,
    sessionId: entity.sessionId,
    shapeType: entity.shapeType.name,
    height: entity.height,
    width: entity.width,
    x: entity.x,
    y: entity.y,
    color: entity.color,
    text: entity.text,
  );
}
