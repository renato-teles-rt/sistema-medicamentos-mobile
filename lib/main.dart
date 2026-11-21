import 'package:flutter/material.dart';

import 'views/login_view.dart';

void main() {
  runApp(const CuidaMedApp());
}

class CuidaMedApp extends StatelessWidget {
  const CuidaMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CuidaMed 50+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F4C81)),
        useMaterial3: true,
      ),
      home: const LoginView(),
    );
  }
}
