import 'package:flutter/material.dart';

import 'services/database_helper.dart';
import 'view/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;

  runApp(const AfinApp());
}

class AfinApp extends StatelessWidget {
  const AfinApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8A5A44);

    return MaterialApp(
      title: 'AFIN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: seed,
          secondary: const Color(0xFFD9A441),
          surface: const Color(0xFFF5EFE6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F1E8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF5D4037),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const LoginPage(),
    );
  }
}
