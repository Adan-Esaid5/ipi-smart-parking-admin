import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xhnmweojfldoexshwqgm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhobm13ZW9qZmxkb2V4c2h3cWdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyODg1OTQsImV4cCI6MjA4OTg2NDU5NH0.ngr1k2A2dk8CXAIp3F8NAfK4fXVYMzio7EZG79ua2-Y',
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Parking Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF188038),
        ),
      ),
      home: const AdminDashboardScreen(),
    );
  }
}