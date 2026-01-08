import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Represents a cursor position broadcast by a user.
///
/// This is ephemeral data (no persistence) used for Broadcast messages.
/// Cursor positions are sent frequently (30-60 times per second) and
/// missing messages are acceptable.
@immutable
class Cursor extends Equatable {
  const Cursor({required this.userId, required this.x, required this.y});

  /// The ID of the user whose cursor this is.
  final String userId;

  /// X coordinate of the cursor.
  final double x;

  /// Y coordinate of the cursor.
  final double y;

  @override
  List<Object?> get props => [userId, x, y];
}
