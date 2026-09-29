import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // 👉 Troque este endereço pelo endpoint real da sua API
  static const String baseUrl = "https://seu-endereco-real.com/api";

  /// Função que envia a imagem para a IA e retorna os bytes da imagem ajustada
  static Future<Uint8List?> processSmile(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/processar'),
      );

      // adiciona o arquivo da foto
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        // retorna os bytes da imagem ajustada
        return await response.stream.toBytes();
      } else {
        throw Exception("Erro ao processar imagem: ${response.statusCode}");
      }
    } on SocketException {
      throw Exception("Erro de conexão: não foi possível acessar o servidor. Verifique sua internet ou o endereço da API.");
    } catch (e) {
      throw Exception("Erro inesperado: $e");
    }
  }
}
