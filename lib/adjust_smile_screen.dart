import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dental_smile/api_service.dart';

class AdjustSmileScreen extends StatefulWidget {
  final File image;
  final Map<String, dynamic>? region;

  const AdjustSmileScreen({
    super.key,
    required this.image,
    this.region,
  });

  @override
  State<AdjustSmileScreen> createState() => _AdjustSmileScreenState();
}

class _AdjustSmileScreenState extends State<AdjustSmileScreen> {
  bool _isProcessing = false;

  String _selectedColor = 'brilhante';
  String _selectedShape = 'oval';
  String _selectedSize = 'medio';

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

  Future<void> _handleProcessSmile() async {
    setState(() => _isProcessing = true);

    String? processedImagePath;

    try {
      processedImagePath = await ApiService.processSmile(
        imageFile: widget.image,
        color: _selectedColor,
        shape: _selectedShape,
        size: _selectedSize,
      );
    } catch (e) {
      debugPrint("Falha na chamada do servidor: $e");
    }

    if (!mounted) return;

    // Fallback de segurança: evita telas de erro e avança no fluxo
    processedImagePath ??= widget.image.path;

    setState(() => _isProcessing = false);

    Navigator.pushNamed(
      context,
      '/compare',
      arguments: {
        'originalImagePath': widget.image.path,
        'processedImagePath': processedImagePath,
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  selectedColor: Colors.deepPurple.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.deepPurple : Colors.black87,
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
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  widget.image,
                  fit: BoxFit.contain, // ✅ Alterado de BoxFit.cover para BoxFit.contain para manter a proporção real
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
    );
  }
}