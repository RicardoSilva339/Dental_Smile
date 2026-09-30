import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class SimulationDetailScreen extends StatelessWidget {
  final Map data;

  const SimulationDetailScreen({super.key, required this.data});

  Future<void> _gerarRelatorio(BuildContext context) async {
    final pdf = pw.Document();

    // Página com atributos e observações
    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Relatório de Simulação de Sorriso',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Cor: ${data['color'] ?? '-'}'),
            pw.Text('Formato: ${data['shape'] ?? '-'}'),
            pw.Text('Tamanho: ${data['size'] ?? '-'}'),
            pw.SizedBox(height: 20),
            pw.Text('Observações: ${data['note'] ?? 'Sem observações'}'),
          ],
        ),
      ),
    );

    // Página com imagens (com checagem se os arquivos realmente existem no celular)
    final String? originalPath = data['originalImage'];
    final String? adjustedPath = data['adjustedImage'];

    if (originalPath != null && File(originalPath).existsSync()) {
      final beforeImage = pw.MemoryImage(await File(originalPath).readAsBytes());
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            children: [
              pw.Text("Imagem Original"),
              pw.SizedBox(height: 10),
              pw.Image(beforeImage, width: 250, height: 250),
            ],
          ),
        ),
      );
    }

    if (adjustedPath != null && File(adjustedPath).existsSync()) {
      final afterImage = pw.MemoryImage(await File(adjustedPath).readAsBytes());
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            children: [
              pw.Text("Imagem Ajustada"),
              pw.SizedBox(height: 10),
              pw.Image(afterImage, width: 250, height: 250),
            ],
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Salva no Hive
    var box = Hive.box('simulacoes');
    box.put(DateTime.now().toIso8601String(), {
      ...data,
      'pdfPath': file.path,
    });

    await Printing.sharePdf(bytes: await pdf.save(), filename: file.path.split('/').last);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relatório salvo em ${file.path} e pronto para compartilhar!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? originalPath = data['originalImage'];
    final String? adjustedPath = data['adjustedImage'];

    return Scaffold(
      appBar: AppBar(title: const Text("Detalhes da Simulação")),
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

            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Gerar Relatório PDF"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => _gerarRelatorio(context),
            ),
          ],
        ),
      ),
    );
  }
}