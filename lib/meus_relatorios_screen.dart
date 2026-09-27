import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';

class MeusRelatoriosScreen extends StatefulWidget {
  const MeusRelatoriosScreen({super.key});

  @override
  State<MeusRelatoriosScreen> createState() => _MeusRelatoriosScreenState();
}

class _MeusRelatoriosScreenState extends State<MeusRelatoriosScreen> {
  late Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('simulacoes');
  }

  @override
  Widget build(BuildContext context) {
    final relatorios = box.toMap().entries
        .where((entry) => (entry.value as Map)['pdfPath'] != null)
        .toList()
      ..sort((a, b) => (b.value['date'] ?? '').compareTo(a.value['date'] ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Relatórios')),
      body: relatorios.isEmpty
          ? const Center(child: Text('Nenhum relatório encontrado'))
          : ListView.builder(
        itemCount: relatorios.length,
        itemBuilder: (context, index) {
          final entry = relatorios[index];
          final data = entry.value as Map;
          final nomeArquivo = data['pdfPath'].toString().split('/').last;

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text("Relatório: $nomeArquivo"),
              subtitle: Text(
                "Cor: ${data['color']} | Formato: ${data['shape']} | Tamanho: ${data['size']}\n"
                    "Obs: ${data['note'] ?? ''}",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  OpenFile.open(data['pdfPath']);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
