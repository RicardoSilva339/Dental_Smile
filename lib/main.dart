import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Telas ativas mantidas na arquitetura
import 'home_screen.dart';
import 'history_screen.dart';
import 'capture_screen.dart';
import 'analysis_screen.dart';
import 'treatment_about_screen.dart';
import 'adjust_smile_screen.dart';
import 'compare_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Hive para armazenamento local do histórico
  await Hive.initFlutter();

  // Abre a box 'simulacoes' antes de iniciar o aplicativo
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

        // 2. Histórico de Simulações
        '/history': (context) => const HistoryScreen(),

        // 3. Captura de Foto
        '/capture': (context) => const CaptureScreen(),

        // 4. Análise com IA
        '/analysis': (context) => const AnalysisScreen(),

        // 5. Sobre o Tratamento (Notas Clínicas do Dentista)
        '/about': (context) => const TreatmentAboutScreen(),

        // 6. Ajuste Fino do Sorriso
        '/adjust': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

          dynamic imageArg = args?['image'];
          File imageFile;
          if (imageArg is File) {
            imageFile = imageArg;
          } else if (imageArg is String) {
            imageFile = File(imageArg);
          } else {
            imageFile = File('');
          }

          return AdjustSmileScreen(
            image: imageFile,
            region: args?['region'] as Map<String, dynamic>?,
          );
        },

        // 7. Comparar Antes/Depois e Gerar Relatório PDF
        '/compare': (context) => const CompareScreen(),
      },
    );
  }
}