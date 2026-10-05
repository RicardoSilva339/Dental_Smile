import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SmileService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com';

  /// Envia a foto e a cor selecionada para a API no Render
  static Future<File?> processSmile({
    required File imageFile,
    required String colorCode, // 'BL1', 'A1', 'A2', 'B1'
  }) async {
    final uri = Uri.parse('$baseUrl/processar');

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
        print('Erro no servidor: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao comunicar com a API no Render: $e');
      return null;
    }
  }
}