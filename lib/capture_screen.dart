import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'background.dart'; // Mantido caso queiras usar noutros locais, embora a câmara use ecrã cheio

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Seleciona preferencialmente a câmara traseira para maior nitidez nos dentes
        final cameraTraseira = _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          cameraTraseira,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Erro ao inicializar a câmara: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndCrop() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // 1. Tira a foto diretamente do sensor da câmara
      final XFile picture = await _controller!.takePicture();
      File originalFile = File(picture.path);

      // 2. Aplica o recorte matemático milimétrico focado na zona da oval
      File? croppedFile = await _processarRecorteOval(originalFile);

      if (!mounted) return;

      final simulationId = _gerarSimulationId();
      final userEmail = _obterEmailUsuarioAtual();

      // 3. Avança para a tela de análise com a imagem limpa e focada
      Navigator.pushNamed(
        context,
        '/analysis',
        arguments: {
          'image': (croppedFile ?? originalFile).path,
          'simulationId': simulationId,
          'userEmail': userEmail,
        },
      );
    } catch (e) {
      debugPrint("Erro ao capturar e recortar imagem: $e");
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<File?> _processarRecorteOval(File imagemOriginal) async {
    try {
      final bytes = await imagemOriginal.readAsBytes();
      final imagemDecodificada = img.decodeImage(bytes);
      if (imagemDecodificada == null) return imagemOriginal;

      int largura = imagemDecodificada.width;
      int altura = imagemDecodificada.height;

      // Define um quadrado centralizado focado no terço superior/médio (onde o rosto fica na oval)
      int menorLado = largura < altura ? largura : altura;
      int tamanhoCorte = (menorLado * 0.72).toInt(); // 72% da largura para fechar bem no rosto

      int offsetX = (largura - tamanhoCorte) ~/ 2;
      int offsetY = (altura - tamanhoCorte) ~/ 3; // Deslocado para cima para focar nos olhos/nariz/boca

      // Validações de segurança para evitar limites negativos
      if (offsetY < 0) offsetY = 0;
      if (offsetX < 0) offsetX = 0;
      if (offsetY + tamanhoCorte > altura) offsetY = altura - tamanhoCorte;
      if (offsetX + tamanhoCorte > largura) offsetX = largura - tamanhoCorte;

      // Recorta cirurgicamente a região do rosto
      img.Image imagemCropped = img.copyCrop(
        imagemDecodificada,
        x: offsetX,
        y: offsetY,
        width: tamanhoCorte,
        height: tamanhoCorte,
      );

      // Padroniza exatamente para 512x512 para o motor da IA
      img.Image imagemFinal = img.copyResize(
        imagemCropped,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      final targetPath = '${imagemOriginal.path}_face_oval.jpg';
      File arquivoFinal = File(targetPath)
        ..writeAsBytesSync(img.encodeJpg(imagemFinal, quality: 90));

      return arquivoFinal;
    } catch (e) {
      debugPrint("Erro no recorte oval: $e");
      return null;
    }
  }

  String _gerarSimulationId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(5);
    return 'DS-$timestamp';
  }

  String _obterEmailUsuarioAtual() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Pré-visualização da Câmara a ocupar todo o ecrã
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // 2. Máscara Escura com o Recorte Oval no Centro (Efeito Gov.br / Bancos)
          Positioned.fill(
            child: CustomPaint(
              painter: OvalOverlayPainter(),
            ),
          ),

          // 3. Cabeçalho e Textos Informativos
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Enquadramento Facial'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Posicione o rosto e o sorriso dentro da oval',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Botão de Disparo Estilo Profissional
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _isCapturing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : GestureDetector(
                onTap: _captureAndCrop,
                child: Container(
                  height: 75,
                  width: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: const Color(0xFF5C6BC0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎨 Pintor responsável por criar o efeito de "janela oval transparente" sobre fundo escuro
class OvalOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBackground = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Retângulo total do ecrã
    final rectTotal = Rect.fromLTWH(0, 0, size.width, size.height);

    // Dimensões e posição da moldura oval central
    final double ovalWidth = size.width * 0.72;
    final double ovalHeight = size.height * 0.48;
    final Rect ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: ovalWidth,
      height: ovalHeight,
    );

    final Path pathBackground = Path()..addRect(rectTotal);
    final Path pathOval = Path()..addOval(ovalRect);

    // Subtrai a oval do fundo escuro
    final Path pathFinal = Path.combine(
      PathOperation.difference,
      pathBackground,
      pathOval,
    );

    canvas.drawPath(pathFinal, paintBackground);

    // Desenha a linha de destaque da oval (Dourada / Amarela)
    final paintBorder = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawOval(ovalRect, paintBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}