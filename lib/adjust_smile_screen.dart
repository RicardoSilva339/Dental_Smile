import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'api_service.dart';

class AdjustSmileScreen extends StatefulWidget {
  final File image;
  final Map<String, dynamic>? region; // coordenadas dos dentes

  const AdjustSmileScreen({super.key, required this.image, this.region});

  @override
  State<AdjustSmileScreen> createState() => _AdjustSmileScreenState();
}

class _AdjustSmileScreenState extends State<AdjustSmileScreen> {
  String _selectedColor = 'Natural';
  String _selectedShape = 'Quadrado';
  String _selectedSize = 'Médio';

  bool loading = false;

  Future<void> _applyAdjustments() async {
    setState(() => loading = true);
    try {
      // Envia a imagem original para a IA
      final result = await ApiService.processSmile(widget.image);

      if (result != null) {
        // Salva resultado temporário
        final dir = await getTemporaryDirectory();
        final adjustedFile = File(
            '${dir.path}/adjusted_${DateTime.now().millisecondsSinceEpoch}.png');
        await adjustedFile.writeAsBytes(result);

        // Vai direto para tela de comparação
        Navigator.pushNamed(
          context,
          '/compare',
          arguments: {
            'originalImage': widget.image.path,
            'existingItem': {
              'color': _selectedColor,
              'shape': _selectedShape,
              'size': _selectedSize,
              'date': DateTime.now().toIso8601String(),
              'note': '',
              'region': widget.region,
            },
            'adjustedImage': adjustedFile.path,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível aplicar ajustes")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao aplicar ajustes: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes de Sorriso")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Controles de ajuste
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<String>(
                  value: _selectedColor,
                  items: const [
                    DropdownMenuItem(value: 'Natural', child: Text('Natural')),
                    DropdownMenuItem(value: 'Brilhante', child: Text('Brilhante')),
                    DropdownMenuItem(value: 'Perolado', child: Text('Perolado')),
                  ],
                  onChanged: (value) => setState(() => _selectedColor = value!),
                ),
                DropdownButton<String>(
                  value: _selectedShape,
                  items: const [
                    DropdownMenuItem(value: 'Quadrado', child: Text('Quadrado')),
                    DropdownMenuItem(value: 'Arredondado', child: Text('Arredondado')),
                    DropdownMenuItem(value: 'Oval', child: Text('Oval')),
                  ],
                  onChanged: (value) => setState(() => _selectedShape = value!),
                ),
                DropdownButton<String>(
                  value: _selectedSize,
                  items: const [
                    DropdownMenuItem(value: 'Curto', child: Text('Curto')),
                    DropdownMenuItem(value: 'Médio', child: Text('Médio')),
                    DropdownMenuItem(value: 'Longo', child: Text('Longo')),
                  ],
                  onChanged: (value) => setState(() => _selectedSize = value!),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Pré-visualização simples da foto original
            Expanded(
              child: Center(
                child: Image.file(widget.image, fit: BoxFit.contain),
              ),
            ),

            if (loading) const CircularProgressIndicator(),

            ElevatedButton(
              onPressed: _applyAdjustments,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Aplicar Ajustes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
