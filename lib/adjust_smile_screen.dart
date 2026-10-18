import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';
import 'plans_screen.dart'; // Certifique-se de importar a tela de planos se necessário

class AdjustSmileScreen extends StatefulWidget {
  final File image;
  final Map<String, dynamic>? region;
  final String? initialColor;
  final String? initialShape;
  final String? initialSize;

  const AdjustSmileScreen({
    super.key,
    required this.image,
    this.region,
    this.initialColor,
    this.initialShape,
    this.initialSize,
  });

  @override
  State<AdjustSmileScreen> createState() => _AdjustSmileScreenState();
}

class _AdjustSmileScreenState extends State<AdjustSmileScreen> {
  bool _isProcessing = false;
  int _creditos = 0; // Armazena o saldo atual de créditos

  late String _selectedColor;
  late String _selectedShape;
  late String _selectedSize;

  final Map<String, String> _colors = {
    'natural': 'Natural',
    'brilhante': 'Brilhante',
    'perolado': 'Perolado',
  };

  final Map<String, String> _shapes = {
    'oval': 'Oval',
    'quadrado': 'Quadrado',
    'retangular': 'Retangular',
    'triangular': 'Triangular',
  };

  final Map<String, String> _sizes = {
    'curto': 'Curto',
    'medio': 'Médio',
    'longo': 'Longo',
  };

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor ?? 'brilhante';
    _selectedShape = widget.initialShape ?? 'oval';
    _selectedSize = widget.initialSize ?? 'medio';

    // Busca os créditos ao abrir o ecrã
    _carregarCreditos();
  }

  Future<void> _carregarCreditos() async {
    final resultado = await ApiService.checkCredits('dentista_demo_123');
    if (resultado['success'] == true && mounted) {
      setState(() {
        _creditos = resultado['creditos'] ?? 0;
      });
    }
  }

  Future<void> _handleProcessSmile() async {
    setState(() => _isProcessing = true);

    String? processedImagePath;

    try {
      // O ApiService.processSmile agora retorna um Map com o resultado e os créditos atualizados
      final resultado = await ApiService.processSmile(
        imageFile: widget.image,
        color: _selectedColor,
        shape: _selectedShape,
        size: _selectedSize,
      );

      if (resultado['success'] == true) {
        processedImagePath = resultado['imagePath'];

        if (mounted) {
          setState(() {
            // Atualiza os créditos na tela instantaneamente (ex: descendo de 13 para 12)
            _creditos = resultado['creditos_restantes'] ?? _creditos;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resultado['error'] ?? 'Erro ao processar simulação')),
          );
        }
      }
    } catch (e) {
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
        'shape': _shapes[_selectedShape] ?? _selectedShape,
        'size': _sizes[_selectedSize] ?? _selectedSize,
      },
    );
  }

  Widget _buildChipGroup({
    required String title,
    required Map<String, String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: options.entries.map((entry) {
              final isSelected = selectedValue == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  selectedColor: const Color(0xFF5C6BC0),
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) onSelected(entry.key);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize o Sorriso'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          // 🛒 Botão de Créditos / Carrinho interativo no topo
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  // Abre o ecrã de planos e aguarda o retorno para atualizar os créditos se houver compra
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlansScreen()),
                  );
                  // Atualiza os créditos ao voltar da tela de planos
                  _carregarCreditos();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$_creditos Créditos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.shopping_cart, color: Colors.amber, size: 16),
                    ],
                  ),
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
            _buildChipGroup(
              title: 'Cor:',
              options: _colors,
              selectedValue: _selectedColor,
              onSelected: (val) => setState(() => _selectedColor = val),
            ),
            const SizedBox(height: 8),
            _buildChipGroup(
              title: 'Formato:',
              options: _shapes,
              selectedValue: _selectedShape,
              onSelected: (val) => setState(() => _selectedShape = val),
            ),
            const SizedBox(height: 8),
            _buildChipGroup(
              title: 'Tamanho:',
              options: _sizes,
              selectedValue: _selectedSize,
              onSelected: (val) => setState(() => _selectedSize = val),
            ),
            const SizedBox(height: 16),
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
                label: Text(_isProcessing ? 'Processando com IA...' : 'Aplicar Sorriso'),
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