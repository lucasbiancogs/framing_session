import 'package:flutter/material.dart';
import 'package:whiteboard/domain/entities/cursor.dart';
import 'package:whiteboard/domain/entities/user.dart';
import 'package:whiteboard/presentation/helpers/color_helper.dart'
    as color_helper;

/// Widget that displays a remote user's cursor on the canvas.
///
/// Shows:
/// - A cursor icon in the user's color
/// - The user's name below the cursor
class UserCursor extends StatelessWidget {
  const UserCursor({
    super.key,
    required this.cursor,
    required this.user,
    required this.panOffset,
    required this.zoom,
  });

  final Cursor cursor;
  final User user;
  final Offset panOffset;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    // Convert canvas coordinates to screen coordinates
    final screenX = cursor.x * zoom + panOffset.dx;
    final screenY = cursor.y * zoom + panOffset.dy;

    final userColor = color_helper.getColorFromHex(user.color);

    return Positioned(
      left: screenX,
      top: screenY,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cursor icon
            Icon(Icons.navigation, color: userColor, size: 20),
            // User name label
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: userColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
