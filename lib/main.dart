import 'package:flutter/material.dart';

import 'screens/pin_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meradla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const PinScreen(),
    );
  }
}
