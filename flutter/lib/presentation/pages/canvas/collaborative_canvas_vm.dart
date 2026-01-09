import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whiteboard/core/either_extension.dart';
import 'package:whiteboard/core/errors/base_faults.dart';
import 'package:whiteboard/domain/entities/cursor.dart';
import 'package:whiteboard/domain/entities/operation.dart';
import 'package:whiteboard/domain/entities/user.dart';
import 'package:whiteboard/domain/services/canvas_services.dart';
import 'package:whiteboard/domain/services/session_services.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_cursor.dart';
import 'package:whiteboard/presentation/pages/canvas/models/canvas_operation.dart';
import 'package:whiteboard/presentation/view_models/global_providers.dart';

final collaborativeCanvasVM =
    StateNotifierProvider.autoDispose<
      CollaborativeCanvasVM,
      CollaborativeCanvasState
    >(
      (ref) => CollaborativeCanvasVM(
        ref.watch(sessionServices),
        ref.watch(canvasServices),
        ref.watch(sessionIdProvider),
      ),
      name: 'collaborativeCanvasVM',
      dependencies: [sessionServices, canvasServices, sessionIdProvider],
    );

class CollaborativeCanvasVM extends StateNotifier<CollaborativeCanvasState> {
  CollaborativeCanvasVM(
    this._sessionServices,
    this._canvasServices,
    this._sessionId,
  ) : super(const CollaborativeCanvasLoading()) {
    _init();
  }

  final SessionServices _sessionServices;
  final CanvasServices _canvasServices;
  final String _sessionId;
  StreamSubscription<List<User>>? _presence;
  StreamSubscription<Cursor>? _cursors;
  StreamSubscription<Operation>? _operations;

  Future<void> _init() async {
    final userId = Uuid().v4();

    final results = await Future.wait([
      _sessionServices.joinSession(_sessionId, userId),
      _canvasServices.listenToCursors(_sessionId),
      _canvasServices.listenToOperations(_sessionId),
    ]);

    if (results.any((result) => result.isLeft())) {
      state = CollaborativeCanvasError(
        results.firstWhere((result) => result.isLeft()).forceLeft(),
      );
      return;
    }

    state = CollaborativeCanvasLoaded(
      userId: userId,
      onlineUsers: [],
      cursors: [],
      operation: null,
    );

    final onlineUsersStream = results[0].forceRight() as Stream<List<User>>;
    final cursorsStream = results[1].forceRight() as Stream<Cursor>;
    final operationsStream = results[2].forceRight() as Stream<Operation>;

    _presence = onlineUsersStream.listen((users) {
      if (!mounted) return;

      final currentState = _loadedState;

      // Remove cursors for users who are no longer online
      final onlineUserIds = users.map((u) => u.id).toSet();
      final filteredCursors = currentState.cursors
          .where((cursor) => onlineUserIds.contains(cursor.userId))
          .toList();

      state = currentState.copyWith(
        onlineUsers: users,
        cursors: filteredCursors,
      );
    });

    _cursors = cursorsStream.listen((cursor) {
      if (!mounted) return;

      final currentState = _loadedState;

      // Check if the user is online
      final isUserOnline = currentState.onlineUsers.any(
        (user) => user.id == cursor.userId,
      );

      // If user is not online, ignore the cursor
      if (!isUserOnline) {
        return;
      }

      final user = currentState.onlineUsers.firstWhere(
        (user) => user.id == cursor.userId,
        orElse: () => throw Exception('User not found'),
      );

      // Find if cursor already exists for this user
      final existingCursorIndex = currentState.cursors.indexWhere(
        (c) => c.userId == cursor.userId,
      );

      final updatedCursors = List<CanvasCursor>.from(currentState.cursors);

      if (existingCursorIndex >= 0) {
        // Update existing cursor
        updatedCursors[existingCursorIndex] = CanvasCursor.fromCursor(
          cursor,
          user,
        );
      } else {
        // Add new cursor
        updatedCursors.add(CanvasCursor.fromCursor(cursor, user));
      }

      state = currentState.copyWith(cursors: updatedCursors);
    });

    _operations = operationsStream.listen((operation) {
      if (!mounted) return;

      final currentState = _loadedState;

      final canvasOperation = CanvasOperation.fromEntity(operation);

      state = currentState.copyWith(operation: canvasOperation);
    });
  }

  void broadcastCursor(Offset position) {
    if (state is! CollaborativeCanvasLoaded) return;

    final cursor = Cursor(
      userId: _loadedState.userId,
      x: position.dx,
      y: position.dy,
    );

    _canvasServices.broadcastCursor(_sessionId, cursor);
  }

  void broadcastOperation(CanvasOperation operation) {
    if (state is! CollaborativeCanvasLoaded) return;

    _canvasServices.broadcastOperation(_sessionId, operation.toEntity());
  }

  CollaborativeCanvasLoaded get _loadedState =>
      state as CollaborativeCanvasLoaded;

  @override
  void dispose() {
    _presence?.cancel();
    _cursors?.cancel();
    _operations?.cancel();
    super.dispose();
  }
}

@immutable
sealed class CollaborativeCanvasState extends Equatable {
  const CollaborativeCanvasState();

  @override
  List<Object?> get props => [];
}

class CollaborativeCanvasLoading extends CollaborativeCanvasState {
  const CollaborativeCanvasLoading();
}

class CollaborativeCanvasLoaded extends CollaborativeCanvasState {
  const CollaborativeCanvasLoaded({
    required this.userId,
    required this.onlineUsers,
    required this.cursors,
    required this.operation,
  });

  final String userId;
  final List<User> onlineUsers;
  final List<CanvasCursor> cursors;
  final CanvasOperation? operation;

  CollaborativeCanvasLoaded copyWith({
    List<User>? onlineUsers,
    List<CanvasCursor>? cursors,
    CanvasOperation? operation,
  }) {
    return CollaborativeCanvasLoaded(
      userId: userId,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      cursors: cursors ?? this.cursors,
      operation: operation ?? this.operation,
    );
  }

  @override
  List<Object?> get props => [userId, onlineUsers, cursors, operation];
}

class CollaborativeCanvasError extends CollaborativeCanvasState {
  const CollaborativeCanvasError(this.exception);

  final BaseException exception;

  @override
  List<Object?> get props => [exception];
}
