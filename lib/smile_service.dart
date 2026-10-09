import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SmileService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com';

  /// Envia a foto e a cor selecionada para a API no Render
  static Future<File?> processSmile({
    required File imageFile,
    required String colorCode, // 'BL1', 'A1', 'A2', 'B1'
  }) async {
    // 1. Rota atualizada conforme chamada nos logs (/process-smile)
    final uri = Uri.parse('$baseUrl/process-smile');

    var request = http.MultipartRequest('POST', uri)
      ..fields['color'] = colorCode
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/processed_smile_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        debugPrint('Erro no servidor: ${response.statusCode}\n${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Erro ao comunicar com a API no Render: $e');
      return null;
    }
  }
}