import 'base_faults.dart';

/// Exception types for session operations.
class SessionException extends BaseException {
  const SessionException._(super.message);

  factory SessionException.notFound(String id) =>
      SessionException._('Session not found: $id');

  factory SessionException.createFailed(String reason) =>
      SessionException._('Failed to create session: $reason');

  factory SessionException.loadFailed(String reason) =>
      SessionException._('Failed to load sessions: $reason');

  factory SessionException.deleteFailed(String reason) =>
      SessionException._('Failed to delete session: $reason');

  factory SessionException.unknown(String reason) =>
      SessionException._('Unknown error: $reason');
}
