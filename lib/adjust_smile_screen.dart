import 'dart:io';
import 'dart:async'; // ⏱️ Necessário para o Timer das mensagens dinâmicas
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';
import 'plans_screen.dart';

class AdjustSmileScreen extends StatefulWidget {
  final File image;
  final Map<String, dynamic>? region;
  final String? initialColor;
  final String? simulationId;
  final String? userEmail;

  const AdjustSmileScreen({
    super.key,
    required this.image,
    this.region,
    this.initialColor,
    this.simulationId,
    this.userEmail,
  });

  @override
  State<AdjustSmileScreen> createState() => _AdjustSmileScreenState();
}

class _AdjustSmileScreenState extends State<AdjustSmileScreen> {
  bool _isProcessing = false;
  int _creditos = 0;
  bool _isLoadingCredits = true;

  late String _selectedColor;

  // 🔄 Variáveis para controlar as mensagens dinâmicas do processamento de IA a cada 10 segundos
  Timer? _timerMensagens;
  int _mensagemIndex = 0;

  final List<String> _mensagensLoading = [
    "Conectando ao servidor seguro de IA...",
    "Acordando motor gráfico na nuvem (GPU)...",
    "Enviando matriz de imagem do paciente...",
    "Processando proporções e alinhamento do sorriso...",
    "Aplicando escala Bleach selecionada...",
    "Finalizando renderização de alta precisão...",
    "Quase pronto! Otimizando resultado final..."
  ];

  // 🦷 Apenas os códigos curtos e objetivos como você pediu
  final Map<String, String> _colors = {
    'bl1': 'BL1',
    'bl2': 'BL2',
    'bl3': 'BL3',
    'bl4': 'BL4',
  };

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor ?? 'bl2';
    _carregarCreditos();
  }

  @override
  void dispose() {
    _timerMensagens?.cancel(); // Limpa o timer ao sair da tela
    super.dispose();
  }

  String _obterApiKeyAtual() {
    if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
      return widget.userEmail!;
    }
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  Future<void> _carregarCreditos() async {
    if (!mounted) return;
    setState(() => _isLoadingCredits = true);

    final apiKey = _obterApiKeyAtual();

    if (apiKey.isNotEmpty) {
      final resultado = await ApiService.checkCredits(apiKey);
      if (mounted && resultado['success'] == true) {
        setState(() {
          _creditos = resultado['creditos'] ?? 0;
          _isLoadingCredits = false;
        });
      }
    } else {
      final dynamic resDevice = await ApiService.checkOrRegisterDevice();
      if (mounted) {
        setState(() {
          if (resDevice is Map<String, dynamic> && resDevice['success'] == true) {
            _creditos = resDevice['creditos'] ?? 0;
          } else if (resDevice is int) {
            _creditos = resDevice;
          } else {
            _creditos = 0;
          }
          _isLoadingCredits = false;
        });
      }
    }
  }

  Future<void> _handleProcessSmile() async {
    final apiKey = _obterApiKeyAtual();

    if (apiKey.isEmpty && _creditos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seus créditos de cortesia acabaram. Adquira um pacote para continuar!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlansScreen()),
      );
      _carregarCreditos();
      return;
    }

    // 🚀 Inicia o estado de processamento e o ciclo das mensagens dinâmicas a cada 10 segundos
    setState(() {
      _isProcessing = true;
      _mensagemIndex = 0;
    });

    _timerMensagens = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _mensagemIndex = (_mensagemIndex + 1) % _mensagensLoading.length;
        });
      }
    });

    String? processedImagePath;

    try {
      final resultado = await ApiService.processSmile(
        imageFile: widget.image,
        color: _selectedColor,
        shape: 'natural',
        size: 'medio',
        apiKey: apiKey.isNotEmpty ? apiKey : '',
      );

      // Para o timer assim que a resposta da IA chega
      _timerMensagens?.cancel();

      if (resultado['success'] == true) {
        processedImagePath = resultado['imagePath'];

        if (mounted) {
          setState(() {
            if (resultado['creditos_restantes'] != null && resultado['creditos_restantes'] is int) {
              _creditos = resultado['creditos_restantes'];
            } else if (_creditos > 0) {
              _creditos = _creditos - 1;
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['error'] ?? 'Créditos insuficientes ou falha na simulação.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      _timerMensagens?.cancel();
      debugPrint("Falha na chamada do servidor: $e");
    }

    if (!mounted) return;

    processedImagePath ??= widget.image.path;

    setState(() => _isProcessing = false);

    Navigator.pushReplacementNamed(
      context,
      '/compare',
      arguments: {
        'originalPath': widget.image.path,
        'processedPath': processedImagePath,
        'color': _colors[_selectedColor] ?? _selectedColor,
        'shape': 'Natural',
        'size': 'Padrão',
        'simulationId': widget.simulationId ?? 'DS-${DateTime.now().millisecondsSinceEpoch}',
        'userEmail': apiKey,
      },
    );
  }

  // 🦷 Grade 2x2 compacta (BL1/BL2 em cima, BL3/BL4 embaixo)
  Widget _buildColorGrid() {
    final keys = _colors.keys.toList(); // ['bl1', 'bl2', 'bl3', 'bl4']

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Selecione a Tonalidade:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildChipButton(keys[0])),
              const SizedBox(width: 8),
              Expanded(child: _buildChipButton(keys[1])),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildChipButton(keys[2])),
              const SizedBox(width: 8),
              Expanded(child: _buildChipButton(keys[3])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipButton(String key) {
    final isSelected = _selectedColor == key;
    final label = _colors[key]!;

    return SizedBox(
      height: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF5C6BC0) : Colors.white.withOpacity(0.9),
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: _isProcessing ? null : () => setState(() => _selectedColor = key),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool saldoZerado = _creditos <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuste do Clareamento'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: saldoZerado
                      ? Colors.red.shade900.withOpacity(0.8)
                      : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: saldoZerado ? Colors.redAccent : Colors.amber.withOpacity(0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      saldoZerado ? Icons.warning_amber_rounded : Icons.stars,
                      color: saldoZerado ? Colors.redAccent : Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    _isLoadingCredits
                        ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      '$_creditos CR',
                      style: TextStyle(
                        color: saldoZerado ? Colors.red.shade100 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Background(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            children: [
              // 🖼️ Foto com espaço bastante ampliado e nítido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      widget.image,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 🦷 Seletor em Grade 2x2 limpo
              _buildColorGrid(),
              const SizedBox(height: 10),

              // 🔄 Caixa de status dinâmica elegante que aparece logo acima do botão a cada 10s
              if (_isProcessing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF5C6BC0), width: 1),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _mensagensLoading[_mensagemIndex],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // 🚀 Botão principal de aplicar clareamento
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  icon: _isProcessing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isProcessing ? 'Processando com IA...' : 'Aplicar Clareamento'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessing ? null : _handleProcessSmile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}