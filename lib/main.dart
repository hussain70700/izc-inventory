import 'package:flutter/material.dart';
import 'package:izc_inventory/dashboard/dashboard_shell.dart'; // <-- CHANGE THIS

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IZC Inventory',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardShell(), // <-- AND CHANGE THIS
    );
  }
}
