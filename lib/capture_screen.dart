import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class _ProcessResult {
        final File file;
        final String? erro;
        _ProcessResult({required this.file, this.erro});
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

        static const String _kHideCaptureInstructionsKey =
            'ocultar_instrucoes_captura';

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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                        _exibirInstrucoesCapturaSeNecessario(context);
                });
        }

        Future<void> _exibirInstrucoesCapturaSeNecessario(
            BuildContext context, {
                    bool forcarExibicao = false,
            }) async {
                if (!forcarExibicao) {
                        final boxUser = Hive.box('box_usuario');
                        final bool ocultar =
                        (boxUser.get(_kHideCaptureInstructionsKey, defaultValue: false)
                        as bool);
                        if (ocultar || !mounted) return;
                }

                if (!mounted) return;
                _exibirInstrucoesCaptura(context);
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

        void _exibirInstrucoesCaptura(BuildContext context) {
                showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) {
                                return _ModalInstrucoesLeitura(
                                        hideKey: _kHideCaptureInstructionsKey,
                                        onConfirm: () => Navigator.pop(ctx),
                                );
                        },
                );
        }

        Future<void> _captureAndCrop() async {
                if (_controller == null ||
                    !_controller!.value.isInitialized ||
                    _isCapturing) {
                        return;
                }

                setState(() => _isCapturing = true);

                try {
                        final XFile picture = await _controller!.takePicture();
                        File originalFile = File(picture.path);

                        _ProcessResult resultado =
                        await _processarRecorteInteligente(originalFile);

                        if (resultado.erro != null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                                content: Text(resultado.erro!),
                                                backgroundColor: Colors.redAccent,
                                        ),
                                );
                                return;
                        }

                        if (!mounted) return;
                        await _avancarParaAnalise(resultado.file);
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
                        setState(() => _isCapturing = true);
                        try {
                                File originalFile = File(pickedFile.path);
                                _ProcessResult resultado =
                                await _processarRecorteInteligente(originalFile);

                                if (resultado.erro != null) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                        content: Text(resultado.erro!),
                                                        backgroundColor: Colors.redAccent,
                                                ),
                                        );
                                        return;
                                }

                                if (!mounted) return;
                                await _avancarParaAnalise(resultado.file);
                        } finally {
                                if (mounted) setState(() => _isCapturing = false);
                        }
                }
        }

        Future<_ProcessResult> _processarRecorteInteligente(
            File imagemOriginal,
            ) async {
                try {
                        final inputImage = InputImage.fromFile(imagemOriginal);
                        final List<Face> faces = await _faceDetector.processImage(inputImage);

                        if (faces.isEmpty) {
                                return _ProcessResult(
                                        file: imagemOriginal,
                                        erro:
                                        "Rosto não detectado. Mantenha 40 a 60 cm de distância enquadrando o rosto inteiro.",
                                );
                        }

                        if (faces.length > 1) {
                                return _ProcessResult(
                                        file: imagemOriginal,
                                        erro:
                                        "Mais de um rosto detectado. Fotografe apenas o paciente sozinho no enquadramento.",
                                );
                        }

                        final Face face = faces.first;
                        final bytes = await imagemOriginal.readAsBytes();
                        final img.Image? imagemDecodificada = img.decodeImage(bytes);
                        if (imagemDecodificada == null) {
                                return _ProcessResult(
                                        file: imagemOriginal,
                                        erro: "Falha ao ler a imagem.",
                                );
                        }

                        int larguraImg = imagemDecodificada.width;
                        int alturaImg = imagemDecodificada.height;

                        final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
                        final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
                        final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

                        int centroX;
                        int centroY;

                        if (leftMouth != null && rightMouth != null && bottomMouth != null) {
                                centroX = ((leftMouth.x + rightMouth.x) / 2).toInt();
                                centroY = ((leftMouth.y + bottomMouth.y) / 2).toInt();
                        } else {
                                final boundingBox = face.boundingBox;
                                centroX = boundingBox.center.dx.toInt();
                                centroY = (boundingBox.top + (boundingBox.height * 0.70)).toInt();
                        }

                        int tamanhoQuadrado = (face.boundingBox.height * 0.85).toInt();

                        if (tamanhoQuadrado > larguraImg) tamanhoQuadrado = larguraImg;
                        if (tamanhoQuadrado > alturaImg) tamanhoQuadrado = alturaImg;

                        int offsetX = centroX - (tamanhoQuadrado ~/ 2);
                        int offsetY = centroY - (tamanhoQuadrado ~/ 2);

                        if (offsetX < 0) offsetX = 0;
                        if (offsetY < 0) offsetY = 0;
                        if (offsetX + tamanhoQuadrado > larguraImg) {
                                offsetX = larguraImg - tamanhoQuadrado;
                        }
                        if (offsetY + tamanhoQuadrado > alturaImg) {
                                offsetY = alturaImg - tamanhoQuadrado;
                        }

                        img.Image imagemCropped = img.copyCrop(
                                imagemDecodificada,
                                x: offsetX,
                                y: offsetY,
                                width: tamanhoQuadrado,
                                height: tamanhoQuadrado,
                        );

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
                        return _ProcessResult(
                                file: imagemOriginal,
                                erro: "Erro ao processar o enquadramento da foto.",
                        );
                }
        }

        Future<void> _avancarParaAnalise(File imagemFinal) async {
                final userEmail = _obterEmailUsuarioAtual();

                if (!mounted) return;
                Navigator.pushNamed(
                        context,
                        '/analysis',
                        arguments: {
                                'image': imagemFinal.path,
                                'userEmail': userEmail,
                        },
                );
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
                                                                                                style: TextStyle(
                                                                                                        color: Colors.white,
                                                                                                        fontSize: 18,
                                                                                                        fontWeight: FontWeight.bold,
                                                                                                ),
                                                                                        ),
                                                                                        IconButton(
                                                                                                icon: const Icon(Icons.help_outline, color: Colors.white),
                                                                                                tooltip: 'Dicas de Captura',
                                                                                                onPressed: () => _exibirInstrucoesCapturaSeNecessario(
                                                                                                        context,
                                                                                                        forcarExibicao: true,
                                                                                                ),
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                ),
                                                                const SizedBox(height: 12),
                                                                Container(
                                                                        padding:
                                                                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                                        decoration: BoxDecoration(
                                                                                color: Colors.black.withOpacity(0.65),
                                                                                borderRadius: BorderRadius.circular(20),
                                                                        ),
                                                                        child: const Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                        Icon(
                                                                                                Icons.face_retouching_natural,
                                                                                                color: Colors.amberAccent,
                                                                                                size: 17,
                                                                                        ),
                                                                                        SizedBox(width: 7),
                                                                                        Text(
                                                                                                '40–60 cm • Enquadre o rosto inteiro',
                                                                                                style: TextStyle(
                                                                                                        color: Colors.white,
                                                                                                        fontSize: 12.5,
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

class _ModalInstrucoesLeitura extends StatefulWidget {
        final String hideKey;
        final VoidCallback onConfirm;

        const _ModalInstrucoesLeitura({
                required this.hideKey,
                required this.onConfirm,
        });

        @override
        State<_ModalInstrucoesLeitura> createState() =>
            _ModalInstrucoesLeituraState();
}

class _ModalInstrucoesLeituraState extends State<_ModalInstrucoesLeitura>
    with SingleTickerProviderStateMixin {
        late final AnimationController _blinkController;
        late final Animation<double> _blinkOpacity;
        bool _naoMostrarNovamente = false;

        @override
        void initState() {
                super.initState();
                final boxUser = Hive.box('box_usuario');
                _naoMostrarNovamente =
                (boxUser.get(widget.hideKey, defaultValue: false) as bool);

                _blinkController = AnimationController(
                        vsync: this,
                        duration: const Duration(milliseconds: 600),
                )..repeat(reverse: true);

                _blinkOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
                        CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
                );
        }

        @override
        void dispose() {
                _blinkController.dispose();
                super.dispose();
        }

        Future<void> _alternarNaoMostrar(bool valor) async {
                setState(() => _naoMostrarNovamente = valor);
                final boxUser = Hive.box('box_usuario');
                await boxUser.put(widget.hideKey, valor);
        }

        @override
        Widget build(BuildContext context) {
                return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                        FadeTransition(
                                                opacity: _blinkOpacity,
                                                child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                                color: Colors.red.withOpacity(0.12),
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(color: Colors.red, width: 1.2),
                                                        ),
                                                        child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                        Icon(
                                                                                Icons.priority_high_rounded,
                                                                                color: Colors.red,
                                                                                size: 20,
                                                                        ),
                                                                        SizedBox(width: 4),
                                                                        Text(
                                                                                'LEIA COM ATENÇÃO!',
                                                                                style: TextStyle(
                                                                                        color: Colors.red,
                                                                                        fontWeight: FontWeight.w900,
                                                                                        fontSize: 14,
                                                                                        letterSpacing: 0.6,
                                                                                ),
                                                                        ),
                                                                ],
                                                        ),
                                                ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Row(
                                                children: [
                                                        Icon(
                                                                Icons.camera_enhance_rounded,
                                                                color: Color(0xFF5C6BC0),
                                                                size: 22,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                                child: Text(
                                                                        'Padrão Ideal da Foto',
                                                                        style: TextStyle(
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 17,
                                                                        ),
                                                                ),
                                                        ),
                                                ],
                                        ),
                                ],
                        ),
                        content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                        const _ItemDicaCompacta(
                                                icone: Icons.straighten,
                                                texto:
                                                'Distância de 40 a 60 cm para pegar o rosto inteiro (perto demais gera erro na simulação)',
                                        ),
                                        const SizedBox(height: 9),
                                        const _ItemDicaCompacta(
                                                icone: Icons.sentiment_satisfied_alt,
                                                texto:
                                                'Sorriso mostrando bem os dentes, com os dentes superiores e inferiores levemente encostados/alinhados (evite lábios fechados ou cobrindo os dentes)',
                                        ),
                                        const SizedBox(height: 9),
                                        const _ItemDicaCompacta(
                                                icone: Icons.person_outline,
                                                texto:
                                                'Apenas o paciente na foto, com boa iluminação e sem cortes no rosto',
                                        ),
                                        const SizedBox(height: 10),
                                        InkWell(
                                                onTap: () => _alternarNaoMostrar(!_naoMostrarNovamente),
                                                child: Row(
                                                        children: [
                                                                Checkbox(
                                                                        value: _naoMostrarNovamente,
                                                                        activeColor: const Color(0xFF5C6BC0),
                                                                        visualDensity: VisualDensity.compact,
                                                                        onChanged: (val) => _alternarNaoMostrar(val ?? false),
                                                                ),
                                                                const Expanded(
                                                                        child: Text(
                                                                                'Não mostrar novamente',
                                                                                style: TextStyle(
                                                                                        fontSize: 12.5,
                                                                                        fontWeight: FontWeight.w600,
                                                                                        color: Colors.black87,
                                                                                ),
                                                                        ),
                                                                ),
                                                        ],
                                                ),
                                        ),
                                ],
                        ),
                        actions: [
                                SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF5C6BC0),
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                                        shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                        ),
                                                ),
                                                onPressed: widget.onConfirm,
                                                child: const Text(
                                                        'Entendido',
                                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                        ),
                                ),
                        ],
                );
        }
}

class _ItemDicaCompacta extends StatelessWidget {
        final IconData icone;
        final String texto;

        const _ItemDicaCompacta({required this.icone, required this.texto});

        @override
        Widget build(BuildContext context) {
                return Row(
                        children: [
                                Icon(icone, size: 18, color: const Color(0xFF5C6BC0)),
                                const SizedBox(width: 8),
                                Expanded(
                                        child: Text(
                                                texto,
                                                style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.black87,
                                                ),
                                        ),
                                ),
                        ],
                );
        }
}