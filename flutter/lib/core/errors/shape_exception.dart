import 'package:whiteboard/core/errors/base_faults.dart';

/// Exception types for shape operations.
class ShapeException extends BaseException {
  const ShapeException._(super.message);

  factory ShapeException.notFound(String id) =>
      ShapeException._('Shape not found: $id');

  factory ShapeException.createFailed(String reason) =>
      ShapeException._('Failed to create shape: $reason');

  factory ShapeException.updateFailed(String reason) =>
      ShapeException._('Failed to update shape: $reason');

  factory ShapeException.deleteFailed(String reason) =>
      ShapeException._('Failed to delete shape: $reason');

  factory ShapeException.unknown(String reason) =>
      ShapeException._('Unknown error: $reason');
}
