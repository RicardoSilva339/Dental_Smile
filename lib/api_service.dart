import 'dart:io';
import 'dart:typed_data';
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

      // 2. Anexa o ficheiro comprimido
      request.files.add(
        await http.MultipartFile.fromPath('file', fileToSend.path),
      );

      request.fields['color'] = color;
      request.fields['shape'] = shape;
      request.fields['size'] = size;

      // 3. Define timeout de 90 segundos para dar tempo de resposta do Render
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