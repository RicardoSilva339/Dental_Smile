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
            // Campo de texto para observações
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Observações do dentista',
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

                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (route) => false);
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

                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (route) => false);
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

    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Relatório de Simulação de Sorriso',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Cor: ${item['color']}'),
            pw.Text('Formato: ${item['shape']}'),
            pw.Text('Tamanho: ${item['size']}'),
            pw.SizedBox(height: 20),
            pw.Text('Observações: $note'),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/relatorio_sorriso.pdf');
    await file.writeAsBytes(await pdf.save());

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'relatorio_sorriso.pdf');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Relatório salvo em ${file.path} e pronto para compartilhar!')),
    );
  }
}
