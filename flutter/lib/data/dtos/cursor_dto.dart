import 'package:whiteboard/domain/entities/cursor.dart';

class CursorDto {
  const CursorDto({required this.userId, required this.x, required this.y});

  final String userId;
  final double x;
  final double y;

  factory CursorDto.fromJson(Map<String, dynamic> json) {
    return CursorDto(
      userId: json['user_id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'user_id': userId, 'x': x, 'y': y};

  factory CursorDto.fromEntity(Cursor entity) =>
      CursorDto(userId: entity.userId, x: entity.x, y: entity.y);

  Cursor toEntity() => Cursor(userId: userId, x: x, y: y);
}
