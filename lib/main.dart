import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // Inicializa o Hive para armazenamento local
  await Hive.initFlutter();

  // 📦 Abre as boxes necessárias para o funcionamento completo do app
  await Hive.openBox('simulacoes');  // Histórico de simulações com IA
  await Hive.openBox('box_usuario'); // Cadastro e dados do dentista
  await Hive.openBox('box_compras'); // Histórico de recargas de créditos

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
        '/': (context) => const InitialLoaderScreen(),

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

// 🛡️ Tela intermediária de carregamento com o Pop-up Profissional e Pisca-Pisca
class InitialLoaderScreen extends StatefulWidget {
  const InitialLoaderScreen({super.key});

  @override
  State<InitialLoaderScreen> createState() => _InitialLoaderScreenState();
}

class _InitialLoaderScreenState extends State<InitialLoaderScreen> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Configura a animação de piscar suave para o aviso
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_blinkController);

    // Acorda o servidor em background e gerencia a transição
    _iniciarConexao();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _iniciarConexao() async {
    // Exibe o pop-up profissional de conexão
    if (mounted) {
      _mostrarPopupConexao(context);
    }

    try {
      final url = Uri.parse('https://dentalsmile.ia.br/');

      // Dispara o ping e aguarda no máximo 10 segundos ou a resposta
      await http.get(url).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("⚠️ Ping inicial concluído/timeout: $e");
    }

    // Aguarda um pequeno delay estético e entra na HomeScreen
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _mostrarPopupConexao(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 45,
                    height: 45,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      strokeWidth: 3.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Estabelecendo conexão...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Sincronizando os dados do sistema.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _blinkAnimation,
                    child: const Text(
                      "Favor aguardar alguns instantes.",
                      style: TextStyle(
                        color: Color(0xFFFF5252), // Vermelho elegante
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tela de fundo neutra enquanto o pop-up está ativo
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
    );
  }
}