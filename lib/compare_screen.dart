import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CompareScreen extends StatefulWidget {
  final String originalImage;
  final String adjustedImage;
  final Map<String, dynamic>? existingItem;

  const CompareScreen({
    super.key,
    required this.originalImage,
    required this.adjustedImage,
    this.existingItem,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null && widget.existingItem!['note'] != null) {
      _noteController.text = widget.existingItem!['note'];
    }
  }

  Future<void> _saveSimulation() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final box = Hive.box('simulacoes');

      final Map<String, dynamic> simulationData = {
        'originalImage': widget.originalImage,
        'adjustedImage': widget.adjustedImage,
        'color': widget.existingItem?['color'] ?? 'A1',
        'shape': widget.existingItem?['shape'] ?? 'Natural',
        'size': widget.existingItem?['size'] ?? 'Médio',
        'note': _noteController.text,
        'date': widget.existingItem?['date'] ?? DateTime.now().toString().split('.')[0],
      };

      // Salva no Hive usando um timestamp único como chave
      final key = DateTime.now().millisecondsSinceEpoch.toString();
      await box.put(key, simulationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulação salva com sucesso no histórico!')),
        );

        // Volta para a Tela Inicial (HomeScreen) e limpa a pilha de telas
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar simulação: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Função auxiliar para criar a caixa da imagem com suporte a zoom
  Widget _buildZoomableImage(String imagePath) {
    return Container(
      height: 280, // Aumenta a área de visualização das fotos
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          panEnabled: true,  // Permite arrastar com o dedo
          minScale: 1.0,     // Tamanho inicial
          maxScale: 4.0,     // Permite dar zoom de até 4x
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparativo Antes / Depois'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Resultado da Simulação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Exibição Lado a Lado com Zoom
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Antes', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildZoomableImage(widget.originalImage),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Depois', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildZoomableImage(widget.adjustedImage),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Campo de Observações
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Observações / Anotações do Tratamento',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Botão de Confirmação
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.check_circle),
              label: Text(_isSaving ? 'Salvando...' : 'Confirmar e Salvar Simulação'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSaving ? null : _saveSimulation,
            ),
          ],
        ),
      ),
    );
  }
}