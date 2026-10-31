import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  static const String baseUrl = 'https://dental-smile-backend-iso3.onrender.com';

  // 📱 Obtém o ID único do dispositivo físico (Anti-Reinstalação)
  static Future<String> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id.isNotEmpty ? androidInfo.id : (androidInfo.device ?? 'android_device');
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (e) {
      debugPrint("Erro ao obter Device ID: $e");
    }
    return 'unknown_device';
  }

  // 🛡️ Verifica ou registra o dispositivo no servidor (Garante os 3 créditos de cortesia por aparelho)
  static Future<dynamic> checkOrRegisterDevice() async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/check-device');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data; // Retorna o map completo {'success': true, 'creditos': X, 'novo': bool}
        }
      }
    } catch (e) {
      debugPrint("Erro ao verificar dispositivo: $e");
    }
    return {'success': false, 'creditos': 3, 'novo': false}; // Fallback de segurança
  }

  // 📝 Registo de novo utilizador com senha
  static Future> register({
    required String nome,
    required String email,
    required String cro,
    required String senha,
  }) async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/register');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'email': email,
          'cro': cro,
          'senha': senha,
          'device_id': deviceId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro no registo: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🔑 Login do utilizador
  static Future> login({
    required String email,
    required String senha,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'senha': senha,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro no login: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🔍 Verifica o saldo de créditos do dentista
  static Future> checkCredits(String apiKey) async {
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

  // 🪄 Envia a foto em Base64 para o servidor gerar o sorriso e retorna ambas padronizadas 512x512
  static Future> processSmile({
    required File imageFile,
    required String color,
    required String shape,
    required String size,
    required String apiKey,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/process-smile');

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      String deviceId = await _getDeviceId();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'device_id': deviceId,
          'image': base64Image,
          'color': color,
          'shape': shape,
          'size': size,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {

          // 1️⃣ Decodifica a imagem tratada pela IA ("Com IA")
          String processedBase64 = data['processed_image'];
          Uint8List decodedBytes = base64Decode(processedBase64);
          final tempDir = await getTemporaryDirectory();
          final fileProcessed = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await fileProcessed.writeAsBytes(decodedBytes);

          // 2️⃣ Decodifica a imagem original padronizada pelo servidor ("Original")
          String originalBase64 = data['original_image'];
          Uint8List decodedOriginalBytes = base64Decode(originalBase64);
          final fileOriginal = File('${tempDir.path}/original_padded_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await fileOriginal.writeAsBytes(decodedOriginalBytes);

          return {
            'success': true,
            'imagePath': fileProcessed.path,          // Caminho da foto com IA (512x512)
            'originalImagePath': fileOriginal.path,   // Caminho da foto original padronizada (512x512)
            'creditos_restantes': data['creditos_restantes'],
          };
        } else {
          return {'success': false, 'error': data['error'] ?? 'Erro desconhecido no servidor'};
        }
      } else {
        debugPrint("Erro do servidor: ${response.statusCode}\n${response.body}");
        return {'success': false, 'error': 'Erro no servidor (${response.statusCode})'};
      }
    } catch (e) {
      debugPrint("Erro no ApiService (processSmile): $e");

      String mensagemErro = e.toString();
      if (mensagemErro.contains('Connection reset by peer') || mensagemErro.contains('SocketException')) {
        mensagemErro = 'A conexão com o servidor foi interrompida durante o download da imagem. Verifique sua internet e tente novamente.';
      } else if (mensagemErro.contains('TimeoutException')) {
        mensagemErro = 'O tempo limite de processamento foi atingido. A IA na nuvem demorou a responder.';
      }

      return {'success': false, 'error': mensagemErro};
    }
  }
}