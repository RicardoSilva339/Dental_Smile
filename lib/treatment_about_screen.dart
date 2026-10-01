import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TreatmentAboutScreen extends StatefulWidget {
  final String? patientId;

  const TreatmentAboutScreen({super.key, this.patientId});

  @override
  State<TreatmentAboutScreen> createState() => _TreatmentAboutScreenState();
}

class _TreatmentAboutScreenState extends State<TreatmentAboutScreen> {
  final TextEditingController _notesController = TextEditingController();
  late Box _box;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initHiveAndLoadNotes();
  }

  // Carrega as anotações usando a caixa do Hive
  Future<void> _initHiveAndLoadNotes() async {
    _box = Hive.box('simulacoes');
    final key = 'notes_${widget.patientId ?? 'default'}';

    setState(() {
      _notesController.text = _box.get(key, defaultValue: '') as String;
      _isLoading = false;
    });
  }

  // Salva as anotações diretamente no Hive
  Future<void> _saveNotes() async {
    final key = 'notes_${widget.patientId ?? 'default'}';
    await _box.put(key, _notesController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anotações salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o Tratamento'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Anotações e Planejamento Clínico',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Espaço para registrar preferências do paciente, alertas clínicos ou lembretes dos próximos passos.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 12,
              decoration: InputDecoration(
                hintText:
                'Ex: Paciente deseja tom BL1 nas facetas. Agendar clareamento prévio. Sensibilidade no elemento 21.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _saveNotes,
              icon: const Icon(Icons.save),
              label: const Text(
                'Salvar Anotações',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}