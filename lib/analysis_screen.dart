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

    // Simulação da IA: detecta sorriso e retorna coordenadas
    final Map<String, dynamic>? detectionResult = _detectTeethRegion(imageFile);

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

              if (detectionResult == null) ...[
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
                    'Tentar novamente',
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
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Seguir para Ajustes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/adjust',
                      arguments: {
                        'image': imageFile.path,
                        'region': detectionResult, // coordenadas dos dentes
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Função simulada para detectar região dos dentes
  Map<String, dynamic>? _detectTeethRegion(File image) {
    // Aqui você integraria ML Kit ou TensorFlow Lite.
    // Por enquanto, vamos simular coordenadas fixas.
    // Se não detectar nada, retorna null.

    // Exemplo de coordenadas simuladas (bounding box dos dentes)
    return {
      'left': 100,
      'top': 200,
      'right': 300,
      'bottom': 280,
    };
  }
}
