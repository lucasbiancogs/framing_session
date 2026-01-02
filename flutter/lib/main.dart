import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteboard/app/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whiteboard',
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
        appBarTheme: AppBarTheme(backgroundColor: Colors.black),
        textTheme: GoogleFonts.robotoMonoTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Whiteboard')),
      body: const Center(child: Text('Supabase initialized ✓')),
    );
  }
}
