import 'dart:io';
import 'package:flutter/material.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  bool _smileDetected = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _analisarImagem();
  }

  Future<void> _analisarImagem() async {
    // Simulação da análise com IA (substitua pelo seu serviço/API real)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
        // Altere para a lógica real que valida a presença do sorriso
        _smileDetected = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final imagePath = args?['imagePath'] as String?;
    if (imagePath != null) {
      _imageFile = File(imagePath);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise com IA'),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analisando imagem com IA...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Resultado da Análise',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Preview da imagem com bordas suavizadas e sombra sutil
            if (_imageFile != null && _imageFile!.existsSync())
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _imageFile!,
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),

            const SizedBox(height: 24),

            // Mensagem Dinâmica de Validação
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _smileDetected ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _smileDetected ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _smileDetected
                      ? 'Sorriso detectado com sucesso!'
                      : 'Sorriso não detectado na foto.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _smileDetected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Botão Principal: Seguir para Ajustes
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _smileDetected ? Colors.deepPurple : Colors.orange[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: Icon(_smileDetected ? Icons.arrow_forward : Icons.camera_alt),
                label: Text(
                  _smileDetected ? 'Seguir para Ajustes' : 'Tirar Nova Foto',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_smileDetected) {
                    Navigator.pushNamed(
                      context,
                      '/adjust',
                      arguments: {'image': _imageFile},
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),

            const SizedBox(height: 12),

            // Botão Secundário: Recapturar foto se necessário
            if (_smileDetected)
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                label: const Text(
                  'Tirar outra foto',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}