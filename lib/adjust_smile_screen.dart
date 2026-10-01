import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

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
  String _selectedColor = 'A1';
  String _selectedShape = 'Natural';
  String _selectedSize = 'Médio';
  bool _isLoading = false;

  // Dicionário com código enviado ao backend -> Texto exibido ao usuário
  final Map<String, String> _colorOptions = {
    'BL1': 'BL1 - Branco Extra (Bleach)',
    'A1': 'A1 - Branco Natural (Muito Claro)',
    'A2': 'A2 - Claro Natural',
    'A3': 'A3 - Tom Médio / Natural',
    'B1': 'B1 - Branco Amarelado Leve',
  };

  final List<String> _shapes = ['Natural', 'Oval', 'Quadrado', 'Retangular'];
  final List<String> _sizes = ['Pequeno', 'Médio', 'Grande'];

  Future<void> _applyChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.processSmile(
        widget.image,
        color: _selectedColor,
        shape: _selectedShape,
        size: _selectedSize,
      );

      if (result != null) {
        final tempDir = await getTemporaryDirectory();
        final adjustedFile = File(
            '${tempDir.path}/adjusted_${DateTime.now().millisecondsSinceEpoch}.png');
        await adjustedFile.writeAsBytes(result);

        if (mounted) {
          Navigator.pushNamed(
            context,
            '/compare',
            arguments: {
              'originalImage': widget.image.path,
              'adjustedImage': adjustedFile.path,
              'existingItem': {
                'color': _selectedColor,
                'shape': _selectedShape,
                'size': _selectedSize,
                'date': DateTime.now().toString().split('.')[0],
              },
            },
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao processar a imagem no servidor.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar com o servidor: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes do Sorriso')),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processando simulação no servidor...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(widget.image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Seleção de Cor com rótulos amigáveis
            const Text('Cor dos Dentes', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedColor,
              items: _colorOptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,   // Envia o código técnico ('BL1', 'A1', etc.)
                  child: Text(entry.value), // Mostra o nome descritivo para o usuário
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedColor = val);
              },
            ),
            const SizedBox(height: 12),

            // Seleção de Formato
            const Text('Formato dos Dentes', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedShape,
              items: _shapes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedShape = val);
              },
            ),
            const SizedBox(height: 12),

            // Seleção de Tamanho
            const Text('Tamanho dos Dentes', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedSize,
              items: _sizes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSize = val);
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _applyChanges,
              child: const Text('Aplicar Simulação', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}