import 'dart:io';
import 'package:flutter/material.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  File? _imageFile;
  String _simulationId = '';
  String _userEmail = '';
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map<String, dynamic>) {
        final path = args['imagePath'] ?? args['image'] ?? args['originalImagePath'];
        if (path is String && path.isNotEmpty) {
          _imageFile = File(path);
        } else if (path is File) {
          _imageFile = path;
        }

        // 🔍 Extrai o ID da simulação e o e-mail do usuário ativo
        _simulationId = args['simulationId'] ?? '';
        _userEmail = args['userEmail'] ?? '';
      } else if (args is String && args.isNotEmpty) {
        _imageFile = File(args);
      } else if (args is File) {
        _imageFile = args;
      }

      _processarCarregamento();
      _isInit = false;
    }
  }

  Future<void> _processarCarregamento() async {
    // Breve pausa para dar fluidez visual ao transitar da captura
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise da Imagem'),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparando imagem...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Imagem Carregada',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Preview da imagem
            if (_imageFile != null && _imageFile!.existsSync())
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _imageFile!,
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),

            const SizedBox(height: 40),

            // Botão Principal: Seguir para Ajustes
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Seguir para Ajustes do Sorriso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_imageFile != null) {
                    Navigator.pushNamed(
                      context,
                      '/adjust',
                      arguments: {
                        'imagePath': _imageFile!.path,
                        'image': _imageFile,
                        'simulationId': _simulationId, // 👈 Repassa o ID
                        'userEmail': _userEmail,       // 👈 Repassa o e-mail do usuário
                      },
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 12),

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