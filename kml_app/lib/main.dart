import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/kml_provider.dart';
import 'views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => KmlProvider()..carregarDados(),
      child: const KmlApp(),
    ),
  );
}

class KmlApp extends StatelessWidget {
  const KmlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KML - Quilômetros e Lucratividade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
      ),
      home: const HomeScreen(), 
    );
  }
}