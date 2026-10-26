import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'background.dart';
import 'adjust_smile_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  File? _imageFile;
  String _simulationId = '';
  String _userEmail = '';
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map<String, dynamic>) {
        final path = args['imagePath'] ?? args['image'] ?? args['originalImagePath'];
        if (path is String && path.isNotEmpty) {
          _imageFile = File(path);
        } else if (path is File) {
          _imageFile = path;
        }

        _simulationId = args['simulationId'] ?? '';
        _userEmail = args['userEmail'] ?? '';
      } else if (args is String && args.isNotEmpty) {
        _imageFile = File(args);
      } else if (args is File) {
        _imageFile = args;
      }

      _processarCarregamento();
      _isInit = false;
    }
  }

  Future<void> _processarCarregamento() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🚀 Método que dispara a API do Flask/Replicate com Feedback Visual Dinâmico
  Future<void> _enviarParaProcessamentoIA(String corSelecionada) async {
    if (_imageFile == null) return;

    // Lista de mensagens dinâmicas para entreter e tranquilizar o usuário durante o "Cold Start" da GPU
    final List<String> mensagensLoading = [
      "Conectando ao servidor seguro de IA...",
      "Acordando motor gráfico na nuvem (GPU)...",
      "Enviando matriz de imagem do paciente...",
      "Processando proporções e alinhamento do sorriso...",
      "Aplicando escala Bleach selecionada...",
      "Finalizando renderização de alta precisão...",
      "Quase pronto! Otimizando resultado final..."
    ];

    int mensagemIndex = 0;
    Timer? timerMensagens;

    // Exibe o diálogo de carregamento bloqueante com frases dinâmicas
    showDialog(
      context: context,
      barrierDismissible: false, // Impede o usuário de fechar clicando fora
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Inicia o timer para trocar a mensagem a cada 3 segundos
            timerMensagens ??= Timer.periodic(const Duration(seconds: 3), (timer) {
              if (mounted) {
                setStateDialog(() {
                  mensagemIndex = (mensagemIndex + 1) % mensagensLoading.length;
                });
              }
            });

            return PopScope(
              canPop: false, // Bloqueia o botão de voltar do Android
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF5C6BC0)),
                      const SizedBox(height: 24),
                      const Text(
                        "Processando Simulação...",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3F51B5)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mensagensLoading[mensagemIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "(Isso pode levar alguns segundos devido ao arranque inicial da IA)",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    try {
      // Lê os bytes da imagem e converte para Base64
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Pega a chave ou identificador do usuário logado
      final boxUser = Hive.box('box_usuario');
      final apiKey = boxUser.get('email', defaultValue: '') as String;

      // Se não houver email logado, pega o device_id ou deixa vazio para tratar no backend
      final boxDevice = Hive.box('box_dispositivo'); // ajuste se o nome da sua box for diferente
      final deviceId = boxDevice.get('device_id', defaultValue: '') as String;

      // URL do seu backend no Render (substitua caso tenha uma URL customizada)
      final url = Uri.parse('https://SEU-APP-NO-RENDER.onrender.com/process-smile');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'device_id': deviceId,
          'image': base64Image,
          'color': corSelecionada, // ex: 'bl2'
        }),
      ).timeout(const Duration(seconds: 90)); // Timeout generoso para aguentar o cold start

      // Cancela o timer de mensagens
      timerMensagens?.cancel();

      // Fecha o diálogo de loading
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final String processedBase64 = data['processed_image'];
          final processedBytes = base64Decode(processedBase64);

          // Salva a imagem processada temporariamente no diretório local do app para exibir na tela de comparação
          final tempDir = Directory.systemTemp;
          final processedFile = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await processedFile.writeAsBytes(processedBytes);

          if (mounted) {
            // Navega para a tela de comparativo (CompareScreen) passando os caminhos
            Navigator.pushNamed(
              context,
              '/compare', // ou ajuste para a rota da sua tela de comparativo
              arguments: {
                'originalPath': _imageFile!.path,
                'processedPath': processedFile.path,
                'color': corSelecionada,
                'simulationId': _simulationId,
                'userEmail': _userEmail,
              },
            );
          }
        } else {
          _mostrarErro(data['error'] ?? 'Erro desconhecido ao processar.');
        }
      } else {
        _mostrarErro('Erro no servidor (${response.statusCode}). Tente novamente.');
      }
    } catch (e) {
      timerMensagens?.cancel();
      if (mounted) Navigator.of(context).pop(); // Fecha o loading se houver exceção
      _mostrarErro('Falha de conexão: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise da Imagem'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparando imagem...'),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Imagem Capturada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 🖼️ Foto com espaço expandido para ficar bem nítida e ampla
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (_imageFile != null && _imageFile!.existsSync())
                      ? Image.file(
                    _imageFile!,
                    fit: BoxFit.contain,
                  )
                      : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 🦷 Guia Explicativo Compacto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Guia da Tonalidade (Escala Bleach):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF3F51B5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniGuide('BL1', 'Ultra'),
                      _buildMiniGuide('BL2', 'Intenso'),
                      _buildMiniGuide('BL3', 'Natural'),
                      _buildMiniGuide('BL4', 'Suave'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Botão Principal para Chamar a IA com o Loading Dinâmico
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text(
                  'Processar Clareamento com IA',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  // Aqui você pode disparar direto ou abrir um seletor de cor se preferir.
                  // Por padrão mandamos 'bl2' ou pegamos a cor escolhida pelo dentista.
                  _enviarParaProcessamentoIA('bl2');
                },
              ),
            ),

            const SizedBox(height: 4),

            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
              label: const Text(
                'Tirar outra foto',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGuide(String code, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.indigo,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
      ],
    );
  }
}