import 'package:equatable/equatable.dart';
import 'package:whiteboard/domain/entities/cursor.dart';
import 'package:whiteboard/domain/entities/user.dart';

class CanvasCursor extends Equatable {
  const CanvasCursor({
    required this.userId,
    required this.userName,
    required this.userColor,
    required this.x,
    required this.y,
  });

  final String userId;
  final String userName;
  final String userColor;
  final double x;
  final double y;

  factory CanvasCursor.fromCursor(Cursor cursor, User user) {
    return CanvasCursor(
      userId: cursor.userId,
      userName: user.name,
      userColor: user.color,
      x: cursor.x,
      y: cursor.y,
    );
  }
  @override
  List<Object?> get props => [userId, userName, userColor, x, y];
}
