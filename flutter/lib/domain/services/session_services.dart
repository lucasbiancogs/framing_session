import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/data/dtos/session_dto.dart';
import 'package:whiteboard/data/repositories/sessions_repository.dart';

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
}

// =============================================================================
// Supabase Implementation (Phase 5)
// =============================================================================

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
      final dto = SessionDto(
        id: const Uuid().v4(),
        name: name,
        createdAt: null, // Set by database
        updatedAt: null, // Set by database
      );

      final session = await _repository.createSession(dto);
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
}
