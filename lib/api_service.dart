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

  // 👤 Atualiza o perfil profissional e dados cadastrais no PostgreSQL (Render)
  static Future<bool> updateProfile(String apiKey, String nome, String email, String cro) async {
    try {
      final url = Uri.parse('$baseUrl/update-profile');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'nome': nome,
          'email': email,
          'cro': cro,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint("Erro ao atualizar perfil no servidor: $e");
    }
    return false;
  }

  // 🪄 Envia a foto em Base64 para o servidor gerar o sorriso e descontar o crédito
  static Future<Map<String, dynamic>> processSmile({
    required File imageFile,
    required String color,
    required String shape,
    required String size,
    String apiKey = 'dentista_demo_123',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/process-smile');

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      String customPrompt = 'perfect white smile, color $color, shape $shape, size $size, professional cosmetic dentistry, highly detailed';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'image': base64Image,
          'prompt': customPrompt,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          String processedBase64 = data['processed_image'];
          Uint8List decodedBytes = base64Decode(processedBase64);

          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(decodedBytes);

          return {
            'success': true,
            'imagePath': file.path,
            'creditos_restantes': data['creditos_restantes'],
          };
        }
      } else {
        debugPrint("Erro do servidor: ${response.statusCode}\n${response.body}");
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? 'Erro desconhecido'};
      }
    } catch (e) {
      debugPrint("Erro no ApiService: $e");
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Falha na comunicação com o servidor'};
  }
}