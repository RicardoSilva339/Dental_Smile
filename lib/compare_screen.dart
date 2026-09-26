import 'dart:io';
import 'package:flutter/material.dart';

class CompareScreen extends StatelessWidget {
  final String originalImage;
  final String adjustedImage;
  final Map existingItem;

  const CompareScreen({
    super.key,
    required this.originalImage,
    required this.adjustedImage,
    required this.existingItem,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparação Antes/Depois')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "Veja o resultado da simulação",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Imagens lado a lado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text("Original", style: TextStyle(fontWeight: FontWeight.bold)),
                    Image.file(File(originalImage), height: 200, fit: BoxFit.cover),
                  ],
                ),
                Column(
                  children: [
                    const Text("Ajustada", style: TextStyle(fontWeight: FontWeight.bold)),
                    Image.file(File(adjustedImage), height: 200, fit: BoxFit.cover),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Atributos escolhidos
            Text("Cor: ${existingItem['color']}"),
            Text("Formato: ${existingItem['shape']}"),
            Text("Tamanho: ${existingItem['size']}"),

            const Spacer(),

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // volta para ajustes
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text("Voltar para Ajustes"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/feedback',
                        arguments: existingItem,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      "Confirmar Alteração",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
