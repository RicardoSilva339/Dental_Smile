import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // URL do backend em produção no Render
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com/processar';

  static Future<Uint8List?> processSmile(
      File imageFile, {
        required String color,
        required String shape,
        required String size,
      }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Envia o ficheiro da imagem na chave 'file'
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Envia os campos adicionais exigidos pelo server.py
      request.fields['color'] = color;
      request.fields['shape'] = shape;
      request.fields['size'] = size;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Retorna os bytes da imagem (Uint8List) esperados pelo writeAsBytes
        return response.bodyBytes;
      } else {
        print('Erro no servidor (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao comunicar com o backend: $e');
      return null;
    }
  }
}