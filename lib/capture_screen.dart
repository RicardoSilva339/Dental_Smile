import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'background.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  File? _image;

  // 🛠️ Recorta a imagem de forma inteligente baseada na moldura central (Elimina o zoom da IA)
  Future<File?> _recortarParaMoldura(File imagemOriginal) async {
    try {
      final bytes = await imagemOriginal.readAsBytes();
      final imagemDecodificada = img.decodeImage(bytes);

      if (imagemDecodificada == null) return imagemOriginal;

      // Define um recorte quadrado centralizado (correspondente à moldura da UI)
      int menorLado = imagemDecodificada.width < imagemDecodificada.height
          ? imagemDecodificada.width
          : imagemDecodificada.height;

      int offsetX = (imagemDecodificada.width - menorLado) ~/ 2;
      int offsetY = (imagemDecodificada.height - menorLado) ~/ 2;

      // 1. Recorta exatamente o centro (onde fica a moldura do rosto)
      img.Image imagemCropped = img.copyCrop(
        imagemDecodificada,
        x: offsetX,
        y: offsetY,
        width: menorLado,
        height: menorLado,
      );

      // 2. Redimensiona para o padrão ideal da IA (512x512)
      img.Image imagemFinal = img.copyResize(
        imagemCropped,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      // Salva num ficheiro temporário padronizado
      final targetPath = '${imagemOriginal.path}_moldura.jpg';
      File arquivoFinal = File(targetPath)
        ..writeAsBytesSync(img.encodeJpg(imagemFinal, quality: 90));

      return arquivoFinal;
    } catch (e) {
      debugPrint("Erro ao recortar imagem para a moldura: $e");
      return imagemOriginal;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      File arquivoSelecionado = File(pickedFile.path);
      File? arquivoProcessado = await _recortarParaMoldura(arquivoSelecionado);

      setState(() {
        _image = arquivoProcessado ?? arquivoSelecionado;
      });
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

  void _goToAnalysis() {
    if (_image != null) {
      final simulationId = _gerarSimulationId();
      final userEmail = _obterEmailUsuarioAtual();

      Navigator.pushNamed(
        context,
        '/analysis',
        arguments: {
          'image': _image!.path,
          'simulationId': simulationId,
          'userEmail': userEmail,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ou capture uma imagem primeiro!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Simulação')),
      body: Background(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                'Posicione o Rosto na Moldura',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 💡 Dicas rápidas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Regras de Ouro:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Enquadre apenas o rosto dentro da área delimitada\n• Sorriso natural (dentes visíveis, boca fechada)\n• Boa iluminação frontal',
                      style: TextStyle(fontSize: 13),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 🖼️ Área de Pré-visualização com a Moldura Guia Estilo "Gov.br"
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Imagem selecionada ou espaço vazio
                    _image == null
                        ? Container(
                      height: 280,
                      width: 280,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'Nenhuma imagem selecionada\nToque em Câmera ou Galeria',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        _image!,
                        height: 280,
                        width: 280,
                        fit: BoxFit.cover,
                      ),
                    ),

                    // 🛑 Moldura Visual em Cima (Guia para o Utilizador)
                    IgnorePointer(
                      child: Container(
                        height: 260,
                        width: 260,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(130), // Formato oval/circular perfeito para o rosto
                          border: Border.all(
                            color: Colors.amberAccent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo),
                    label: const Text('Galeria'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[300],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 50),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Câmera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[300],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 50),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: const Text(
            'Seguir para Análise com IA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            backgroundColor: Colors.blue[400],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: _goToAnalysis,
        ),
      ),
    );
  }
}