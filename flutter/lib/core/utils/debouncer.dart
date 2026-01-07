import 'dart:async';

import 'package:flutter/foundation.dart';

/// A simple debouncer that delays execution of an action.
///
/// Useful for operations that shouldn't fire on every event, like
/// persisting shape updates during drag operations.
///
/// Usage:
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 300));
/// debouncer.run(() => persistShape(shape));
/// ```
class Debouncer {
  Debouncer({required this.duration});

  /// The delay duration before the action is executed.
  final Duration duration;

  Timer? _timer;

  /// Run [action] after [duration] has passed without another call.
  ///
  /// If called again before the timer fires, the previous timer is cancelled
  /// and a new one starts.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancel any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether there's a pending action waiting to be executed.
  bool get isPending => _timer?.isActive ?? false;
}
