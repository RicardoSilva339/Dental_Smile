import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// 1. DECLARAÇÃO DA CLASSE CompareScreen (Faltava isso no arquivo)
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar Simulação'),
      ),
      body: const Center(
        child: Text('Tela de Comparação'),
      ),
    );
  }
}

// 2. MÉTODOS AUXILIARES DE GERAÇÃO DE PDF
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