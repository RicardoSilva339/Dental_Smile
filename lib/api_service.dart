import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApiService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com';

  static Future<String?> processSmile({
    required File imageFile,
    required String color,
    required String shape,
    required String size,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/process-smile');

      var request = http.MultipartRequest('POST', uri)
        ..fields['color'] = color
        ..fields['shape'] = shape
        ..fields['size'] = size
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      // Aumentado para 60 segundos para dar tempo à IA de gerar a imagem sem timeout
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        // Salvando com extensão .jpg para corresponder ao mimetype image/jpeg enviado pelo servidor
        final file = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        debugPrint("Erro do servidor: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Erro no ApiService: $e");
    }
    return null;
  }
}