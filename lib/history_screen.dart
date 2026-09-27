import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'simulation_detail_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final simulacoes = box.toMap().entries.toList()
      ..sort((a, b) => (b.value['date'] ?? '').compareTo(a.value['date'] ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Simulações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Limpar todo histórico',
            onPressed: () {
              setState(() {
                box.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Histórico limpo com sucesso!')),
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
        child: simulacoes.isEmpty
            ? const Center(
          child: Text(
            'Nenhuma simulação realizada ainda',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        )
            : ListView.builder(
          itemCount: simulacoes.length,
          itemBuilder: (context, index) {
            final entry = simulacoes[index];
            final data = entry.value as Map;

            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: data['adjustedImage'] != null
                    ? Image.file(
                  File(data['adjustedImage']),
                  width: 50,
                  fit: BoxFit.cover,
                )
                    : const Icon(Icons.image_not_supported),
                title: Text("Simulação em ${data['date'] ?? 'Data não informada'}"),
                subtitle: Text(
                  "Cor: ${data['color']} | Formato: ${data['shape']} | Tamanho: ${data['size']}\n"
                      "Obs: ${data['note'] ?? ''}",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data['pdfPath'] != null)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        tooltip: 'Abrir Relatório PDF',
                        onPressed: () {
                          OpenFile.open(data['pdfPath']);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Remover esta simulação',
                      onPressed: () {
                        setState(() {
                          box.delete(entry.key);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Simulação removida!')),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SimulationDetailScreen(data: data),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
