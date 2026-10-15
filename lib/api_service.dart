import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApiService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com';

  // 🔍 Verifica o saldo de créditos do dentista
  static Future<Map<String, dynamic>> checkCredits(String apiKey) async {
    try {
      final url = Uri.parse('$baseUrl/check-credits?api_key=$apiKey');
      final response = await http.get(url);

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
        ..fields['api_key'] = apiKey // Envia a chave para o servidor descontar o crédito
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