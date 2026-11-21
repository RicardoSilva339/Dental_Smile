import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  // 🌐 Domínio oficial próprio com SSL configurado
  static const String baseUrl = 'https://dentalsmile.ia.br';

  // 🔑 Public Key de Teste do Mercado Pago[cite: 6]
  // (Depois de validar o cartão, voltar para Produção: 'APP_USR-bcce465a-85ea-4174-95e5-d6c6fcae721f'[cite: 2])
  static const String mpPublicKey = 'APP_USR-bcce465a-85ea-4174-95e5-d6c6fcae721f';

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

  static Future<dynamic> checkOrRegisterDevice() async {
    return {'success': true, 'creditos': 0, 'novo': false};
  }

  // 1. Cadastro
  static Future<dynamic> register({
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
      debugPrint("Erro no registro: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  // 2. Validação OTP
  static Future<dynamic> verifyEmail({
    required String email,
    required String codigo,
  }) async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/verify-email');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'codigo': codigo,
          'device_id': deviceId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao verificar e-mail: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  // 3. Login
  static Future<dynamic> login({
    required String email,
    required String senha,
  }) async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'senha': senha,
          'device_id': deviceId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro no login: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  // 4. Esqueci minha senha
  static Future<dynamic> forgotPassword({required String email}) async {
    try {
      final url = Uri.parse('$baseUrl/forgot-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao solicitar recuperação de senha: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  // 5. Redefinir senha
  static Future<dynamic> resetPassword({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/reset-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'codigo': codigo,
          'nova_senha': novaSenha,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao redefinir senha: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  // 6. Desconectar outros aparelhos
  static Future<dynamic> resetDevices({required String email}) async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/reset-devices');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'device_id': deviceId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao desconectar aparelhos: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  static Future<dynamic> checkCredits(String apiKey) async {
    if (apiKey.isEmpty) {
      return {'success': true, 'creditos': 0, 'limite_dispositivos': 1};
    }

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

  // 💳 7. Criar Pagamento Pix via Mercado Pago
  static Future<dynamic> criarPagamentoPix({
    required String apiKey,
    required String pacote,
  }) async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/criar-pagamento');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'pacote': pacote,
          'device_id': deviceId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao criar pagamento Pix: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor: $e'};
    }
  }

  // 💳 8. Simular Parcelas do Cartão (1x a 10x com repasse transparente)
  static Future<dynamic> simularParcelasCartao({
    required String pacote,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/simular-parcelas-cartao');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pacote': pacote}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao simular parcelas do cartão: $e");
      return {'success': false, 'error': 'Falha ao consultar parcelas: $e'};
    }
  }

  // Identifica a bandeira básica pelo número do cartão
  static String detectarBandeiraCartao(String numeroLimpo) {
    if (numeroLimpo.startsWith('4')) return 'visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(numeroLimpo)) return 'master';
    if (RegExp(r'^(34|37)').hasMatch(numeroLimpo)) return 'amex';
    if (RegExp(r'^(4011|4312|4389|4514|4576|5041|5066|5067|509|6277|6362|6363|650|6516|6550)').hasMatch(numeroLimpo)) {
      return 'elo';
    }
    if (RegExp(r'^(606282|3841)').hasMatch(numeroLimpo)) return 'hipercard';
    return 'visa';
  }

  // 🔒 9. Tokeniza os dados do cartão direto no servidor oficial do Mercado Pago
  static Future<dynamic> gerarTokenCartaoMp({
    required String cardNumber,
    required String cardholderName,
    required int expirationMonth,
    required int expirationYear,
    required String securityCode,
    required String cpfTitular,
  }) async {
    try {
      final numeroLimpo = cardNumber.replaceAll(RegExp(r'\D'), '');
      final cpfLimpo = cpfTitular.replaceAll(RegExp(r'\D'), '');
      final anoCompleto = expirationYear < 100 ? 2000 + expirationYear : expirationYear;

      final url = Uri.parse('https://api.mercadopago.com/v1/card_tokens?public_key=$mpPublicKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'card_number': numeroLimpo,
          'security_code': securityCode.trim(),
          'expiration_month': expirationMonth,
          'expiration_year': anoCompleto,
          'cardholder': {
            'name': cardholderName.trim().toUpperCase(),
            'identification': {
              'type': 'CPF',
              'number': cpfLimpo,
            }
          }
        }),
      );

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['id'] != null) {
        return {
          'success': true,
          'card_token': data['id'],
          'payment_method_id': detectarBandeiraCartao(numeroLimpo),
        };
      } else {
        String erroMsg = 'Dados do cartão inválidos. Verifique número, validade e CVV.';
        if (data is Map && data['cause'] is List && (data['cause'] as List).isNotEmpty) {
          erroMsg = data['cause'][0]['description'] ?? erroMsg;
        }
        return {'success': false, 'error': erroMsg};
      }
    } catch (e) {
      debugPrint("Erro ao tokenizar cartão no Mercado Pago: $e");
      return {'success': false, 'error': 'Falha ao validar cartão junto ao Mercado Pago: $e'};
    }
  }

  // 💳 10. Criar Pagamento com Cartão de Crédito via Orders API v1
  static Future<dynamic> criarPagamentoCartao({
    required String apiKey,
    required String pacote,
    required String cardToken,
    required String paymentMethodId,
    required int installments,
    required String cpf,
  }) async {
    try {
      final String deviceId = await _getDeviceId();
      final url = Uri.parse('$baseUrl/criar-pagamento-cartao');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'pacote': pacote,
          'card_token': cardToken,
          'payment_method_id': paymentMethodId,
          'installments': installments,
          'cpf': cpf,
          'device_id': deviceId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Erro ao processar pagamento com cartão: $e");
      return {'success': false, 'error': 'Falha na conexão com o servidor de pagamentos: $e'};
    }
  }

  static Future<dynamic> processSmile({
    required File imageFile,
    String color = 'BL2',
    String shape = 'Oval',
    String size = 'Médio',
    required String apiKey,
    List<double>? mouthBox,
    required String deviceId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/process-smile');

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      String currentDeviceId = await _getDeviceId();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'device_id': currentDeviceId,
          'image': base64Image,
          'color': color,
          'shape': shape,
          'size': size,
          if (mouthBox != null) 'mouth_box': mouthBox,
        }),
      ).timeout(const Duration(seconds: 180));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        String processedBase64 = data['processed_image'];
        Uint8List decodedBytes = base64Decode(processedBase64);
        final tempDir = await getTemporaryDirectory();
        final fileProcessed = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await fileProcessed.writeAsBytes(decodedBytes);

        String originalBase64 = data['original_image'];
        Uint8List decodedOriginalBytes = base64Decode(originalBase64);
        final fileOriginal = File('${tempDir.path}/original_padded_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await fileOriginal.writeAsBytes(decodedOriginalBytes);

        return {
          'success': true,
          'imagePath': fileProcessed.path,
          'originalImagePath': fileOriginal.path,
          'creditos_restantes': data['creditos_restantes'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Erro no servidor (${response.statusCode})',
        };
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