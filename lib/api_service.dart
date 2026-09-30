import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚠️ ATENÇÃO: Ajuste a porta e o IP conforme seu ambiente de teste
  // Para Emulador Android: "http://10.0.2.2:5000"
  // Para Dispositivo Físico no Wi-Fi: "http://192.168.X.X:5000"
  static const String baseUrl = "http://10.0.2.2:5000";

  /// 1. Envia a foto para detectar a região dos dentes na tela de Análise (AnalysisScreen)
  static Future<Map<String, dynamic>?> detectSmileRegion(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['region']; // Ex: {"top": 100, "left": 50, ...}
      } else {
        return null;
      }
    } catch (e) {
      print("Erro ao detectar sorriso via API: $e");
      return null;
    }
  }

  /// 2. Envia a foto + todos os parâmetros de ajuste selecionados para gerar a nova foto do sorriso
  static Future<Uint8List?> processSmile(
      File imageFile, {
        required String color,
        required String shape,
        required String size,
        Map<String, dynamic>? region,
      }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/processar'),
      );

      // ✅ Envia o arquivo da foto
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      // ✅ Envia os parâmetros de ajuste para o Python saber como modificar os dentes
      request.fields['color'] = color;
      request.fields['shape'] = shape;
      request.fields['size'] = size;
      if (region != null) {
        request.fields['region'] = jsonEncode(region);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Retorna os bytes da imagem com o sorriso ajustado devolvida pelo Python
        return response.bodyBytes;
      } else {
        print("Erro do servidor (${response.statusCode}): ${response.body}");
        return null;
      }
    } on SocketException {
      throw Exception("Não foi possível conectar ao servidor backend ($baseUrl). Verifique se o servidor Python está rodando.");
    } catch (e) {
      throw Exception("Erro inesperado ao processar sorriso: $e");
    }
  }
}