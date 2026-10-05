import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class AutoAlignSmileScreen extends StatefulWidget {
  final File imageFile;

  const AutoAlignSmileScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<AutoAlignSmileScreen> createState() => _AutoAlignSmileScreenState();
}

class _AutoAlignSmileScreenState extends State<AutoAlignSmileScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  bool _isAnalyzing = true;
  bool _isProcessing = false;
  String? _errorMessage;

  // Informações calculadas pelo ML Kit
  Rect? _mouthRect;
  double _headAngleZ = 0.0; // Inclinacao da cabeca

  // Opacidade do molde e formato selecionado
  double _opacity = 0.85;
  String _selectedShape = 'oval';

  final Map<String, Map<String, String>> _shapes = {
    'oval': {'label': 'Oval', 'path': 'assets/images/teeth_oval.png'},
    'square': {'label': 'Quadrado', 'path': 'assets/images/teeth_square.png'},
    'rectangular': {'label': 'Retangular', 'path': 'assets/images/teeth_rectangular.png'},
    'triangular': {'label': 'Triangular', 'path': 'assets/images/teeth_triangular.png'},
  };

  @override
  void initState() {
    super.initState();
    _detectFaceAndPositionMouth();
  }

  Future<void> _detectFaceAndPositionMouth() async {
    try {
      final inputImage = InputImage.fromFile(widget.imageFile);
      final options = FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      );
      final faceDetector = FaceDetector(options: options);

      final List<Face> faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _errorMessage = 'Nenhum rosto encontrado na foto. Tente tirar outra foto mais de perto.';
          _isAnalyzing = false;
        });
        await faceDetector.close();
        return;
      }

      final face = faces.first;
      _headAngleZ = face.headEulerAngleZ ?? 0.0;

      // Busca os pontos de referencia dos cantos da boca
      final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
      final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
      final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

      final boundingBox = face.boundingBox;

      double mouthWidth;
      double mouthCenterX;
      double mouthCenterY;

      if (leftMouth != null && rightMouth != null) {
        // Distancia entre os cantos da boca
        mouthWidth = (rightMouth.x - leftMouth.x).abs().toDouble() * 1.35;
        mouthCenterX = (leftMouth.x + rightMouth.x) / 2;
        mouthCenterY = (bottomMouth != null)
            ? bottomMouth.y.toDouble() - (mouthWidth * 0.15)
            : (leftMouth.y + rightMouth.y) / 2;
      } else {
        // Estimativa com base no contorno do rosto caso os landmarks falhem
        mouthWidth = boundingBox.width * 0.45;
        mouthCenterX = boundingBox.left + (boundingBox.width / 2);
        mouthCenterY = boundingBox.top + (boundingBox.height * 0.72);
      }

      double mouthHeight = mouthWidth * 0.42;

      setState(() {
        _mouthRect = Rect.fromCenter(
          center: Offset(mouthCenterX, mouthCenterY),
          width: mouthWidth,
          height: mouthHeight,
        );
        _isAnalyzing = false;
      });

      await faceDetector.close();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao processar imagem: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _captureAndNavigate() async {
    setState(() => _isProcessing = true);

    try {
      RenderRepaintBoundary boundary =
      _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/auto_smile_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/compare',
        arguments: {
          'originalImage': widget.imageFile.path,
          'adjustedImage': file.path,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar resultado: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alinhamento Automático'),
      ),
      body: _isAnalyzing
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Detectando rosto e alinhando dentes...'),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.orange),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tirar Outra Foto'),
              )
            ],
          ),
        ),
      )
          : Column(
        children: [
          // Seletor de Formatos Dentarios
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: _shapes.entries.map((entry) {
                final isSelected = _selectedShape == entry.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(entry.value['label']!),
                    selected: isSelected,
                    selectedColor: Colors.deepPurple.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.deepPurple : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedShape = entry.key);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Área Principal da Foto + Moldes
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: RepaintBoundary(
                key: _repaintKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // 1. Foto do Paciente
                          Positioned.fill(
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.cover,
                            ),
                          ),

                          // 2. Sobreposição Automática dos Dentes
                          if (_mouthRect != null)
                            Positioned(
                              left: _mouthRect!.left,
                              top: _mouthRect!.top,
                              width: _mouthRect!.width,
                              height: _mouthRect!.height,
                              child: Transform.rotate(
                                angle: _headAngleZ * (3.141592653589793 / 180),
                                child: Opacity(
                                  opacity: _opacity,
                                  child: Image.asset(
                                    _shapes[_selectedShape]!['path']!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Controle de Opacidade
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
            child: Row(
              children: [
                const Text('Opacidade:', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.2,
                    max: 1.0,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) => setState(() => _opacity = val),
                  ),
                ),
              ],
            ),
          ),

          // Botão para Confirmar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 20.0),
            child: ElevatedButton.icon(
              icon: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isProcessing ? 'Processando...' : 'Confirmar e Comparar'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF5C6BC0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isProcessing ? null : _captureAndNavigate,
            ),
          ),
        ],
      ),
    );
  }
}