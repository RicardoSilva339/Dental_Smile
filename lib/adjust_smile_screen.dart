import 'dart:io';
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
  int _creditos = 0; // Armazena o saldo atual de créditos
  bool _isLoadingCredits = true;

  late String _selectedColor;

  // 🦷 Cores baseadas exclusivamente na Escala Profissional Bleach (BL1 a BL4)
  final Map<String, String> _colors = {
    'bl1': 'BL1 (Ultra Branco)',
    'bl2': 'BL2 (Branco Intenso)',
    'bl3': 'BL3 (Natural Claro)',
    'bl4': 'BL4 (Suave)',
  };

  @override
  void initState() {
    super.initState();
    // Valor inicial padrão ajustado para bl2 (um dos mais buscados) caso não venha definido
    _selectedColor = widget.initialColor ?? 'bl2';

    // Busca os créditos ativos ao abrir a tela
    _carregarCreditos();
  }

  // 🔍 Retorna o e-mail/api_key do utilizador logado no Hive
  String _obterApiKeyAtual() {
    if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
      return widget.userEmail!;
    }
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  // 🔄 Busca créditos via e-mail ou via Device ID se estiver deslogado
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
      // Convidado: busca os créditos do aparelho via Device ID
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

    // Se estiver deslogado e zerado de créditos, direciona para a compra
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

    setState(() => _isProcessing = true);

    String? processedImagePath;

    try {
      // Envia a chamada de processamento da IA passando a cor selecionada da Escala Bleach
      // Mantemos parâmetros neutros de shape e size fixos para a IA preservar a anatomia natural
      final resultado = await ApiService.processSmile(
        imageFile: widget.image,
        color: _selectedColor,
        shape: 'natural',
        size: 'medio',
        apiKey: apiKey.isNotEmpty ? apiKey : '',
      );

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
      debugPrint("Falha na chamada do servidor: $e");
    }

    if (!mounted) return;

    processedImagePath ??= widget.image.path;

    setState(() => _isProcessing = false);

    // 🚀 Repassa o simulationId e userEmail para a CompareScreen gravar no Hive com o e-mail correto!
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

  Widget _buildColorChipGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            'Selecione a Tonalidade (Escala Bleach):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _colors.entries.map((entry) {
              final isSelected = _selectedColor == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  selectedColor: const Color(0xFF5C6BC0),
                  backgroundColor: Colors.white.withOpacity(0.85),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedColor = entry.key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool saldoZerado = _creditos <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha a Cor do Clareamento'),
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
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(
                    widget.image,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            // 🦷 Apenas o seletor de cores da Escala Bleach limpo e direto ao ponto
            _buildColorChipGroup(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
              child: ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isProcessing ? 'Processando com IA...' : 'Aplicar Clareamento'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _isProcessing ? null : _handleProcessSmile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}