import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';
import 'plans_screen.dart';
import 'compare_screen.dart';

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
  bool _isInit = true;

  // 🦷 Apenas os códigos curtos e objetivos
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
    }
  }

  String _obterApiKeyAtual() {
    if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
      return widget.userEmail!;
    }
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  // 🔢 Gera ID sequencial DS-101+ usando o contador persistente em box_usuario
  Future<String> _gerarProximoIdSimulacao() async {
    final boxUser = Hive.box('box_usuario');
    final int ultimoId = (boxUser.get('ultimo_id_simulacao', defaultValue: 100) as int);
    final int proximoId = ultimoId < 100 ? 101 : ultimoId + 1;
    await boxUser.put('ultimo_id_simulacao', proximoId);
    return 'DS-$proximoId';
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

    setState(() {
      _isProcessing = true;
    });

    String? processedImagePath;
    String? originalPaddedPath;

    try {
      final boxUser = Hive.box('box_usuario');
      final deviceId = boxUser.get('device_id', defaultValue: 'device_${DateTime.now().millisecondsSinceEpoch}') as String;

      final resultado = await ApiService.processSmile(
        imageFile: widget.image,
        color: _selectedColor,
        shape: 'Oval',
        size: 'Médio',
        apiKey: apiKey.isNotEmpty ? apiKey : '',
        deviceId: deviceId,
      );

      if (resultado['success'] == true) {
        processedImagePath = resultado['imagePath'];
        originalPaddedPath = resultado['originalImagePath'];

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

    final String idParaEnviar = (widget.simulationId != null && widget.simulationId!.isNotEmpty)
        ? widget.simulationId!
        : await _gerarProximoIdSimulacao();

    if (!mounted) return;

    processedImagePath ??= widget.image.path;
    originalPaddedPath ??= widget.image.path;

    setState(() => _isProcessing = false);

    Navigator.pushReplacementNamed(
      context,
      '/compare',
      arguments: {
        'originalPath': originalPaddedPath,
        'processedPath': processedImagePath,
        'color': _colors[_selectedColor] ?? _selectedColor,
        'shape': 'Natural',
        'size': 'Padrão',
        'simulationId': idParaEnviar,
        'userEmail': apiKey,
      },
    );
  }

  Widget _buildColorGrid() {
    final keys = _colors.keys.toList();

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

              _buildColorGrid(),
              const SizedBox(height: 14),

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
                  label: Text(
                    _isProcessing ? 'Processando...' : 'Aplicar Clareamento',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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