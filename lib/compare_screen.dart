import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

class CompareScreen extends StatefulWidget {
  final String originalImage;
  final String adjustedImage;
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
File? filteredFile;

@override
void initState() {
super.initState();
_applyFilters(File(widget.adjustedImage)).then((file) {
setState(() {
filteredFile = file;
});
});
}
/// Função para aplicar filtros estéticos reais
Future<File> _applyFilters(File image) async {
final bytes = await image.readAsBytes();
final codec = await ui.instantiateImageCodec(bytes);
final frame = await codec.getNextFrame();
final original = frame.image;

final recorder = ui.PictureRecorder();
final canvas = Canvas(recorder);
final paint = Paint();

// 1. Desenha imagem original
canvas.drawImage(original, Offset.zero, paint);

// 2. Clareamento com ColorMatrix (dentes mais brancos)
final brighten = Paint()
..colorFilter = const ColorFilter.matrix([
1.2, 0,   0,   0, 20,
0,   1.2, 0,   0, 20,
0,   0,   1.2, 0, 20,
0,   0,   0,   1, 0,
]);
canvas.drawImage(original, Offset.zero, brighten);

// 3. Suavização da gengiva (blur leve)
final blurPaint = Paint()
..imageFilter = ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2);
canvas.drawImage(original, Offset.zero, blurPaint);

// 4. Overlay transparente (usando coordenadas se existirem)
if (widget.existingItem.containsKey('region') &&
widget.existingItem['region'] is Map) {
final region = widget.existingItem['region'] as Map;

final left = (region['left'] is num) ? (region['left'] as num).toDouble() : 100.0;
final top = (region['top'] is num) ? (region['top'] as num).toDouble() : 200.0;
final right = (region['right'] is num) ? (region['right'] as num).toDouble() : 300.0;
final bottom = (region['bottom'] is num) ? (region['bottom'] as num).toDouble() : 280.0;

final overlayPaint = Paint()..color = Colors.white.withOpacity(0.1);
canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), overlayPaint);
}

final picture = recorder.endRecording();
final filteredImage = await picture.toImage(original.width, original.height);
final byteData = await filteredImage.toByteData(format: ui.ImageByteFormat.png);

final dir = await getTemporaryDirectory();
final filteredFile = File('${dir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.png');
await filteredFile.writeAsBytes(byteData!.buffer.asUint8List());

return filteredFile;
}
Future<void> _gerarRelatorio(BuildContext context) async {
final pdf = pw.Document();

// Página com atributos
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
final adjustedBytes = await filteredFile!.readAsBytes();

final originalImg = pw.MemoryImage(originalBytes);
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
pw.Text("Ajustada"),
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
'adjustedImage': filteredFile!.path,
'pdfPath': file.path,
});

await Printing.sharePdf(bytes: await pdf.save(), filename: file.path.split('/').last);

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Relatório salvo em ${file.path} e pronto para compartilhar!')),
);
}
@override
Widget build(BuildContext context) {
  if (filteredFile == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  double sliderValue = MediaQuery.of(context).size.width / 2;

  return Scaffold(
    appBar: AppBar(title: const Text('Comparação Antes/Depois')),
    body: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            "Veja o resultado da simulação",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Comparação com Slider + Zoom com os dedos
          Expanded(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Stack(
                children: [
                  // Imagem original
                  Image.file(File(widget.originalImage),
                      width: double.infinity, fit: BoxFit.cover),

                  // Imagem ajustada revelada pelo ClipRect
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: sliderValue /
                          MediaQuery.of(context).size.width,
                      child: Image.file(filteredFile!,
                          width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),

                  // Slider para controlar a comparação
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Slider(
                      value: sliderValue,
                      min: 0,
                      max: MediaQuery.of(context).size.width,
                      onChanged: (value) {
                        setState(() {
                          sliderValue = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Atributos escolhidos
          Text("Cor: ${widget.existingItem['color'] ?? ''}"),
          Text("Formato: ${widget.existingItem['shape'] ?? ''}"),
          Text("Tamanho: ${widget.existingItem['size'] ?? ''}"),

          const Spacer(),

          // Botões de ação
          Column(
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
                            'adjustedImage': filteredFile!.path,
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
          ),
        ],
      ),
    ),
  );
}
}
