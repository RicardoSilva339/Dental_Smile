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
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
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
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Imagem Capturada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 🖼️ Foto com espaço expandido para ficar bem nítida e ampla
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (_imageFile != null && _imageFile!.existsSync())
                      ? Image.file(
                    _imageFile!,
                    fit: BoxFit.contain,
                  )
                      : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 🦷 Guia Explicativo Compacto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Guia da Tonalidade (Escala Bleach):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF3F51B5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniGuide('BL1', 'Ultra'),
                      _buildMiniGuide('BL2', 'Intenso'),
                      _buildMiniGuide('BL3', 'Natural'),
                      _buildMiniGuide('BL4', 'Suave'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Botão Principal
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(
                  'Seguir para Ajustes do Sorriso',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_imageFile != null) {
                    Navigator.pushNamed(
                      context,
                      '/adjust',
                      arguments: {
                        'imagePath': _imageFile!.path,
                        'image': _imageFile,
                        'simulationId': _simulationId,
                        'userEmail': _userEmail,
                      },
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 4),

            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
              label: const Text(
                'Tirar outra foto',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGuide(String code, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.indigo,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
      ],
    );
  }
}