import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  double _sliderValue = 0.5;
  bool _isGeneratingPdf = false;

  /// Função responsável por compilar o PDF e abrir o gerenciador nativo do dispositivo
  Future<void> _generateAndShowPdf({
    required String originalPath,
    required Uint8List? processedBytes,
    required String? processedPath,
  }) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();

      // 1. Carrega os bytes da imagem original
      final Uint8List originalBytes = await File(originalPath).readAsBytes();

      // 2. Carrega ou resolve os bytes da imagem processada
      Uint8List? finalProcessedBytes = processedBytes;
      if (finalProcessedBytes == null && processedPath != null) {
        finalProcessedBytes = await File(processedPath).readAsBytes();
      }

      if (finalProcessedBytes == null) {
        throw Exception("Não foi possível obter a imagem processada para o PDF.");
      }

      final imgOriginal = pw.MemoryImage(originalBytes);
      final imgProcessed = pw.MemoryImage(finalProcessedBytes);

      // 3. Constrói o layout da página do PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Relatório Digital Smile Design',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Simulação de Planejamento Estético Dental'),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('Original (Antes)',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 8),
                          pw.Image(imgOriginal, width: 220, height: 280),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('Simulação IA (Depois)',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 8),
                          pw.Image(imgProcessed, width: 220, height: 280),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 4. Abre a interface nativa de impressão/salvamento no Android
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Simulacao_Dental_Smile.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? originalPath = args?['originalImage'] ?? args?['originalImagePath'];
    final Uint8List? processedBytes = args?['processedBytes'];
    final String? processedPath = args?['processedImage'] ?? args?['processedImagePath'];

    if (originalPath == null || (processedBytes == null && processedPath == null)) {
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
              _generateAndShowPdf(
                originalPath: originalPath,
                processedBytes: processedBytes,
                processedPath: processedPath,
              );
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
                        // 1. Foto Processada pela IA (Fundo)
                        Positioned.fill(
                          child: processedBytes != null
                              ? Image.memory(
                            processedBytes,
                            fit: BoxFit.cover,
                          )
                              : (processedPath!.startsWith('http')
                              ? Image.network(
                            processedPath,
                            fit: BoxFit.cover,
                          )
                              : Image.file(
                            File(processedPath),
                            fit: BoxFit.cover,
                          )),
                        ),

                        // 2. Foto Original (Efeito Cortina)
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

                        // 3. Linha divisória vertical
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

          // Controle Deslizante
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

          // Botões de Ação
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
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGeneratingPdf ? 'Gerando...' : 'Gerar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isGeneratingPdf
                        ? null
                        : () {
                      _generateAndShowPdf(
                        originalPath: originalPath,
                        processedBytes: processedBytes,
                        processedPath: processedPath,
                      );
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