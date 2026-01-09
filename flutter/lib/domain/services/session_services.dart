import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:whiteboard/data/repositories/sessions_repository.dart';
import 'package:whiteboard/domain/entities/user.dart';

import '../../core/errors/base_faults.dart';
import '../../core/errors/session_exception.dart';
import '../entities/session.dart';

/// Service interface for session business logic.
///
/// This abstraction allows swapping implementations:
/// - MockSessionServices — local mock data (for testing)
/// - SessionServicesImpl — backed by Supabase
abstract class SessionServices {
  /// Get all sessions.
  Future<Either<BaseException, List<Session>>> getAllSessions();

  /// Get a single session by ID.
  Future<Either<BaseException, Session>> getSessionById(String id);

  /// Create a new session.
  Future<Either<BaseException, Session>> createSession({required String name});

  /// Delete a session by ID.
  Future<Either<BaseException, void>> deleteSession(String id);

  /// Join a session by ID.
  ///
  /// Returns a stream of online users in the session.
  Future<Either<BaseException, Stream<List<User>>>> joinSession(
    String id,
    String userId,
  );
}

class SessionServicesImpl implements SessionServices {
  SessionServicesImpl(this._repository);

  final SessionsRepository _repository;

  @override
  Future<Either<BaseException, List<Session>>> getAllSessions() async {
    try {
      final sessions = await _repository.getAllSessions();
      return right(sessions);
    } catch (e) {
      return left(SessionException.loadFailed(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Session>> getSessionById(String id) async {
    try {
      final session = await _repository.getSession(id);
      return right(session);
    } catch (e) {
      if (e.toString().contains('No rows found')) {
        return left(SessionException.notFound(id));
      }
      return left(SessionException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Session>> createSession({
    required String name,
  }) async {
    try {
      final session = await _repository.createSession(name);
      return right(session);
    } catch (e) {
      return left(SessionException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, void>> deleteSession(String id) async {
    try {
      await _repository.deleteSession(id);
      return right(null);
    } catch (e) {
      return left(SessionException.unknown(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Stream<List<User>>>> joinSession(
    String id,
    String userId,
  ) async {
    try {
      final names = [
        'John Doe',
        'Rafa Letsche',
        'Jim Beam',
        'Paul Solomonson',
        'George Washington',
        'Thomas Jefferson',
        'Abraham Lincoln',
        'Theodore Roosevelt',
        'Woodrow Wilson',
        'Franklin D. Roosevelt',
        'Harry S. Truman',
        'Dwight D. Eisenhower',
        'John F. Kennedy',
        'Lyndon B. Johnson',
        'Richard Nixon',
        'Gerald Ford',
        'Jimmy Carter',
        'Ronald Reagan',
        'George H. W. Bush',
        'Bill Clinton',
        'George W. Bush',
        'Barack Obama',
        'Donald Trump',
        'Joe Biden',
      ];

      final randomName = names[Random().nextInt(names.length)];
      final randomColor =
          '#${Random().nextInt(16777215).toRadixString(16).padLeft(6, '0')}';

      final user = User(id: userId, name: randomName, color: randomColor);

      final stream = await _repository.joinSession(id, user);

      return right(stream);
    } catch (e) {
      return left(SessionException.unknown(e.toString()));
    }
  }
}
