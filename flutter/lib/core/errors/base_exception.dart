import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Base exception class for domain layer errors.
/// All domain exceptions should extend this class.
@immutable
abstract class BaseException extends Equatable implements Exception {
  const BaseException(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}
