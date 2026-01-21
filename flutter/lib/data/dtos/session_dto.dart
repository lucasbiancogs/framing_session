import 'package:whiteboard/domain/entities/session.dart';

class SessionDto {
  const SessionDto({required this.id, required this.name});

  final String id;
  final String name;

  /// Create from database map (Supabase response)
  factory SessionDto.fromJson(Map<String, dynamic> json) =>
      SessionDto(id: json['id'] as String, name: json['name'] as String);

  /// Convert to database map (for INSERT/UPDATE)
  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  /// Convert to domain entity
  Session toEntity() => Session(id: id, name: name);

  /// Create from domain entity
  factory SessionDto.fromEntity(Session entity) =>
      SessionDto(id: entity.id, name: entity.name);
}
