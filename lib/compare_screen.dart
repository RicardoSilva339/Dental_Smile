import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class CompareScreen extends StatefulWidget {
  final String originalImage;
  final String adjustedImage; // agora recebemos direto da tela anterior
  final Map existingItem;

  const CompareScreen({
    super.key,
    required this.originalImage,
    required this.adjustedImage,
    required this.existingItem,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
Uint8List? processedImage;

@override
void initState() {
super.initState();
_loadAdjustedImage();
}

Future<void> _loadAdjustedImage() async {
final file = File(widget.adjustedImage);
final bytes = await file.readAsBytes();
setState(() {
processedImage = bytes;
});
}
Future<void> _gerarRelatorio(BuildContext context) async {
final pdf = pw.Document();

// Página com atributos escolhidos
pdf.addPage(
pw.Page(
build: (ctx) => pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.start,
children: [
pw.Text('Relatório de Simulação de Sorriso',
style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
pw.SizedBox(height: 20),
pw.Text('Cor: ${widget.existingItem['color'] ?? ''}'),
pw.Text('Formato: ${widget.existingItem['shape'] ?? ''}'),
pw.Text('Tamanho: ${widget.existingItem['size'] ?? ''}'),
pw.SizedBox(height: 20),
pw.Text('Observações: ${widget.existingItem['note'] ?? ''}'),
],
),
),
);

// Página com imagens antes/depois
final originalBytes = await File(widget.originalImage).readAsBytes();
final originalImg = pw.MemoryImage(originalBytes);

final adjustedBytes = await File(widget.adjustedImage).readAsBytes();
final adjustedImg = pw.MemoryImage(adjustedBytes);

pdf.addPage(
pw.Page(
build: (ctx) => pw.Row(
mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
children: [
pw.Column(
children: [
pw.Text("Original"),
pw.Image(originalImg, width: 200, height: 200),
],
),
pw.Column(
children: [
pw.Text("Ajustada pela IA"),
pw.Image(adjustedImg, width: 200, height: 200),
],
),
],
),
),
);

final dir = await getApplicationDocumentsDirectory();
final file = File('${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf');
await file.writeAsBytes(await pdf.save());

// Salva no Hive
var box = Hive.box('simulacoes');
box.put(DateTime.now().toIso8601String(), {
...widget.existingItem,
'originalImage': widget.originalImage,
'adjustedImage': widget.adjustedImage,
'pdfPath': file.path,
});

await Printing.sharePdf(bytes: await pdf.save(), filename: file.path.split('/').last);

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Relatório salvo em ${file.path} e pronto para compartilhar!')),
);
}
Widget _buildActionButtons(BuildContext context) {
return Column(
children: [
Row(
children: [
Expanded(
child: ElevatedButton(
onPressed: () {
Navigator.pop(context); // volta para ajustes
},
style: ElevatedButton.styleFrom(
minimumSize: const Size(double.infinity, 50),
backgroundColor: Colors.grey,
),
child: const Text("Voltar para Ajustes"),
),
),
const SizedBox(width: 10),
Expanded(
child: ElevatedButton(
onPressed: () {
Navigator.pushNamed(
context,
'/feedback',
arguments: {
...widget.existingItem,
'originalImage': widget.originalImage,
'adjustedImage': widget.adjustedImage,
},
);
},
style: ElevatedButton.styleFrom(
minimumSize: const Size(double.infinity, 50),
),
child: const Text(
"Confirmar Alteração",
style: TextStyle(fontWeight: FontWeight.bold),
),
),
),
],
),
const SizedBox(height: 20),
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
);
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Comparação Antes/Depois')),
    body: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            "Veja o resultado da simulação com IA",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Comparação lado a lado
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text("Antes"),
                    Image.file(
                      File(widget.originalImage),
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text("Depois (IA)"),
                    processedImage != null
                        ? Image.memory(
                      processedImage!,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    )
                        : Image.file(
                      File(widget.adjustedImage),
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Atributos escolhidos
          Text("Cor: ${widget.existingItem['color'] ?? ''}"),
          Text("Formato: ${widget.existingItem['shape'] ?? ''}"),
          Text("Tamanho: ${widget.existingItem['size'] ?? ''}"),

          const Spacer(),

          // Botões de ação (Parte 3)
          _buildActionButtons(context),
        ],
      ),
    ),
  );
}
}
