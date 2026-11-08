import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;

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
        int _selectedCameraIndex = 0;

        @override
        void initState() {
                super.initState();
                _initializeCamera(_selectedCameraIndex);
        }

        Future<void> _initializeCamera(int cameraIndex) async {
                try {
                        _cameras = await availableCameras();
                        if (_cameras != null && _cameras!.isNotEmpty) {
                                if (cameraIndex >= _cameras!.length) cameraIndex = 0;

                                _controller = CameraController(
                                        _cameras![cameraIndex],
                                        ResolutionPreset.high,
                                        enableAudio: false,
                                );

                                await _controller!.initialize();
                                if (!mounted) return;
                                setState(() {
                                        _selectedCameraIndex = cameraIndex;
                                        _isCameraInitialized = true;
                                });
                        }
                } catch (e) {
                        debugPrint("Erro ao inicializar a câmera: $e");
                }
        }

        Future<void> _switchCamera() async {
                if (_cameras == null || _cameras!.length < 2) return;
                int novoIndice = (_selectedCameraIndex + 1) % _cameras!.length;
                setState(() => _isCameraInitialized = false);
                await _controller?.dispose();
                await _initializeCamera(novoIndice);
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
                        final XFile picture = await _controller!.takePicture();
                        File originalFile = File(picture.path);
                        File? croppedFile = await _processarRecorteOval(originalFile);

                        if (!mounted) return;
                        _avancarParaAnalise(croppedFile ?? originalFile);
                } catch (e) {
                        debugPrint("Erro ao capturar imagem: $e");
                } finally {
                        if (mounted) setState(() => _isCapturing = false);
                }
        }

        Future<void> _pickFromGallery() async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);

                if (pickedFile != null) {
                        File originalFile = File(pickedFile.path);
                        File? croppedFile = await _processarRecorteOval(originalFile);

                        if (!mounted) return;
                        _avancarParaAnalise(croppedFile ?? originalFile);
                }
        }

        // 🎯 RECORTE OTIMIZADO: Quadrado perfeito (1:1) para eliminar o achatamento
        Future<File?> _processarRecorteOval(File imagemOriginal) async {
                try {
                        final bytes = await imagemOriginal.readAsBytes();
                        final imagemDecodificada = img.decodeImage(bytes);
                        if (imagemDecodificada == null) return imagemOriginal;

                        int larguraImg = imagemDecodificada.width;
                        int alturaImg = imagemDecodificada.height;

                        // 1. Define o tamanho do corte como um QUADRADO PERFEITO (menor lado)
                        int tamanhoQuadrado = larguraImg < alturaImg ? larguraImg : alturaImg;

                        // 2. Centraliza no eixo X
                        int offsetX = (larguraImg - tamanhoQuadrado) ~/ 2;

                        // 3. Posiciona no eixo Y descendo o quadrado para pegar a parte inferior do rosto (boca)
                        // Adicionamos um deslocamento de 10% da altura para empurrar o corte para a base da foto
                        int offsetY = ((alturaImg - tamanhoQuadrado) ~/ 2) + (alturaImg * 0.10).toInt();

                        // Travas de segurança para não cortar fora da imagem
                        if (offsetX < 0) offsetX = 0;
                        if (offsetY < 0) offsetY = 0;
                        if (offsetX + tamanhoQuadrado > larguraImg) offsetX = larguraImg - tamanhoQuadrado;
                        if (offsetY + tamanhoQuadrado > alturaImg) offsetY = alturaImg - tamanhoQuadrado;

                        // 4. Faz o corte quadrado perfeito 1:1
                        img.Image imagemCropped = img.copyCrop(
                                imagemDecodificada,
                                x: offsetX,
                                y: offsetY,
                                width: tamanhoQuadrado,
                                height: tamanhoQuadrado,
                        );

                        // 5. Redimensiona para 512x512. Como a base já é quadrada, NÃO HÁ MAIS ACHATAMENTO!
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

        void _avancarParaAnalise(File imagemFinal) {
                final simulationId = _gerarSimulationId();
                final userEmail = _obterEmailUsuarioAtual();

                Navigator.pushNamed(
                        context,
                        '/analysis',
                        arguments: {
                                'image': imagemFinal.path,
                                'simulationId': simulationId,
                                'userEmail': userEmail,
                        },
                );
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
                                        Positioned.fill(
                                                child: CameraPreview(_controller!),
                                        ),
                                        Positioned.fill(
                                                child: CustomPaint(
                                                        painter: OvalOverlayPainter(),
                                                ),
                                        ),
                                        SafeArea(
                                                child: Column(
                                                        children: [
                                                                Padding(
                                                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                                        child: Row(
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                children: [
                                                                                        IconButton(
                                                                                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                                                                                onPressed: () => Navigator.pop(context),
                                                                                        ),
                                                                                        const Text(
                                                                                                'Enquadramento Facial',
                                                                                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                                                                        ),
                                                                                        const SizedBox(width: 48),
                                                                                ],
                                                                        ),
                                                                ),
                                                                const SizedBox(height: 8),
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
                                        Positioned(
                                                bottom: 40,
                                                left: 0,
                                                right: 0,
                                                child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                        children: [
                                                                FloatingActionButton(
                                                                        heroTag: 'btnGaleria',
                                                                        backgroundColor: Colors.blue[300],
                                                                        onPressed: _isCapturing ? null : _pickFromGallery,
                                                                        child: const Icon(Icons.photo_library, color: Colors.white),
                                                                ),
                                                                _isCapturing
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
                                                                FloatingActionButton(
                                                                        heroTag: 'btnSwitchCamera',
                                                                        backgroundColor: Colors.grey[800],
                                                                        onPressed: _isCapturing ? null : _switchCamera,
                                                                        child: const Icon(Icons.switch_camera, color: Colors.white),
                                                                ),
                                                        ],
                                                ),
                                        ),
                                ],
                        ),
                );
        }
}

class OvalOverlayPainter extends CustomPainter {
        @override
        void paint(Canvas canvas, Size size) {
                final paintBackground = Paint()
                        ..color = Colors.black.withOpacity(0.7)
                        ..style = PaintingStyle.fill;

                final rectTotal = Rect.fromLTWH(0, 0, size.width, size.height);

                // 🛠️ CORRIGIDO: Erro de sintaxe da proporção resolvido!
                final double ovalWidth = size.width * 0.72;
                final double ovalHeight = size.height * 0.48;

                final Rect ovalRect = Rect.fromCenter(
                        center: Offset(size.width / 2, (size.height / 2) - 20),
                        width: ovalWidth,
                        height: ovalHeight,
                );

                final Path pathBackground = Path()..addRect(rectTotal);
                final Path pathOval = Path()..addOval(ovalRect);

                final Path pathFinal = Path.combine(
                        PathOperation.difference,
                        pathBackground,
                        pathOval,
                );

                canvas.drawPath(pathFinal, paintBackground);

                final paintBorder = Paint()
                        ..color = Colors.amberAccent
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3.5;

                canvas.drawOval(ovalRect, paintBorder);
        }

        @override
        bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}