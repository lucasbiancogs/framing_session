import 'package:dartz/dartz.dart';
import 'package:whiteboard/core/errors/base_faults.dart';
import 'package:whiteboard/core/errors/canvas_exception.dart';
import 'package:whiteboard/data/repositories/canvas_repository.dart';
import 'package:whiteboard/domain/entities/cursor.dart';

abstract class CanvasServices {
  Future<Either<BaseException, void>> broadcastCursor(
    String sessionId,
    Cursor cursor,
  );
  Future<Either<BaseException, Stream<Cursor>>> listenToCursors(
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
}
