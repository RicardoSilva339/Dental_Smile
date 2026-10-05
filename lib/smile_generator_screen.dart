import 'dart:io';
import 'package:flutter/material.dart';
import 'smile_service.dart';

class SmileGeneratorScreen extends StatefulWidget {
  final File patientImage;

  const SmileGeneratorScreen({super.key, required this.patientImage});

  @override
  State<SmileGeneratorScreen> createState() => _SmileGeneratorScreenState();
}

class _SmileGeneratorScreenState extends State<SmileGeneratorScreen> {
  String _selectedColor = 'A1';
  bool _isLoading = false;

  final Map<String, String> _vitaScaleOptions = {
    'BL1': 'Ultra Branco (BL1)',
    'A1': 'Branco Natural (A1)',
    'A2': 'Levemente Clareado (A2)',
    'B1': 'Claro (B1)',
  };

  Future<void> _generateSmile() async {
    setState(() => _isLoading = true);

    File? processedImage = await SmileService.processSmile(
      imageFile: widget.patientImage,
      colorCode: _selectedColor,
    );

    setState(() => _isLoading = false);

    if (processedImage != null && mounted) {
      // Navega para a tela de Antes x Depois
      Navigator.pushNamed(
        context,
        '/compare',
        arguments: {
          'originalImage': widget.patientImage.path,
          'adjustedImage': processedImage.path,
        },
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao processar o sorriso no servidor. Verifique a conexão.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise e Clareamento DSD'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 20),
            Text(
              'A processar imagem no servidor...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'A aplicar clareamento da Escala Vita e suavização.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pré-visualização da foto
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                widget.patientImage,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Selecione a Tonalidade (Escala Vita)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Lista de Seleção de Cor
            Column(
              children: _vitaScaleOptions.entries.map((entry) {
                final isSelected = _selectedColor == entry.key;
                return Card(
                  elevation: isSelected ? 3 : 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.deepPurple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    leading: Radio<String>(
                      value: entry.key,
                      groupValue: _selectedColor,
                      activeColor: Colors.deepPurple,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedColor = value);
                        }
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedColor = entry.key);
                    },
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Botão de Envio para a API
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text(
                  'Gerar Sorriso Automático',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _generateSmile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}