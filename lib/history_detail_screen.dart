import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'feedback_screen.dart';

class HistoryDetailScreen extends StatelessWidget {
  final Map item;
  const HistoryDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // ✅ Tenta recuperar o caminho da imagem ajustada ou original
    final String? imagePath = item['adjustedImage'] ?? item['originalImage'] ?? item['image'];

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da Simulação')),
      body: Column(
        children: [
          // Foto com zoom
          Expanded(
            child: InteractiveViewer(
              child: (imagePath != null && File(imagePath).existsSync())
                  ? Image.file(File(imagePath))
                  : const Center(
                child: Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
              ),
            ),
          ),
          // Dados do paciente e feedback
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paciente: ${item['paciente'] ?? 'Não informado'}',
                    style: const TextStyle(fontSize: 16)),
                Text('Dentista: ${item['dentista'] ?? 'Não informado'}',
                    style: const TextStyle(fontSize: 16)),
                Text('Data: ${item['date'] ?? ''}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text('Feedback: ${item['note'] ?? 'Sem observação'}',
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          // Botões de ação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (imagePath != null && File(imagePath).existsSync()) {
                    Share.shareXFiles(
                      [XFile(imagePath)],
                      text: item['note'] ?? '',
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Arquivo de imagem não encontrado para compartilhar.')),
                    );
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedbackScreen(
                        existingItem: item, // 👈 edição
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}