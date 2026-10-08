import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('simulacoes');
  }

  /// Remove os arquivos físicos de imagem e PDF do armazenamento do celular
  Future<void> _deletarArquivosLocais(Map data) async {
    final paths = [
      data['originalImage'],
      data['adjustedImage'],
      data['pdfPath'],
    ];

    for (final path in paths) {
      if (path != null && path.toString().isNotEmpty) {
        final file = File(path.toString());
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('Erro ao apagar arquivo $path: $e');
          }
        }
      }
    }
  }

  /// Limpa todos os registros e remove todos os arquivos físicos salvos
  Future<void> _limparTodoHistorico() async {
    for (var entry in box.toMap().entries) {
      if (entry.value is Map) {
        await _deletarArquivosLocais(entry.value as Map);
      }
    }
    await box.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Simulações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
            tooltip: 'Limpar todo o histórico',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Limpar todo o histórico?'),
                  content: const Text(
                    'Esta ação apagará permanentemente todas as simulações, '
                        'imagens geradas e relatórios PDF salvos no dispositivo.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _limparTodoHistorico();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Histórico e arquivos apagados com sucesso!'),
                            ),
                          );
                        }
                      },
                      child: const Text('Limpar Tudo', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/antes_depois.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black54,
              BlendMode.darken,
            ),
          ),
        ),
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box box, _) {
            final simulacoes = box.toMap().entries.toList()
              ..sort((a, b) {
                final dateA = (a.value is Map) ? (a.value['date'] ?? '') : '';
                final dateB = (b.value is Map) ? (b.value['date'] ?? '') : '';
                return dateB.compareTo(dateA);
              });

            if (simulacoes.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhuma simulação realizada ainda',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              itemCount: simulacoes.length,
              itemBuilder: (context, index) {
                final entry = simulacoes[index];
                if (entry.value is! Map) return const SizedBox.shrink();

                final data = entry.value as Map;
                final imagePath = data['adjustedImage'] ?? data['originalImage'];
                final pdfPath = data['pdfPath'];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: (imagePath != null && File(imagePath).existsSync())
                        ? Image.file(
                      File(imagePath),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                        : const Icon(Icons.image_not_supported),
                    title: Text("Simulação em ${data['date'] ?? 'Data não informada'}"),
                    subtitle: Text(
                      "Cor: ${data['color'] ?? '-'} | Formato: ${data['shape'] ?? '-'} | Tamanho: ${data['size'] ?? '-'}\n"
                          "Obs: ${data['note'] ?? ''}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pdfPath != null && File(pdfPath).existsSync())
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            tooltip: 'Abrir Relatório PDF',
                            onPressed: () {
                              OpenFile.open(pdfPath);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Remover esta simulação',
                          onPressed: () async {
                            await _deletarArquivosLocais(data);
                            await box.delete(entry.key);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Simulação e arquivos removidos!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      if (pdfPath != null && File(pdfPath).existsSync()) {
                        OpenFile.open(pdfPath);
                      } else {
                        Navigator.pushNamed(
                          context,
                          '/compare',
                          arguments: {
                            'originalImage': data['originalImage'],
                            'adjustedImage': data['adjustedImage'],
                            'color': data['color'],
                            'shape': data['shape'],
                            'size': data['size'],
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
      ),
    );
  }
}