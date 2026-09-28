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

    // Recupera coordenadas da região dos dentes ou centraliza se não houver
    final region = widget.region ?? {};
    final imageWidth = original.width.toDouble();
    final imageHeight = original.height.toDouble();

    final left = (region['left'] ?? imageWidth * 0.3).toDouble();
    final top = (region['top'] ?? imageHeight * 0.6).toDouble();
    final right = (region['right'] ?? imageWidth * 0.7).toDouble();
    final bottom = (region['bottom'] ?? imageHeight * 0.8).toDouble();
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

            // Pré-visualização da foto com filtros + zoom + overlay dinâmico
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Stack(
                    children: [
                      _previewFile != null
                          ? Image.file(_previewFile!, fit: BoxFit.contain)
                          : Image.file(widget.image, fit: BoxFit.contain),

                      if (widget.region != null)
                        Positioned(
                          left: widget.region!['left']?.toDouble() ?? 100,
                          top: widget.region!['top']?.toDouble() ?? 200,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                widget.region!['left'] =
                                    (widget.region!['left'] ?? 100) + details.delta.dx;
                                widget.region!['top'] =
                                    (widget.region!['top'] ?? 200) + details.delta.dy;
                              });
                              _applyPreviewFilters();
                            },
                            child: Container(
                              width: (widget.region!['right'] ?? 300).toDouble() -
                                  (widget.region!['left'] ?? 100).toDouble(),
                              height: (widget.region!['bottom'] ?? 280).toDouble() -
                                  (widget.region!['top'] ?? 200).toDouble(),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red, width: 2),
                                color: Colors.red.withOpacity(0.2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

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
