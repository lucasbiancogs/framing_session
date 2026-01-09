import 'package:dartz/dartz.dart';
import 'package:whiteboard/core/errors/base_faults.dart';
import 'package:whiteboard/core/errors/canvas_exception.dart';
import 'package:whiteboard/data/repositories/canvas_repository.dart';
import 'package:whiteboard/domain/entities/cursor.dart';
import 'package:whiteboard/domain/entities/operation.dart';

/// Service interface for canvas operations
abstract class CanvasServices {
  /// Broadcast a cursor position to all clients in the session
  Future<Either<BaseException, void>> broadcastCursor(
    String sessionId,
    Cursor cursor,
  );

  /// Listen to cursor positions for a session
  Future<Either<BaseException, Stream<Cursor>>> listenToCursors(
    String sessionId,
  );

  /// Broadcast an operation to all clients in the session
  Future<Either<BaseException, void>> broadcastOperation(
    String sessionId,
    Operation operation,
  );

  /// Listen to operations for a session
  Future<Either<BaseException, Stream<Operation>>> listenToOperations(
    String sessionId,
  );
}

class CanvasServicesImpl implements CanvasServices {
  CanvasServicesImpl(this._repository);

  final CanvasRepository _repository;

  @override
  Future<Either<BaseException, void>> broadcastCursor(
    String sessionId,
    Cursor cursor,
  ) async {
    try {
      await _repository.broadcastCursor(sessionId, cursor);
      return right(null);
    } catch (e) {
      return left(CanvasException.broadcastFailed(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Stream<Cursor>>> listenToCursors(
    String sessionId,
  ) async {
    try {
      final stream = await _repository.listenToCursors(sessionId);
      return right(stream);
    } catch (e) {
      return left(CanvasException.subscribeFailed(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, void>> broadcastOperation(
    String sessionId,
    Operation operation,
  ) async {
    try {
      await _repository.broadcastOperation(sessionId, operation);
      return right(null);
    } catch (e) {
      return left(CanvasException.broadcastFailed(e.toString()));
    }
  }

  @override
  Future<Either<BaseException, Stream<Operation>>> listenToOperations(
    String sessionId,
  ) async {
    try {
      final stream = await _repository.listenToOperations(sessionId);
      return right(stream);
    } catch (e) {
      return left(CanvasException.subscribeFailed(e.toString()));
    }
  }
}
