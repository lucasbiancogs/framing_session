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
    required this.rotation,
    this.text,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String shapeType; // Raw string from database enum
  final double height;
  final double width;
  final double x;
  final double y;
  final String color;
  final double rotation;
  final String? text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Create from database map (Supabase response)
  factory ShapeDto.fromJson(Map<String, dynamic> json) {
    return ShapeDto(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      shapeType: json['shape_type'] as String,
      height: (json['height'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      color: json['color'] as String,
      rotation: (json['rotation'] as num).toDouble(),
      text: json['text'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to database map (for INSERT/UPDATE)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'shape_type': shapeType,
      'height': height,
      'width': width,
      'x': x,
      'y': y,
      'color': color,
      'rotation': rotation,
      'text': text,
      // created_at and updated_at are set by database defaults
    };
  }

  /// Convert to domain entity
  Shape toEntity() {
    return Shape(
      id: id,
      sessionId: sessionId,
      shapeType: ShapeType.values.byName(shapeType),
      height: height,
      width: width,
      x: x,
      y: y,
      color: color,
      rotation: rotation,
      text: text,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create from domain entity
  factory ShapeDto.fromEntity(Shape entity) {
    return ShapeDto(
      id: entity.id,
      sessionId: entity.sessionId,
      shapeType: entity.shapeType.name,
      height: entity.height,
      width: entity.width,
      x: entity.x,
      y: entity.y,
      color: entity.color,
      rotation: entity.rotation,
      text: entity.text,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
