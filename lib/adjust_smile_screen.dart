import 'dart:io';
import 'package:flutter/material.dart';

class AdjustSmileScreen extends StatefulWidget {
  final File image;

  const AdjustSmileScreen({super.key, required this.image});

  @override
  State<AdjustSmileScreen> createState() => _AdjustSmileScreenState();
}

class _AdjustSmileScreenState extends State<AdjustSmileScreen> {
  String _selectedColor = 'Natural';
  String _selectedShape = 'Quadrado';
  String _selectedSize = 'Médio';

  void _applyAdjustments() {
    Navigator.pushNamed(
      context,
      '/compare',
      arguments: {
        'originalImage': widget.image.path,
        'adjustedImage': widget.image.path, // aqui entraria a versão processada
        'existingItem': {
          'color': _selectedColor,
          'shape': _selectedShape,
          'size': _selectedSize,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes de Sorriso")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Controles em cima
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

            // Foto embaixo com pré-visualização
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Image.file(widget.image, height: 300, fit: BoxFit.cover),
                    Container(
                      color: Colors.white70,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        "Cor: $_selectedColor | Formato: $_selectedShape | Tamanho: $_selectedSize",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            ElevatedButton(
              onPressed: _applyAdjustments,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Aplicar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
