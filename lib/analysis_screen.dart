import 'dart:io';
import 'package:flutter/material.dart';
import 'background.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final imagePath = args?['image'] as String?;

    if (imagePath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Análise com IA')),
        body: const Center(
          child: Text(
            'Nenhuma análise disponível',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    final imageFile = File(imagePath);
    final bool hasSmile = _detectSmile(imageFile); // simulação da IA

    // Se detectar sorriso, navega automaticamente para ajuste
    if (hasSmile) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(
          context,
          '/adjust',
          arguments: {'image': imageFile.path},
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Análise com IA')),
      body: Background(
        imagePath: 'assets/images/antes_depois.jpg',
        opacity: 0.25,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                'Resultado da Análise',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              Image.file(imageFile, height: 300, fit: BoxFit.cover),
              const SizedBox(height: 30),

              if (!hasSmile) ...[
                const Text(
                  'Não foi detectado sorriso na foto.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'Favor bater nova foto – sorriso não detectado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/capture');
                  },
                ),
              ] else ...[
                const Text(
                  'Sorriso detectado com sucesso!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Função simulada para detectar sorriso
  bool _detectSmile(File image) {
    // Aqui você integraria a IA real.
    // Por enquanto, vamos simular sempre "true".
    return true;
  }
}
