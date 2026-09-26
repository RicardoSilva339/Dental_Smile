import 'dart:io';
import 'package:flutter/material.dart';

class SimulationDetailScreen extends StatelessWidget {
  final Map data;

  const SimulationDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalhes da Simulação")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Comparação Antes e Depois",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text("Original"),
                    if (data['originalImage'] != null)
                      Image.file(File(data['originalImage']), height: 150),
                  ],
                ),
                Column(
                  children: [
                    const Text("Ajustada"),
                    if (data['adjustedImage'] != null)
                      Image.file(File(data['adjustedImage']), height: 150),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text("Cor: ${data['color']}"),
            Text("Formato: ${data['shape']}"),
            Text("Tamanho: ${data['size']}"),
            const SizedBox(height: 10),
            Text("Observações: ${data['note']}"),
          ],
        ),
      ),
    );
  }
}
