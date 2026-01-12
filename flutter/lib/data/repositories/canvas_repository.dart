import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whiteboard/data/dtos/cursor_dto.dart';
import 'package:whiteboard/data/dtos/operation_dto.dart';
import 'package:whiteboard/domain/entities/cursor.dart';
import 'package:whiteboard/domain/entities/operation.dart';

abstract class CanvasRepository {
  Future<void> broadcastCursor(String sessionId, Cursor cursor);
  Future<Stream<Cursor>> listenToCursors(String sessionId);
  Future<void> broadcastOperation(String sessionId, Operation operation);
  Future<Stream<Operation>> listenToOperations(String sessionId);
}

class _CanvasKeys {
  static const String cursorEvent = 'cursor_position';
  static const String operationEvent = 'operation';
  static String broadcastChannel(String sessionId) => 'canvas:$sessionId';
}

class CanvasRepositoryImpl implements CanvasRepository {
  CanvasRepositoryImpl(this._client);

  final SupabaseClient _client;

  StreamController<Cursor>? _cursorController;
  StreamController<Operation>? _operationController;
  RealtimeChannel? _broadcastChannel;

  RealtimeChannel getBroadcastChannel(String sessionId) {
    if (_broadcastChannel != null) {
      return _broadcastChannel!;
    }

    _broadcastChannel ??= _client
        .channel(_CanvasKeys.broadcastChannel(sessionId))
        .subscribe();

    return _broadcastChannel!;
  }

  @override
  Future<Stream<Cursor>> listenToCursors(String sessionId) async {
    _cursorController ??= StreamController<Cursor>.broadcast();

    getBroadcastChannel(sessionId).onBroadcast(
      event: _CanvasKeys.cursorEvent,
      callback: (payload) {
        _cursorController?.add(CursorDto.fromJson(payload).toEntity());
      },
    );

    _cursorController!.onCancel = () {
      _cursorController?.close();
      _cursorController = null;
    };

    return _cursorController!.stream;
  }

  @override
  Future<void> broadcastCursor(String sessionId, Cursor cursor) async {
    await _broadcastChannel!.sendBroadcastMessage(
      event: _CanvasKeys.cursorEvent,
      payload: CursorDto.fromEntity(cursor).toJson(),
    );
  }

  @override
  Future<Stream<Operation>> listenToOperations(String sessionId) async {
    _operationController ??= StreamController<Operation>.broadcast();

    getBroadcastChannel(sessionId).onBroadcast(
      event: _CanvasKeys.operationEvent,
      callback: (payload) {
        _operationController?.add(OperationDto.fromJson(payload).toEntity());
      },
    );

    _operationController!.onCancel = () {
      _operationController?.close();
      _operationController = null;
    };

    return _operationController!.stream;
  }

  @override
  Future<void> broadcastOperation(String sessionId, Operation operation) async {
    await _broadcastChannel!.sendBroadcastMessage(
      event: _CanvasKeys.operationEvent,
      payload: OperationDto.fromEntity(operation).toJson(),
    );
  }
}
