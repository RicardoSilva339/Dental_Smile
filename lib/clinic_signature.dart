import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ClinicSignatureScreen extends StatefulWidget {
  const ClinicSignatureScreen({super.key});

  @override
  State<ClinicSignatureScreen> createState() => _ClinicSignatureScreenState();
}

class _ClinicSignatureScreenState extends State<ClinicSignatureScreen> {
  File? _signatureFile;

  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _signatureFile = File(picked.path);
      });

      // Salva no Hive para uso futuro
      var box = Hive.box('simulacoes');
      box.put('signaturePath', picked.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura/Carimbo salvo com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assinatura / Carimbo da Clínica")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _signatureFile != null
                ? Image.file(_signatureFile!, height: 150)
                : const Text("Nenhuma assinatura selecionada"),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Selecionar Assinatura/Carimbo"),
              onPressed: _pickSignature,
            ),
          ],
        ),
      ),
    );
  }
}
