import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:whiteboard/data/dtos/session_dto.dart';
import 'package:whiteboard/domain/entities/session.dart';

/// Session repository for managing whiteboard session CRUD operations with Supabase.
///
/// - Defines [SessionsRepository] interface and [SessionsRepositoryImpl] implementation.
/// - Uses [SessionDto] for data mapping and [Session] as domain entity.
/// - Supports fetching, creating, updating, and deleting sessions.
///
/// Usage:
/// ```dart
/// final repo = SessionsRepositoryImpl(Supabase.instance.client);
/// final sessions = await repo.getAllSessions();
/// ```
abstract class SessionsRepository {
  /// Fetches all sessions from the database.
  Future<List<Session>> getAllSessions();

  /// Fetches a session by its ID.
  Future<Session> getSession(String id);

  /// Creates a new session in the database.
  Future<Session> createSession(SessionDto session);

  /// Updates an existing session in the database.
  Future<Session> updateSession(SessionDto session);

  /// Deletes a session from the database.
  Future<void> deleteSession(String id);
}

class _SessionKeys {
  static const String repo = 'sessions';
  static const String id = 'id';
  // ignore: unused_field
  static const String name = 'name';
  // ignore: unused_field
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class SessionsRepositoryImpl implements SessionsRepository {
  SessionsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Session>> getAllSessions() async {
    final response = await _client
        .from(_SessionKeys.repo)
        .select()
        .order(_SessionKeys.updatedAt, ascending: false);

    return (response as List)
        .map(
          (data) => SessionDto.fromMap(data as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Session> getSession(String id) async {
    final response = await _client
        .from(_SessionKeys.repo)
        .select()
        .eq(_SessionKeys.id, id)
        .single();

    return SessionDto.fromMap(response).toEntity();
  }

  @override
  Future<Session> createSession(SessionDto session) async {
    final response = await _client
        .from(_SessionKeys.repo)
        .insert(session.toMap())
        .select()
        .single();

    return SessionDto.fromMap(response).toEntity();
  }

  @override
  Future<Session> updateSession(SessionDto session) async {
    final response = await _client
        .from(_SessionKeys.repo)
        .update(session.toMap())
        .eq(_SessionKeys.id, session.id)
        .select()
        .single();

    return SessionDto.fromMap(response).toEntity();
  }

  @override
  Future<void> deleteSession(String id) async {
    await _client.from(_SessionKeys.repo).delete().eq(_SessionKeys.id, id);
  }
}
