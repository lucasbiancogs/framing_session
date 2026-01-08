import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:whiteboard/presentation/pages/canvas/canvas_page.dart';

void navigateToCanvas(
  BuildContext context,
  String sessionId,
  String sessionName,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProviderScope(
        overrides: [
          sessionIdProvider.overrideWithValue(sessionId),
          sessionNameProvider.overrideWithValue(sessionName),
        ],
        child: const CanvasPage(),
      ),
    ),
  );
}
