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
      // DÔLEŽITÁ ZMENA: Použitie builder na obalenie celej aplikácie
      builder: (context, child) {
        return SafeArea(
          top: false, // Horná lišta (stavová) môže ostať prekrytá, ak chcete
          bottom: true, // TOTO JE KĽÚČOVÉ: pridá odsadenie od spodnej lišty
          child: child ?? Container(),
        );
      },
      home: const PinScreen(),
    );
  }
}
