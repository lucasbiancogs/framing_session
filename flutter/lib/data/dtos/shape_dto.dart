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
  factory ShapeDto.fromMap(Map<String, dynamic> map) {
    return ShapeDto(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      shapeType: map['shape_type'] as String,
      height: (map['height'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      color: map['color'] as String,
      rotation: (map['rotation'] as num).toDouble(),
      text: map['text'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convert to database map (for INSERT/UPDATE)
  Map<String, dynamic> toMap() {
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
