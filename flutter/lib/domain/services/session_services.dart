import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/base_exception.dart';
import '../../core/errors/session_exception.dart';
import '../entities/session.dart';

/// Service interface for session business logic.
///
/// This abstraction allows swapping implementations:
/// - MockSessionServices (this phase) — local mock data
/// - SessionServicesImpl (later phases) — backed by Supabase
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
// Mock Implementation (Phase 4 only)
// =============================================================================
// This implementation uses in-memory data for UI development.
// In Phase 5+, this will be replaced with SupabaseSessionServices.

class MockSessionServices implements SessionServices {
  MockSessionServices() {
    // Seed with example sessions
    _sessions.addAll(_seedSessions);
  }

  final List<Session> _sessions = [];

  // Example sessions for the mock data
  static final List<Session> _seedSessions = [
    Session(
      id: 'session-1',
      name: 'Team Brainstorm',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Session(
      id: 'session-2',
      name: 'Product Roadmap',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Session(
      id: 'session-3',
      name: 'Sprint Planning',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  @override
  Future<Either<BaseException, List<Session>>> getAllSessions() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Return sessions sorted by updatedAt (most recent first)
    final sortedSessions = List<Session>.from(_sessions)
      ..sort(
        (a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
      );

    return right(sortedSessions);
  }

  @override
  Future<Either<BaseException, Session>> getSessionById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final session = _sessions.firstWhere((s) => s.id == id);
      return right(session);
    } catch (_) {
      return left(SessionException.notFound(id));
    }
  }

  @override
  Future<Either<BaseException, Session>> createSession({
    required String name,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final now = DateTime.now();
    final newSession = Session(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );

    _sessions.add(newSession);
    return right(newSession);
  }

  @override
  Future<Either<BaseException, void>> deleteSession(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final index = _sessions.indexWhere((s) => s.id == id);
    if (index == -1) {
      return left(SessionException.notFound(id));
    }

    _sessions.removeAt(index);
    return right(null);
  }
}
