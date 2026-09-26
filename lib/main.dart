import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Telas internas
import 'home_screen.dart';
import 'history_screen.dart';
import 'capture_screen.dart';
import 'about_screen.dart';
import 'meus_relatorios_screen.dart';
import 'feedback_screen.dart';
import 'adjust_smile_screen.dart';
import 'compare_screen.dart';
import 'analysis_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('simulacoes');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dental Smile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        // 1. Tela Inicial
        '/': (context) => const HomeScreen(),

        // 2. Histórico
        '/history': (context) => HistoryScreen(),

        // 3. Captura de Foto
        '/capture': (context) => const CaptureScreen(),

        // 4. Sobre o Tratamento
        '/about': (context) => const AboutScreen(),

        // 5. Meus Relatórios
        '/relatorios': (context) => MeusRelatoriosScreen(),

        // 6. Análise com IA
        '/analysis': (context) => AnalysisScreen(),

        // 7. Ajustes de Sorriso
        '/adjust': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return AdjustSmileScreen(image: File(args['image']));
        },

        // 8. Comparar Antes/Depois
        '/compare': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CompareScreen(
            originalImage: args['originalImage'],
            adjustedImage: args['adjustedImage'],
            existingItem: args['existingItem'],
          );
        },
      },
      onGenerateRoute: (settings) {
        // 9. Feedback do Dentista
        if (settings.name == '/feedback') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => FeedbackScreen(existingItem: args ?? {}),
          );
        }
        return null;
      },
    );
  }
}
