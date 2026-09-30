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
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Relatórios')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          final relatorios = box.toMap().entries.where((entry) {
            if (entry.value is Map) {
              final pdfPath = (entry.value as Map)['pdfPath'];
              return pdfPath != null && pdfPath.toString().isNotEmpty;
            }
            return false;
          }).toList()
            ..sort((a, b) {
              final dateA = (a.value is Map) ? (a.value['date'] ?? '') : '';
              final dateB = (b.value is Map) ? (b.value['date'] ?? '') : '';
              return dateB.compareTo(dateA);
            });

          if (relatorios.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum relatório encontrado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          return ListView.builder(
            itemCount: relatorios.length,
            itemBuilder: (context, index) {
              final entry = relatorios[index];
              final data = entry.value as Map;
              final pdfPath = data['pdfPath'].toString();
              final nomeArquivo = pdfPath.split('/').last;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                  title: Text(
                    "Relatório: $nomeArquivo",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    "Cor: ${data['color'] ?? '-'} | Formato: ${data['shape'] ?? '-'} | Tamanho: ${data['size'] ?? '-'}\n"
                        "Obs: ${data['note'] ?? 'Sem observações'}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.blue),
                    tooltip: 'Abrir PDF',
                    onPressed: () {
                      if (File(pdfPath).existsSync()) {
                        OpenFile.open(pdfPath);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Arquivo PDF não foi encontrado no dispositivo.')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}