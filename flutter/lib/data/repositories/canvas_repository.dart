import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whiteboard/data/dtos/cursor_dto.dart';
import 'package:whiteboard/domain/entities/cursor.dart';

abstract class CanvasRepository {
  Future<void> broadcastCursor(String sessionId, Cursor cursor);
  Future<Stream<Cursor>> listenToCursors(String sessionId);
}

class _CanvasKeys {
  static const String cursorEvent = 'cursor_position';
  static String broadcastChannel(String sessionId) => 'canvas:$sessionId';
}

class CanvasRepositoryImpl implements CanvasRepository {
  CanvasRepositoryImpl(this._client);

  final SupabaseClient _client;

  StreamController<Cursor>? _broadcastController;
  RealtimeChannel? _broadcastChannel;

  @override
  Future<Stream<Cursor>> listenToCursors(String sessionId) async {
    _broadcastController ??= StreamController<Cursor>.broadcast();
    _broadcastChannel = _client.channel(
      _CanvasKeys.broadcastChannel(sessionId),
    );

    _broadcastChannel!
        .onBroadcast(
          event: _CanvasKeys.cursorEvent,
          callback: (payload) {
            _broadcastController?.add(CursorDto.fromJson(payload).toEntity());
          },
        )
        .subscribe();

    _broadcastController!.onCancel = () {
      _broadcastController?.close();
      _broadcastController = null;
    };

    return _broadcastController!.stream;
  }

  @override
  Future<void> broadcastCursor(String sessionId, Cursor cursor) async {
    await _broadcastChannel!.sendBroadcastMessage(
      event: _CanvasKeys.cursorEvent,
      payload: CursorDto.fromEntity(cursor).toJson(),
    );
  }
}
