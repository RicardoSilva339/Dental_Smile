import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  double _sliderValue = 1.0;
  bool _isGeneratingPdf = false;

  Future<void> _handleGeneratePdf({
    required String? originalPath,
    required String? processedPath,
  }) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfDoc = await _gerarDocumentoPdf(
        originalPath: originalPath,
        adjustedPath: processedPath,
      );

      final pdfBytes = await pdfDoc.save();

      if (!mounted) return;

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Relatorio_Dental_Smile.pdf',
      );
    } catch (e) {
      debugPrint('Erro ao gerar/imprimir PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar relatório PDF: $e')),
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
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final originalPath = args?['originalImagePath'] as String?;
    final processedPath = args?['processedImagePath'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Simulação'),
      ),
      body: Column(
        children: [
          // Área de visualização comparativa com BoxFit.contain
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Camada 1: Foto Original (Fundo)
                    if (originalPath != null && File(originalPath).existsSync())
                      Image.file(
                        File(originalPath),
                        fit: BoxFit.contain, // ✅ Garante que a foto não seja esticada/cortada
                        width: double.infinity,
                        height: double.infinity,
                      )
                    else
                      const Center(child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey)),

                    // Camada 2: Foto Processada por IA (Sobreposta com opacidade do slider)
                    if (processedPath != null && File(processedPath).existsSync())
                      Opacity(
                        opacity: _sliderValue,
                        child: Image.file(
                          File(processedPath),
                          fit: BoxFit.contain, // ✅ Alinhamento perfeito com a camada de fundo
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Controlo deslizante (Slider Original <-> Com IA)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Original', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _sliderValue,
                    onChanged: (val) => setState(() => _sliderValue = val),
                    activeColor: const Color(0xFF5C6BC0),
                  ),
                ),
                const Text('Com IA', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Botões inferiores (Voltar a Ajustar / Gerar PDF)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('Ajustar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isGeneratingPdf
                        ? null
                        : () => _handleGeneratePdf(
                      originalPath: originalPath,
                      processedPath: processedPath,
                    ),
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGeneratingPdf ? 'Gerando...' : 'Gerar PDF'),
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

// -----------------------------------------------------------------------------
// MÉTODOS AUXILIARES DE PDF
// -----------------------------------------------------------------------------

Future<pw.MemoryImage?> _carregarImagemSegura(String? path) async {
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint('Erro ao ler bytes da imagem ($path): $e');
      }
    }
  }
  return null;
}

Future<pw.Document> _gerarDocumentoPdf({
  required String? originalPath,
  required String? adjustedPath,
  String? color,
  String? shape,
  String? size,
  String? note,
}) async {
  final pdf = pw.Document();

  final beforeImage = await _carregarImagemSegura(originalPath);
  final afterImage = await _carregarImagemSegura(adjustedPath);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, // ✅ Corrigido
        children: [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Relatório de Simulação - Dental Smile',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 15),

          pw.Text(
            'Parâmetros do Planeamento:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('• Cor: ${color ?? '-'}'),
          pw.Text('• Formato: ${shape ?? '-'}'),
          pw.Text('• Tamanho: ${size ?? '-'}'),
          pw.Text('• Observações: ${note ?? 'Sem observações'}'),

          pw.SizedBox(height: 25),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              if (beforeImage != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Antes (Original)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Image(beforeImage, width: 200, height: 250),
                  ],
                ),
              if (afterImage != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Depois (Simulação)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Image(afterImage, width: 200, height: 250),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
  );

  return pdf;
}