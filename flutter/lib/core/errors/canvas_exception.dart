import 'package:whiteboard/core/errors/base_faults.dart';

/// Exception types for canvas operations (including Broadcast).
class CanvasException extends BaseException {
  const CanvasException._(super.message);

  factory CanvasException.broadcastFailed(String reason) =>
      CanvasException._('Failed to broadcast: $reason');

  factory CanvasException.subscribeFailed(String reason) =>
      CanvasException._('Failed to subscribe: $reason');

  factory CanvasException.unknown(String reason) =>
      CanvasException._('Unknown error: $reason');
}
