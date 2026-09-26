import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart'; // para abrir PDF

class MeusRelatoriosScreen extends StatefulWidget {
  const MeusRelatoriosScreen({super.key});

  @override
  State<MeusRelatoriosScreen> createState() => _MeusRelatoriosScreenState();
}

class _MeusRelatoriosScreenState extends State<MeusRelatoriosScreen> {
  List<FileSystemEntity> arquivos = [];

  @override
  void initState() {
    super.initState();
    _carregarRelatorios();
  }

  Future<void> _carregarRelatorios() async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory(dir.path);
    final lista = pasta.listSync().where((f) => f.path.endsWith('.pdf')).toList();

    setState(() {
      arquivos = lista;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Relatórios')),
      body: arquivos.isEmpty
          ? const Center(child: Text('Nenhum relatório encontrado'))
          : ListView.builder(
        itemCount: arquivos.length,
        itemBuilder: (context, index) {
          final arquivo = arquivos[index];
          final nome = arquivo.path.split('/').last;

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(nome),
              subtitle: Text('Caminho: ${arquivo.path}'),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  OpenFile.open(arquivo.path);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
