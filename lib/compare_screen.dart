import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  double _sliderValue = 0.5;

  @override
  Widget build(BuildContext context) {
    // Recupera os argumentos passados via Navigator
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? originalPath = args?['originalImage'];
    final Uint8List? processedBytes = args?['processedBytes'];

    if (originalPath == null || processedBytes == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparação')),
        body: const Center(
          child: Text('Erro ao carregar imagens para comparação.'),
        ),
      );
    }

    final File originalFile = File(originalPath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Simulação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Compartilhamento em PDF/Imagem
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // 1. Foto Processada pela IA (Fundo Completo)
                        Positioned.fill(
                          child: Image.memory(
                            processedBytes,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // 2. Foto Original (Revelada de acordo com o Slider)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: constraints.maxWidth * _sliderValue,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: constraints.maxWidth,
                              maxWidth: constraints.maxWidth,
                              child: Image.file(
                                originalFile,
                                fit: BoxFit.cover,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                              ),
                            ),
                          ),
                        ),

                        // 3. Linha divisória vertical do Slider (Efeito Cortina)
                        Positioned(
                          left: (constraints.maxWidth * _sliderValue) - 1.5,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Controle Deslizante (Original ↔ Com IA)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Original', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _sliderValue,
                    activeColor: const Color(0xFF5C6BC0),
                    onChanged: (val) => setState(() => _sliderValue = val),
                  ),
                ),
                const Text('Com IA', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Botões de Ação Final
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text('Ajustar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Gerar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Geração de relatório PDF
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}