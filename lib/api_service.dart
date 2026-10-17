import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApiService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com';

  // 🔍 Verifica o saldo de créditos do dentista (Corrigido para POST)
  static Future<Map<String, dynamic>> checkCredits(String apiKey) async {
    try {
      final url = Uri.parse('$baseUrl/check-credits');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': apiKey}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Erro ao buscar créditos'};
      }
    } catch (e) {
      debugPrint("Erro na conexão para checar créditos: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // 💳 Adiciona créditos após a compra bem-sucedida
  static Future<bool> adicionarCreditos(String apiKey, int quantidade) async {
    try {
      final url = Uri.parse('$baseUrl/add-credits');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': apiKey, 'quantidade': quantidade}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint("Erro ao adicionar créditos: $e");
    }
    return false;
  }

  // 🪄 Envia a foto e parâmetros para o servidor gerar o novo sorriso
  static Future<String?> processSmile({
    required File imageFile,
    required String color,
    required String shape,
    required String size,
    String apiKey = 'dentista_demo_123', // Chave padrão de demonstração
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/process-smile');

      var request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['color'] = color
        ..fields['shape'] = shape
        ..fields['size'] = size
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      // Timeout de 60 segundos para aguardar o processamento da IA
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        debugPrint("Erro do servidor: ${response.statusCode}\n${response.body}");
      }
    } catch (e) {
      debugPrint("Erro no ApiService: $e");
    }
    return null;
  }
}