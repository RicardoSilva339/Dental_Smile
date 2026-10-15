import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'background.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('simulacoes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Simulações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpar Histórico Corrompido/Antigo',
            onPressed: () async {
              await _box.clear();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Histórico limpo com sucesso!')),
                );
              }
            },
          ),
        ],
      ),
      body: Background(
        child: ValueListenableBuilder(
          valueListenable: _box.listenable(),
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
              padding: const EdgeInsets.all(16),
              itemCount: box.length,
              itemBuilder: (context, index) {
                final rawItem = box.getAt(index);

                // ✅ Tratamento blindado contra erros de cast de dados antigos
                if (rawItem is! Map) {
                  return const SizedBox.shrink(); // Ignores itens inválidos
                }

                final item = Map<String, dynamic>.from(rawItem);
                final simulationId = item['simulationId'] ?? 'DS-SemID';
                final dateStr = item['date'] ?? '';
                final originalPath = item['originalPath'];
                final processedPath = item['processedPath'];
                final notes = item['notes'] ?? 'Sem observações';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: processedPath != null && File(processedPath).existsSync()
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(processedPath),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.image, size: 40, color: Colors.grey),
                    title: Text(
                      'ID: $simulationId',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateStr.isNotEmpty)
                          Text(
                            'Data: ${dateStr.split('T')[0]}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        Text(
                          'Obs: $notes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/compare',
                        arguments: item,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}