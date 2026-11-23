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
        final path =
            args['imagePath'] ?? args['image'] ?? args['originalImagePath'];
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
        padding:
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Imagem Capturada',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // 🖼️ Foto capturada com espaço proporcional
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
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
                      : const Icon(Icons.image_not_supported,
                      size: 80, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 🦷 Guia da Tonalidade baseado na escala VITA Bleachedguide
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tonalidades baseadas na escala VITA Bleachedguide',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF3F51B5),
                    ),
                  ),
                  const Text(
                    'Do clareamento mais intenso ao mais próximo do tom natural:',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildLinhaEscala(
                    'BL1',
                    'Máximo clareamento:',
                    'o tom mais claro e intenso da escala, para quem busca o branco mais destacado.',
                  ),
                  const SizedBox(height: 4),
                  _buildLinhaEscala(
                    'BL2',
                    'Clareamento intenso:',
                    'branco bem claro e marcante, com forte correção do tom.',
                  ),
                  const SizedBox(height: 4),
                  _buildLinhaEscala(
                    'BL3',
                    'Próximo ao natural ("claro"):',
                    'alinhado à tonalidade natural dos dentes, com resultado equilibrado.',
                  ),
                  const SizedBox(height: 4),
                  _buildLinhaEscala(
                    'BL4',
                    'Próximo ao tom atual / natural:',
                    'o mais discreto e próximo da coloração natural do dente humano.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Botão Principal para Seguir para os Ajustes do Sorriso
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
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_imageFile != null) {
                    Navigator.pushNamed(
                      context,
                      '/adjust',
                      arguments: {
                        'image': _imageFile!,
                        'simulationId': _simulationId,
                        'userEmail': _userEmail,
                      },
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 2),

            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon:
              const Icon(Icons.refresh, size: 16, color: Colors.grey),
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

  Widget _buildLinhaEscala(String code, String titulo, String descricao) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade800,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: '$titulo ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(text: descricao),
              ],
            ),
          ),
        ),
      ],
    );
  }
}