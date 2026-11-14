import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class _ProcessResult {
        final File file;
        _ProcessResult({required this.file});
}

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

        // 🤖 Detector Facial via Google ML Kit com Landmarks ativados
        final FaceDetector _faceDetector = FaceDetector(
                options: FaceDetectorOptions(
                        enableLandmarks: true,
                        performanceMode: FaceDetectorMode.accurate,
                ),
        );

        @override
        void initState() {
                super.initState();
                _initializeCamera(_selectedCameraIndex);

                // Exibe as instruções de captura automaticamente na primeira abertura da tela
                WidgetsBinding.instance.addPostFrameCallback((_) {
                        _exibirInstrucoesCaptura(context);
                });
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
                _faceDetector.close();
                super.dispose();
        }

        // 💡 Diálogo explicativo com o padrão ideal de foto (Estilo Lubrite Dental)
        void _exibirInstrucoesCaptura(BuildContext context, {VoidCallback? onContinuar}) {
                showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Row(
                                        children: [
                                                Icon(Icons.info_outline, color: Color(0xFF5C6BC0), size: 28),
                                                SizedBox(width: 10),
                                                Expanded(
                                                        child: Text(
                                                                'Padrão Ideal para a Foto',
                                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                                        ),
                                                ),
                                        ],
                                ),
                                content: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                                Text(
                                                        'Para garantir uma simulação perfeita com a Inteligência Artificial, siga estas orientações:',
                                                        style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                                                ),
                                                SizedBox(height: 12),
                                                Text('• Sorriso natural (dentes visíveis / ocluídos)[cite: 2]', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                SizedBox(height: 4),
                                                Text('• Boa iluminação e ângulo frontal[cite: 2]', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                SizedBox(height: 4),
                                                Text('• Evite bocas entreabertas ou lábios cobrindo os dentes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                ),
                                actions: [
                                        ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF5C6BC0),
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                onPressed: () {
                                                        Navigator.pop(ctx);
                                                        if (onContinuar != null) onContinuar();
                                                },
                                                child: const Text('Entendido, Vamos lá', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                ],
                        ),
                );
        }

        Future<void> _captureAndCrop() async {
                if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

                setState(() => _isCapturing = true);

                try {
                        final XFile picture = await _controller!.takePicture();
                        File originalFile = File(picture.path);

                        _ProcessResult? resultado = await _processarRecorteInteligente(originalFile);

                        if (resultado == null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                                content: Text("Rosto ou sorriso não detectado. Centralize o rosto e tente novamente."),
                                                backgroundColor: Colors.redAccent,
                                        ),
                                );
                                return;
                        }

                        if (!mounted) return;
                        _avancarParaAnalise(resultado.file);
                } catch (e) {
                        debugPrint("Erro ao capturar imagem: $e");
                } finally {
                        if (mounted) setState(() => _isCapturing = false);
                }
        }

        Future<void> _pickFromGallery() async {
                // Antes de abrir a galeria, exibe as orientações para o médico selecionar uma foto adequada
                _exibirInstrucoesCaptura(context, onContinuar: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);

                        if (pickedFile != null) {
                                setState(() => _isCapturing = true);
                                try {
                                        File originalFile = File(pickedFile.path);
                                        _ProcessResult? resultado = await _processarRecorteInteligente(originalFile);

                                        if (resultado == null) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                                content: Text("Não foi possível identificar o rosto/sorriso na foto selecionada."),
                                                                backgroundColor: Colors.redAccent,
                                                        ),
                                                );
                                                return;
                                        }

                                        if (!mounted) return;
                                        _avancarParaAnalise(resultado.file);
                                } finally {
                                        if (mounted) setState(() => _isCapturing = false);
                                }
                        }
                });
        }

        // 🧠 DETECÇÃO E RECORTE DINÂMICO VIA GOOGLE ML KIT
        Future<_ProcessResult?> _processarRecorteInteligente(File imagemOriginal) async {
                try {
                        final inputImage = InputImage.fromFile(imagemOriginal);
                        final List<Face> faces = await _faceDetector.processImage(inputImage);

                        if (faces.isEmpty) {
                                debugPrint("ML Kit: Nenhum rosto encontrado.");
                                return null;
                        }

                        final Face face = faces.first;
                        final bytes = await imagemOriginal.readAsBytes();
                        final img.Image? imagemDecodificada = img.decodeImage(bytes);
                        if (imagemDecodificada == null) return null;

                        int larguraImg = imagemDecodificada.width;
                        int alturaImg = imagemDecodificada.height;

                        final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
                        final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
                        final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

                        int centroX;
                        int centroY;

                        if (leftMouth != null && rightMouth != null && bottomMouth != null) {
                                // Ponto central exato da boca
                                centroX = ((leftMouth.x + rightMouth.x) / 2).toInt();
                                centroY = ((leftMouth.y + bottomMouth.y) / 2).toInt();
                        } else {
                                // Fallback: Centro estimado pela bounding box do rosto
                                final boundingBox = face.boundingBox;
                                centroX = boundingBox.center.dx.toInt();
                                centroY = (boundingBox.top + (boundingBox.height * 0.70)).toInt();
                        }

                        // Define o tamanho do quadrado delimitador proporcional ao rosto
                        int tamanhoQuadrado = (face.boundingBox.height * 0.85).toInt();

                        if (tamanhoQuadrado > larguraImg) tamanhoQuadrado = larguraImg;
                        if (tamanhoQuadrado > alturaImg) tamanhoQuadrado = alturaImg;

                        int offsetX = centroX - (tamanhoQuadrado ~/ 2);
                        int offsetY = centroY - (tamanhoQuadrado ~/ 2);

                        // Trava os limites para evitar estouro fora da imagem
                        if (offsetX < 0) offsetX = 0;
                        if (offsetY < 0) offsetY = 0;
                        if (offsetX + tamanhoQuadrado > larguraImg) offsetX = larguraImg - tamanhoQuadrado;
                        if (offsetY + tamanhoQuadrado > alturaImg) offsetY = alturaImg - tamanhoQuadrado;

                        // 1. Corte 1:1 quadrado focado dinamicamente na boca
                        img.Image imagemCropped = img.copyCrop(
                                imagemDecodificada,
                                x: offsetX,
                                y: offsetY,
                                width: tamanhoQuadrado,
                                height: tamanhoQuadrado,
                        );

                        // 2. Padronização 512x512
                        img.Image imagemFinal = img.copyResize(
                                imagemCropped,
                                width: 512,
                                height: 512,
                                interpolation: img.Interpolation.linear,
                        );

                        final targetPath = '${imagemOriginal.path}_mlkit_smile.jpg';
                        File arquivoFinal = File(targetPath)
                                ..writeAsBytesSync(img.encodeJpg(imagemFinal, quality: 90));

                        return _ProcessResult(file: arquivoFinal);
                } catch (e) {
                        debugPrint("Erro no processamento do ML Kit: $e");
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
                        backgroundColor: Colors.black,
                        body: Stack(
                                children: [
                                        Positioned.fill(
                                                child: CameraPreview(_controller!),
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
                                                                                                'Simulação de Sorriso',
                                                                                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                                                                        ),
                                                                                        // Botão de ajuda para reabrir as instruções de captura a qualquer momento
                                                                                        IconButton(
                                                                                                icon: const Icon(Icons.help_outline, color: Colors.white),
                                                                                                tooltip: 'Dicas de Captura',
                                                                                                onPressed: () => _exibirInstrucoesCaptura(context),
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                ),
                                                                const SizedBox(height: 12),
                                                                Container(
                                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                                        decoration: BoxDecoration(
                                                                                color: Colors.black.withOpacity(0.65),
                                                                                borderRadius: BorderRadius.circular(20),
                                                                        ),
                                                                        child: const Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                        Icon(Icons.face_retouching_natural, color: Colors.amberAccent, size: 18),
                                                                                        SizedBox(width: 8),
                                                                                        Text(
                                                                                                'Enquadre o rosto e tire a foto',
                                                                                                style: TextStyle(
                                                                                                        color: Colors.white,
                                                                                                        fontSize: 13,
                                                                                                        fontWeight: FontWeight.bold,
                                                                                                ),
                                                                                        ),
                                                                                ],
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