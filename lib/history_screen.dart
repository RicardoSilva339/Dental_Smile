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

  // 🧹 Menu inteligente de opções de limpeza (Filtro por tempo ou limpeza total)
  void _mostrarOpcoesLimpeza() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Color(0xFF5C6BC0)),
            SizedBox(width: 8),
            Text('Gerir Histórico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_toggle_off, color: Colors.orange),
              title: const Text('Apagar com mais de 30 dias'),
              subtitle: const Text('Liberta espaço removendo registos antigos'),
              onTap: () {
                Navigator.pop(ctx);
                _apagarSimulacoesAntigas(30);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Limpar Tudo'),
              subtitle: const Text('Apaga todo o histórico de simulações'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmarLimpezaTotal();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ⏳ Filtra e apaga apenas os registos mais antigos com base nos dias limite
  Future<void> _apagarSimulacoesAntigas(int diasLimite) async {
    final agora = DateTime.now();
    final chavesParaApagar = <dynamic>[];

    for (var key in _box.keys) {
      final rawItem = _box.get(key);
      if (rawItem is Map) {
        final item = Map<String, dynamic>.from(rawItem);
        final dateStr = item['date'] ?? '';
        if (dateStr.isNotEmpty) {
          try {
            final dataSimulacao = DateTime.parse(dateStr);
            final diferenca = agora.difference(dataSimulacao).inDays;
            if (diferenca > diasLimite) {
              chavesParaApagar.add(key);
            }
          } catch (_) {}
        }
      }
    }

    if (chavesParaApagar.isNotEmpty) {
      await _box.deleteAll(chavesParaApagar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${chavesParaApagar.length} simulações com mais de $diasLimite dias foram removidas.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma simulação antiga encontrada.')),
        );
      }
    }
  }

  // ⚠️ Confirmação antes de apagar todo o banco de histórico
  void _confirmarLimpezaTotal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apagar Todo o Histórico?'),
        content: const Text('Esta ação não pode ser desfeita. Deseja realmente apagar todas as simulações salvas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await _box.clear();
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Histórico limpo com sucesso!')),
                );
              }
            },
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Simulações'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Gerir e Limpar Histórico',
            onPressed: _mostrarOpcoesLimpeza,
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
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: box.length,
              itemBuilder: (context, index) {
                final rawItem = box.getAt(index);

                if (rawItem is! Map) {
                  return const SizedBox.shrink();
                }

                final item = Map<String, dynamic>.from(rawItem);
                final simulationId = item['simulationId'] ?? 'DS-SemID';
                final dateStr = item['date'] ?? '';
                final processedPath = item['processedPath'];
                final notes = item['notes'] ?? 'Sem observações';
                final key = box.keyAt(index);

                // ✅ Envolve o Card em um Dismissible para apagar individualmente arrastando para o lado
                return Dismissible(
                  key: Key(key.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Excluir Simulação'),
                        content: Text('Deseja apagar a simulação $simulationId do histórico?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    box.delete(key);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulação removida do histórico.')),
                    );
                  },
                  child: Card(
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