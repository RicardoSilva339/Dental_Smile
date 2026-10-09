import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  // Controller para capturar o texto digitado pelo dentista
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Função auxiliar para resetar a navegação e retornar à tela inicial
  void _goToHomeScreen() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Salva a simulação no banco local (Hive) para que apareça no HistoryScreen
  Future<void> _salvarNoHistorico({
    required String? originalPath,
    required String? processedPath,
    required String? color,
    required String? shape,
    required String? size,
    required String? note,
  }) async {
    try {
      final box = Hive.box('simulacoes');
      final now = DateTime.now();
      final dataFormatada =
          "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      await box.add({
        'date': dataFormatada,
        'originalImage': originalPath ?? '',
        'originalImagePath': originalPath ?? '', // compatibilidade com chaves alternativas
        'adjustedImage': processedPath ?? '',
        'processedImagePath': processedPath ?? '', // compatibilidade com chaves alternativas
        'color': color ?? '-',
        'shape': shape ?? '-',
        'size': size ?? '-',
        'note': note ?? 'Sem observações',
        'notes': note ?? 'Sem observações',
      });
      debugPrint('Simulação salva no Hive com sucesso!');
    } catch (e) {
      debugPrint('Erro ao salvar no Hive: $e');
    }
  }

  Future<void> _handleGeneratePdf({
    required String? originalPath,
    required String? processedPath,
    required String? color,
    required String? shape,
    required String? size,
  }) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final noteText = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      // 1. Gera o PDF
      final pdfDoc = await _gerarDocumentoPdf(
        originalPath: originalPath,
        adjustedPath: processedPath,
        color: color,
        shape: shape,
        size: size,
        note: noteText,
      );

      final pdfBytes = await pdfDoc.save();

      // 2. Persiste os dados da simulação no Hive para o Histórico
      await _salvarNoHistorico(
        originalPath: originalPath,
        processedPath: processedPath,
        color: color,
        shape: shape,
        size: size,
        note: noteText,
      );

      if (!mounted) return;

      // 3. Abre a janela de impressão / salvamento do PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Relatorio_Dental_Smile.pdf',
      );

      // 4. Caixa de diálogo pós-impressão/geração de PDF
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Simulação Concluída'),
            content: const Text('O relatório PDF foi gerado e salvo no histórico. Deseja voltar à tela inicial para iniciar um novo atendimento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Permanecer'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _goToHomeScreen();
                },
                child: const Text('Voltar ao Início'),
              ),
            ],
          ),
        );
      }
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
    final originalPath = args?['originalImagePath'] as String? ?? args?['originalImage'] as String?;
    final processedPath = args?['processedImagePath'] as String? ?? args?['adjustedImage'] as String?;

    // Resgata os parâmetros passados da tela de seleção
    final selectedColor = args?['color'] as String? ?? args?['selectedColor'] as String?;
    final selectedShape = args?['shape'] as String? ?? args?['selectedShape'] as String?;
    final selectedSize = args?['size'] as String? ?? args?['selectedSize'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Simulação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Voltar ao Início',
            onPressed: _goToHomeScreen,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Área de visualização comparativa (Antes / Depois)
            SizedBox(
              height: 400,
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
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      else
                        const Center(child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey)),

                      // Camada 2: Foto Processada por IA
                      if (processedPath != null && File(processedPath).existsSync())
                        Opacity(
                          opacity: _sliderValue,
                          child: Image.file(
                            File(processedPath),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Controle deslizante (Slider Original <-> Com IA)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
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

            // Campo de Observações do Dentista
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Observações do Dentista:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Digite aqui as observações para o paciente...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            // Botões inferiores (Ajustar / Gerar PDF)
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
                        color: selectedColor,
                        shape: selectedShape,
                        size: selectedSize,
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
        crossAxisAlignment: pw.CrossAxisAlignment.start,
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