import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SimulationDetailScreen extends StatelessWidget {
  final Map data;

  const SimulationDetailScreen({super.key, required this.data});

  Future<void> _gerarRelatorio(BuildContext context) async {
    final pdf = pw.Document();

    final String? originalPath = data['originalImage'];
    final String? adjustedPath = data['adjustedImage'];

    pw.MemoryImage? beforeImage;
    pw.MemoryImage? afterImage;

    if (originalPath != null && File(originalPath).existsSync()) {
      beforeImage = pw.MemoryImage(await File(originalPath).readAsBytes());
    }

    if (adjustedPath != null && File(adjustedPath).existsSync()) {
      afterImage = pw.MemoryImage(await File(adjustedPath).readAsBytes());
    }

    // Monta o relatório estruturado numa única página A4
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

            // Detalhes do Planeamento
            pw.Text(
              'Parâmetros Selecionados:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('• Cor: ${data['color'] ?? '-'}'),
            pw.Text('• Formato: ${data['shape'] ?? '-'}'),
            pw.Text('• Tamanho: ${data['size'] ?? '-'}'),
            pw.Text('• Observações: ${data['note'] ?? 'Sem observações'}'),

            pw.SizedBox(height: 25),

            // Imagens Antes x Depois lado a lado
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                if (beforeImage != null)
                  pw.Column(
                    children: [
                      pw.Text("Antes (Original)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Image(beforeImage, width: 200, height: 250),
                    ],
                  ),
                if (afterImage != null)
                  pw.Column(
                    children: [
                      pw.Text("Depois (Simulação)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Image(afterImage, width: 200, height: 250),
                    ],
                  ),
              ],
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Relatório gerado automaticamente pelo aplicativo Dental Smile.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    // 1. Salva o ficheiro no armazenamento local
    final dir = await getApplicationDocumentsDirectory();
    final pdfFile = File('${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final pdfBytes = await pdf.save();
    await pdfFile.writeAsBytes(pdfBytes);

    // 2. Salva o registo no Hive
    var box = Hive.box('simulacoes');
    box.put(DateTime.now().toIso8601String(), {
      ...data,
      'pdfPath': pdfFile.path,
    });

    // 3. Abre a janela nativa de impressão/partilha
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Relatorio_Dental_Smile.pdf',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Relatório gerado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? originalPath = data['originalImage'];
    final String? adjustedPath = data['adjustedImage'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhes da Simulação"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                "Comparação Antes e Depois",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text("Original", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    (originalPath != null && File(originalPath).existsSync())
                        ? Image.file(File(originalPath), height: 140, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                  ],
                ),
                Column(
                  children: [
                    const Text("Ajustada", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    (adjustedPath != null && File(adjustedPath).existsSync())
                        ? Image.file(File(adjustedPath), height: 140, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),
            Text("Cor: ${data['color'] ?? '-'}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Formato: ${data['shape'] ?? '-'}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Tamanho: ${data['size'] ?? '-'}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text("Observações: ${data['note'] ?? 'Sem observações'}", style: const TextStyle(fontSize: 16)),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text(
                  "Gerar Relatório PDF",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _gerarRelatorio(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}