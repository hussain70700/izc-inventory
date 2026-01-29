// ============================================
// MAIN.DART - Application Entry Point
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:izc_inventory/dashboard/Dashboard_Shell.dart';

import 'package:izc_inventory/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SUPABASE_URL="https://lbhvhvpzllaudyilldwp.supabase.co";
  final SUPABASE_ANON_KEY="sb_publishable_6TDVjvEK2-CArpIGPndVEg_wz73GZIN";



  // Initialize Hive for session management (MUST be before Supabase)
  await SessionService.init();

  // Initialize Supabase
  await Supabase.initialize(
    url: SUPABASE_URL ?? '',
    anonKey: SUPABASE_ANON_KEY?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
      title: 'Inventory Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffFE691E),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      // Check if user is logged in and navigate accordingly
      home: SessionService.isLoggedIn()
          ? const DashboardShell()
          : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardShell(),
      },
    );
  }
}