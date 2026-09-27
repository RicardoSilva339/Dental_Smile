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
            pw.Text('Cor: ${data['color']}'),
            pw.Text('Formato: ${data['shape']}'),
            pw.Text('Tamanho: ${data['size']}'),
            pw.SizedBox(height: 20),
            pw.Text('Observações: ${data['note'] ?? ''}'),
          ],
        ),
      ),
    );

    // Página com imagens
    if (data['originalImage'] != null) {
      final beforeImage = pw.MemoryImage(await File(data['originalImage']).readAsBytes());
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            children: [
              pw.Text("Imagem Original"),
              pw.Image(beforeImage, width: 200, height: 200),
            ],
          ),
        ),
      );
    }

    if (data['adjustedImage'] != null) {
      final afterImage = pw.MemoryImage(await File(data['adjustedImage']).readAsBytes());
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            children: [
              pw.Text("Imagem Ajustada"),
              pw.Image(afterImage, width: 200, height: 200),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Relatório salvo em ${file.path} e pronto para compartilhar!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalhes da Simulação")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Comparação Antes e Depois",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text("Original"),
                    if (data['originalImage'] != null)
                      Image.file(File(data['originalImage']), height: 150),
                  ],
                ),
                Column(
                  children: [
                    const Text("Ajustada"),
                    if (data['adjustedImage'] != null)
                      Image.file(File(data['adjustedImage']), height: 150),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text("Cor: ${data['color']}"),
            Text("Formato: ${data['shape']}"),
            Text("Tamanho: ${data['size']}"),
            const SizedBox(height: 10),
            Text("Observações: ${data['note']}"),

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
