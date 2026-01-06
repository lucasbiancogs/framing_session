import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/base_exception.dart';
import '../../../domain/entities/session.dart';
import '../../../domain/services/session_services.dart';
import '../../view_models/global_providers.dart';

@immutable
sealed class SessionsState extends Equatable {
  const SessionsState();

  @override
  List<Object?> get props => [];
}

class SessionsLoading extends SessionsState {
  const SessionsLoading();
}

class SessionsLoaded extends SessionsState {
  const SessionsLoaded({required this.sessions, this.isCreating = false});

  /// All sessions.
  final List<Session> sessions;

  /// Whether a new session is being created.
  final bool isCreating;

  @override
  List<Object?> get props => [sessions, isCreating];

  SessionsLoaded copyWith({List<Session>? sessions, bool? isCreating}) {
    return SessionsLoaded(
      sessions: sessions ?? this.sessions,
      isCreating: isCreating ?? this.isCreating,
    );
  }
}

class SessionsError extends SessionsState {
  const SessionsError(this.exception);

  final BaseException exception;

  @override
  List<Object?> get props => [exception];
}

final sessionsVM = StateNotifierProvider.autoDispose<SessionsVM, SessionsState>(
  (ref) => SessionsVM(ref.watch(sessionServices)),
  name: 'sessionsVM',
  dependencies: [sessionServices],
);

class SessionsVM extends StateNotifier<SessionsState> {
  SessionsVM(this._sessionServices) : super(const SessionsLoading()) {
    _loadSessions();
  }

  final SessionServices _sessionServices;

  SessionsLoaded get _loadedState => state as SessionsLoaded;

  Future<void> _loadSessions() async {
    final result = await _sessionServices.getAllSessions();

    result.fold(
      (exception) => state = SessionsError(exception),
      (sessions) => state = SessionsLoaded(sessions: sessions),
    );
  }

  Future<void> retryLoading() async {
    state = const SessionsLoading();
    await _loadSessions();
  }

  /// Create a new session with the given name.
  /// Returns the created session ID on success.
  Future<String?> createSession(String name) async {
    if (state is! SessionsLoaded) return null;

    state = _loadedState.copyWith(isCreating: true);

    final result = await _sessionServices.createSession(name: name);

    String? sessionId;
    result.fold(
      (exception) {
        // Reset creating state on error
        state = _loadedState.copyWith(isCreating: false);
      },
      (session) {
        sessionId = session.id;
        state = _loadedState.copyWith(
          sessions: [session, ..._loadedState.sessions],
          isCreating: false,
        );
      },
    );

    return sessionId;
  }

  Future<void> deleteSession(String sessionId) async {
    if (state is! SessionsLoaded) return;

    final result = await _sessionServices.deleteSession(sessionId);

    result.fold(
      (exception) {
        // TODO(lucasbiancogs): Show error notification here
      },
      (_) {
        state = _loadedState.copyWith(
          sessions: _loadedState.sessions
              .where((s) => s.id != sessionId)
              .toList(),
        );
      },
    );
  }
}
