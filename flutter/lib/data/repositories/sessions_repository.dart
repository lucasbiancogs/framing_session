import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide Session, User;
import 'package:uuid/uuid.dart';
import 'package:whiteboard/data/dtos/session_dto.dart';
import 'package:whiteboard/data/dtos/user_dto.dart';
import 'package:whiteboard/domain/entities/session.dart';
import 'package:whiteboard/domain/entities/user.dart';

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
  Future<Session> createSession(String name);

  /// Updates an existing session in the database.
  Future<Session> updateSession(Session session);

  /// Deletes a session from the database.
  Future<void> deleteSession(String id);

  /// Joins a session and returns a stream of online users.
  Future<Stream<List<User>>> joinSession(String sessionId, User user);
}

class _SessionKeys {
  static const String repo = 'sessions';
  static const String id = 'id';
  // ignore: unused_field
  static const String name = 'name';
  // ignore: unused_field
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static String presenceChannel(String sessionId) => 'session:$sessionId';
}

class SessionsRepositoryImpl implements SessionsRepository {
  SessionsRepositoryImpl(this._client);

  final SupabaseClient _client;

  StreamController<List<User>>? _presenceController;
  RealtimeChannel? _presenceChannel;

  @override
  Future<List<Session>> getAllSessions() async {
    final response = await _client
        .from(_SessionKeys.repo)
        .select()
        .order(_SessionKeys.updatedAt, ascending: false);

    return (response as List)
        .map(
          (data) =>
              SessionDto.fromJson(data as Map<String, dynamic>).toEntity(),
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

    return SessionDto.fromJson(response).toEntity();
  }

  @override
  Future<Session> createSession(String name) async {
    final session = Session(id: const Uuid().v4(), name: name);

    final response = await _client
        .from(_SessionKeys.repo)
        .insert(SessionDto.fromEntity(session).toJson())
        .select()
        .single();

    return SessionDto.fromJson(response).toEntity();
  }

  @override
  Future<Session> updateSession(Session session) async {
    final response = await _client
        .from(_SessionKeys.repo)
        .update(SessionDto.fromEntity(session).toJson())
        .eq(_SessionKeys.id, session.id)
        .select()
        .single();

    return SessionDto.fromJson(response).toEntity();
  }

  @override
  Future<void> deleteSession(String id) async {
    await _client.from(_SessionKeys.repo).delete().eq(_SessionKeys.id, id);
  }

  @override
  Future<Stream<List<User>>> joinSession(String sessionId, User user) async {
    _presenceController ??= StreamController<List<User>>.broadcast();
    _presenceChannel = _client.channel(_SessionKeys.presenceChannel(sessionId));

    final userPayload = UserDto.fromEntity(user).toJson();

    _presenceChannel!
        .onPresenceSync((payload) {
          final state = _presenceChannel!.presenceState();

          final users = state
              .expand((presence) => presence.presences)
              .map((presence) => UserDto.fromJson(presence.payload).toEntity())
              .toList();

          _presenceController?.add(users);
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel?.track(userPayload);
          }
        });

    _presenceController!.onCancel = () {
      _presenceChannel?.unsubscribe();
      _presenceChannel = null;
      _presenceController?.close();
      _presenceController = null;
    };

    return _presenceController!.stream;
  }
}
