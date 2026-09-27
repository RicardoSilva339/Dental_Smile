import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

class AdjustSmileScreen extends StatefulWidget {
  final File image;
  final Map<String, dynamic>? region; // coordenadas dos dentes

  const AdjustSmileScreen({super.key, required this.image, this.region});

  @override
  State<AdjustSmileScreen> createState() => _AdjustSmileScreenState();
}

class _AdjustSmileScreenState extends State<AdjustSmileScreen> {
  String _selectedColor = 'Natural';
  String _selectedShape = 'Quadrado';
  String _selectedSize = 'Médio';

  File? _previewFile;

  @override
  void initState() {
    super.initState();
    _applyPreviewFilters(); // gera prévia inicial
  }

  /// Função para aplicar filtros estéticos em tempo real
  Future<void> _applyPreviewFilters() async {
    final bytes = await widget.image.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // Desenha imagem original
    canvas.drawImage(original, Offset.zero, paint);

    // Recupera coordenadas da região dos dentes
    final region = widget.region ?? {};
    final left = (region['left'] ?? 100).toDouble();
    final top = (region['top'] ?? 200).toDouble();
    final right = (region['right'] ?? 300).toDouble();
    final bottom = (region['bottom'] ?? 280).toDouble();
    final rect = Rect.fromLTRB(left, top, right, bottom);

    // Clareamento conforme cor escolhida
    if (_selectedColor != 'Natural') {
      final brighten = Paint()
        ..colorFilter = const ColorFilter.matrix([
          1.3, 0,   0,   0, 30,
          0,   1.3, 0,   0, 30,
          0,   0,   1.3, 0, 30,
          0,   0,   0,   1, 0,
        ]);
      canvas.saveLayer(rect, brighten);
      canvas.drawImageRect(original, rect, rect, brighten);
      canvas.restore();
    }

    // Overlay transparente para destacar dentes
    final overlayPaint = Paint()..color = Colors.white.withOpacity(0.08);
    canvas.drawRect(rect, overlayPaint);

    // Finaliza
    final picture = recorder.endRecording();
    final filteredImage = await picture.toImage(original.width, original.height);
    final byteData = await filteredImage.toByteData(format: ui.ImageByteFormat.png);

    final dir = await getTemporaryDirectory();
    final previewFile = File('${dir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.png');
    await previewFile.writeAsBytes(byteData!.buffer.asUint8List());

    setState(() {
      _previewFile = previewFile;
    });
  }

  void _applyAdjustments() async {
    // Usa a última prévia como versão ajustada
    final adjustedFile = _previewFile ?? widget.image;

    Navigator.pushNamed(
      context,
      '/compare',
      arguments: {
        'originalImage': widget.image.path,
        'adjustedImage': adjustedFile.path,
        'existingItem': {
          'color': _selectedColor,
          'shape': _selectedShape,
          'size': _selectedSize,
          'date': DateTime.now().toIso8601String(),
          'note': '',
          'region': widget.region,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes de Sorriso")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Controles de ajuste
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<String>(
                  value: _selectedColor,
                  items: const [
                    DropdownMenuItem(value: 'Natural', child: Text('Natural')),
                    DropdownMenuItem(value: 'Brilhante', child: Text('Brilhante')),
                    DropdownMenuItem(value: 'Perolado', child: Text('Perolado')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedColor = value!);
                    _applyPreviewFilters();
                  },
                ),
                DropdownButton<String>(
                  value: _selectedShape,
                  items: const [
                    DropdownMenuItem(value: 'Quadrado', child: Text('Quadrado')),
                    DropdownMenuItem(value: 'Arredondado', child: Text('Arredondado')),
                    DropdownMenuItem(value: 'Oval', child: Text('Oval')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedShape = value!);
                    _applyPreviewFilters();
                  },
                ),
                DropdownButton<String>(
                  value: _selectedSize,
                  items: const [
                    DropdownMenuItem(value: 'Curto', child: Text('Curto')),
                    DropdownMenuItem(value: 'Médio', child: Text('Médio')),
                    DropdownMenuItem(value: 'Longo', child: Text('Longo')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedSize = value!);
                    _applyPreviewFilters();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Pré-visualização da foto com filtros
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    _previewFile != null
                        ? Image.file(_previewFile!, height: 300, fit: BoxFit.cover)
                        : Image.file(widget.image, height: 300, fit: BoxFit.cover),
                    Container(
                      width: double.infinity,
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        "Cor: $_selectedColor | Formato: $_selectedShape | Tamanho: $_selectedSize",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botão aplicar
            ElevatedButton(
              onPressed: _applyAdjustments,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Aplicar Ajustes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
