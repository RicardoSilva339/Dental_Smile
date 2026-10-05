import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // Substitua pela URL exata do seu serviço no Render
  static const String baseUrl = 'https://seu-servidor.onrender.com';

  static Future<Uint8List?> processSmile(
      File imageFile, {
        required String color,
        required String shape,
        required String size,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/process-smile');
      var request = http.MultipartRequest('POST', uri);

      // Enviando a imagem
      request.files.add(
        await http.MultipartFile.fromPath('photo', imageFile.path),
      );

      // Enviando os parâmetros selecionados
      request.fields['color'] = color;
      request.fields['shape'] = shape;
      request.fields['size'] = size;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Retorna os bytes da imagem final renderizada pelo servidor
        return response.bodyBytes;
      } else {
        print('Erro no servidor: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao comunicar com a API: $e');
      rethrow;
    }
  }
}