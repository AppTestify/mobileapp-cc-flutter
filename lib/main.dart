import 'package:flutter/material.dart';
import 'screens/school_code_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3498DB)),
        useMaterial3: true,
      ),
      home: const SchoolCodePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

