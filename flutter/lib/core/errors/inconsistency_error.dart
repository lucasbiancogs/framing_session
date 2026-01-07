import 'package:whiteboard/core/errors/base_faults.dart';

/// Lack of consistency through the developer's logic
class InconsistencyError extends BaseError {
  InconsistencyError._(super.message);

  factory InconsistencyError.internal(String message) =>
      InconsistencyError._(message);
  factory InconsistencyError.external(String message) =>
      InconsistencyError._(message);
}
