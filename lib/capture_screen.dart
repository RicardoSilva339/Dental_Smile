import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img; // 👈 Certifica-te de que tens este pacote no pubspec.yaml
import 'background.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  File? _image;

  // 🛠️ Padroniza, aplica zoom inteligente focado no rosto (eliminando ombros) e redimensiona (512x512)
  Future<File?> _padronizarImagem(File imagemOriginal) async {
    try {
      final bytes = await imagemOriginal.readAsBytes();
      final imagemDecodificada = img.decodeImage(bytes);

      if (imagemDecodificada == null) return imagemOriginal;

      int larguraOriginal = imagemDecodificada.width;
      int alturaOriginal = imagemDecodificada.height;

      // Define o tamanho do quadrado de corte (cobre o rosto e boca com boa margem)
      int tamanhoCorte = (larguraOriginal < alturaOriginal ? larguraOriginal : alturaOriginal) ~/ 1.3;

      // Centraliza horizontalmente
      int offsetX = (larguraOriginal - tamanhoCorte) ~/ 2;

      // Posiciona o corte verticalmente mais acima (15% a partir do topo), focando no rosto e cortando os ombros
      int offsetY = (alturaOriginal * 0.15).toInt();
      if (offsetY + tamanhoCorte > alturaOriginal) {
        offsetY = alturaOriginal - tamanhoCorte;
      }
      if (offsetY < 0) offsetY = 0;

      // Executa o corte inteligente focado na região superior/rosto
      img.Image imagemQuadrada = img.copyCrop(
          imagemDecodificada,
          x: offsetX,
          y: offsetY,
          width: tamanhoCorte,
          height: tamanhoCorte
      );

      // Redimensiona para o padrão exato de 512x512 exigido pela IA
      img.Image imagemFinal = img.copyResize(
          imagemQuadrada,
          width: 512,
          height: 512,
          interpolation: img.Interpolation.linear
      );

      // Salva num novo ficheiro temporário padronizado
      final targetPath = '${imagemOriginal.path}_padded_rosto.jpg';
      File arquivoFinal = File(targetPath)
        ..writeAsBytesSync(img.encodeJpg(imagemFinal, quality: 95));

      return arquivoFinal;
    } catch (e) {
      debugPrint("Erro ao padronizar imagem na origem: $e");
      return imagemOriginal;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      File arquivoSelecionado = File(pickedFile.path);
      File? arquivoPadronizado = await _padronizarImagem(arquivoSelecionado);

      setState(() => _image = arquivoPadronizado ?? arquivoSelecionado);
    }
  }

  String _gerarSimulationId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(5);
    return 'DS-$timestamp';
  }

  // 🔍 E-mail do utilizador logado no momento da captura
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                'Capturar Foto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enquadre o sorriso ou selecione uma foto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

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
              const SizedBox(height: 30),

              Expanded(
                child: Center(
                  child: _image == null
                      ? const Text('Nenhuma imagem selecionada')
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_image!, height: 300, fit: BoxFit.cover),
                  ),
                ),
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