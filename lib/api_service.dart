import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ApiService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com/processar';

  // Função auxiliar para redimensionar e comprimir a imagem
  static Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/temp_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (result == null) return null;
    return File(result.path);
  }

  // Função auxiliar para converter um Asset em File temporário para o upload
  static Future<File> _getAssetFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${assetPath.split('/').last}');
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file;
  }

  static Future<Uint8List?> processSmile(
      File imageFile, {
        required String color,
        required String shape,
        required String size,
      }) async {
    try {
      // 1. Comprime a imagem antes de enviar
      final File? compressedFile = await _compressImage(imageFile);
      final File fileToSend = compressedFile ?? imageFile;

      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // 2. Anexa o ficheiro principal (foto do paciente)
      request.files.add(
        await http.MultipartFile.fromPath('file', fileToSend.path),
      );

      // 3. Mapeia o formato (shape) escolhido para o asset PNG correspondente
      String assetPath = 'assets/images/dentes_arredondados.png';
      if (shape.toLowerCase().contains('quadrado')) {
        assetPath = 'assets/images/dentes_quadrados.png';
      }

      // 4. Carrega e anexa o molde PNG no campo 'overlay'
      final File overlayFile = await _getAssetFile(assetPath);
      request.files.add(
        await http.MultipartFile.fromPath('overlay', overlayFile.path),
      );

      // 5. Adiciona os parâmetros no formulário
      request.fields['color'] = color;
      request.fields['shape'] = shape;
      request.fields['size'] = size;

      // 6. Define timeout de 90 segundos para dar tempo do Render responder
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Erro no servidor (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro de conexão ou processamento: $e');
      return null;
    }
  }
}