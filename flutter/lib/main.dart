import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whiteboard/data/repositories/canvas_repository.dart';
import 'package:whiteboard/data/repositories/sessions_repository.dart';
import 'package:whiteboard/data/repositories/shapes_repository.dart';

import 'core/config/supabase_config.dart';
import 'domain/services/canvas_services.dart';
import 'domain/services/session_services.dart';
import 'domain/services/shape_services.dart';
import 'presentation/pages/sessions/sessions_page.dart';
import 'presentation/view_models/global_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final supabaseClient = Supabase.instance.client;

  //
  // Repositories
  //
  final sessionsRepository = SessionsRepositoryImpl(supabaseClient);
  final shapesRepository = ShapesRepositoryImpl(supabaseClient);
  final canvasRepository = CanvasRepositoryImpl(supabaseClient);

  //
  // Services
  //
  final sessionServicesImpl = SessionServicesImpl(sessionsRepository);
  final shapeServicesImpl = ShapeServicesImpl(shapesRepository);
  final canvasServicesImpl = CanvasServicesImpl(canvasRepository);

  runApp(
    ProviderScope(
      overrides: [
        sessionServices.overrideWithValue(sessionServicesImpl),
        shapeServices.overrideWithValue(shapeServicesImpl),
        canvasServices.overrideWithValue(canvasServicesImpl),
      ],
      child: const WhiteboardApp(),
    ),
  );
}

class WhiteboardApp extends StatelessWidget {
  const WhiteboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Whiteboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.lightZinc(),
        radius: 0.5,
      ),
      darkTheme: ThemeData(
        colorScheme: LegacyColorSchemes.darkZinc(),
        radius: 0.5,
      ),
      home: const SessionsPage(),
    );
  }
}
