import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Acessa a caixa 'simulacoes' inicializada no main.dart
    final box = Hive.box('simulacoes');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Simulações'),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma simulação salva no histórico.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: box.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              // Exibe do registro mais recente para o mais antigo
              final reversedIndex = box.length - 1 - index;
              final rawItem = box.getAt(reversedIndex);

              if (rawItem == null) return const SizedBox.shrink();

              final item = Map<String, dynamic>.from(rawItem as Map);

              // Formatação de data
              final dateStr = item['date'] as String? ?? '';
              final date = DateTime.tryParse(dateStr) ?? DateTime.now();
              final formattedDate =
                  "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

              final processedPath = item['processedPath'] as String?;
              final originalPath = item['originalPath'] as String?;
              final color = item['color'] ?? '-';
              final shape = item['shape'] ?? '-';
              final size = item['size'] ?? '-';
              final notes = item['notes'] as String? ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (processedPath != null &&
                        processedPath.isNotEmpty &&
                        File(processedPath).existsSync())
                        ? Image.file(
                      File(processedPath),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                        : (originalPath != null &&
                        originalPath.isNotEmpty &&
                        File(originalPath).existsSync())
                        ? Image.file(
                      File(originalPath),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  title: Text(
                    'Simulação em $formattedDate',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Cor: $color | Formato: $shape | Tamanho: $size\nObs: ${notes.isEmpty ? 'Sem observações' : notes}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Apagar registro',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Excluir Registro'),
                          content: const Text('Deseja realmente remover esta simulação do histórico?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await box.deleteAt(reversedIndex);
                      }
                    },
                  ),
                  onTap: () {
                    // Reabre a tela de comparação com as fotos salvas
                    if (originalPath != null && processedPath != null) {
                      Navigator.pushNamed(
                        context,
                        '/compare',
                        arguments: {
                          'originalImagePath': originalPath,
                          'processedImagePath': processedPath,
                          'color': color,
                          'shape': shape,
                          'size': size,
                          'notes': notes,
                        },
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}