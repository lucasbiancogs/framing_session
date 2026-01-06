import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/supabase_config.dart';
import 'domain/services/session_services.dart';
import 'domain/services/shape_services.dart';
import 'presentation/pages/sessions/sessions_page.dart';
import 'presentation/view_models/global_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(
    // Wrap with ProviderScope and override with mock implementations
    ProviderScope(
      overrides: [
        // Phase 4: Use mock services (no Supabase yet)
        shapeServices.overrideWithValue(MockShapeServices()),
        sessionServices.overrideWithValue(MockSessionServices()),
      ],
      child: const WhiteboardApp(),
    ),
  );
}

class WhiteboardApp extends StatelessWidget {
  const WhiteboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF1E1E1E),
          surfaceContainerLowest: Colors.black,
          primary: const Color(0xFF4ED09A),
          brightness: Brightness.dark,
          inversePrimary: const Color(0xFF4ED09A),
          inverseSurface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const SessionsPage(),
    );
  }
}
