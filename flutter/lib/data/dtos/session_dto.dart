import 'package:whiteboard/domain/entities/session.dart';

class SessionDto {
  const SessionDto({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Create from database map (Supabase response)
  factory SessionDto.fromMap(Map<String, dynamic> map) {
    return SessionDto(
      id: map['id'] as String,
      name: map['name'] as String,
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
      'name': name,
      // created_at and updated_at are set by database defaults
    };
  }

  /// Convert to domain entity
  Session toEntity() {
    return Session(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create from domain entity
  factory SessionDto.fromEntity(Session entity) {
    return SessionDto(
      id: entity.id,
      name: entity.name,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
