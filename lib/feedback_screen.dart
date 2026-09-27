import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class FeedbackScreen extends StatelessWidget {
  final Map existingItem;

  const FeedbackScreen({super.key, required this.existingItem});

  @override
  Widget build(BuildContext context) {
    final String? originalImage = existingItem['originalImage'];
    final String? adjustedImage = existingItem['adjustedImage'];
    final TextEditingController noteController =
    TextEditingController(text: existingItem['note'] ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback do Dentista')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pré-visualização das imagens
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (originalImage != null)
                  Column(
                    children: [
                      const Text("Original", style: TextStyle(fontWeight: FontWeight.bold)),
                      Image.file(File(originalImage), height: 150, fit: BoxFit.cover),
                    ],
                  ),
                if (adjustedImage != null)
                  Column(
                    children: [
                      const Text("Ajustada", style: TextStyle(fontWeight: FontWeight.bold)),
                      Image.file(File(adjustedImage), height: 150, fit: BoxFit.cover),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Campo de texto para observações
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Observações do dentista',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    var box = Hive.box('simulacoes');
                    box.put(DateTime.now().toIso8601String(), {
                      ...existingItem,
                      'note': noteController.text,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feedback salvo no histórico!')),
                    );

                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                  child: const Text('Salvar Feedback'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _gerarRelatorio(
                      context,
                      originalImage,
                      adjustedImage,
                      noteController.text,
                      existingItem,
                    );

                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                  child: const Text('Gerar Relatório PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _gerarRelatorio(
      BuildContext context,
      String? original,
      String? adjusted,
      String note,
      Map item,
      ) async {
    final pdf = pw.Document();

    // Página com atributos + observações + imagens
    final List<pw.Widget> content = [
      pw.Text('Relatório de Simulação de Sorriso',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      pw.Text('Cor: ${item['color']}'),
      pw.Text('Formato: ${item['shape']}'),
      pw.Text('Tamanho: ${item['size']}'),
      pw.SizedBox(height: 20),
      pw.Text('Observações: $note'),
      pw.SizedBox(height: 20),
    ];

    if (original != null && adjusted != null) {
      final beforeImage = pw.MemoryImage(await File(original).readAsBytes());
      final afterImage = pw.MemoryImage(await File(adjusted).readAsBytes());

      content.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            pw.Column(
              children: [
                pw.Text("Original"),
                pw.Image(beforeImage, width: 200, height: 200),
              ],
            ),
            pw.Column(
              children: [
                pw.Text("Ajustada"),
                pw.Image(afterImage, width: 200, height: 200),
              ],
            ),
          ],
        ),
      );
    }

    // Assinatura ou carimbo da clínica
    final signaturePath = item['signaturePath']; // caminho da imagem de assinatura
    if (signaturePath != null) {
      final signatureImage = pw.MemoryImage(await File(signaturePath).readAsBytes());
      content.add(pw.SizedBox(height: 30));
      content.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text("Assinatura / Carimbo da Clínica"),
            pw.Image(signatureImage, width: 150, height: 80),
          ],
        ),
      );
    }

    pdf.addPage(pw.Page(build: (ctx) => pw.Column(children: content)));

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Salva no Hive
    var box = Hive.box('simulacoes');
    box.put(DateTime.now().toIso8601String(), {
      ...item,
      'note': note,
      'originalImage': original,
      'adjustedImage': adjusted,
      'pdfPath': file.path,
      'signaturePath': signaturePath,
    });

    await Printing.sharePdf(bytes: await pdf.save(), filename: file.path.split('/').last);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Relatório salvo em ${file.path} e pronto para compartilhar!')),
    );
  }
}
