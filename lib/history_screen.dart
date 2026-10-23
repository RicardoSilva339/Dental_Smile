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

  // 🔍 Retorna a chave do utilizador logado no Hive (e-mail) ou string vazia se deslogado (convidado)
  String _obterEmailUsuarioAtual() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  // 🧹 Menu inteligente de opções de limpeza (Filtro por tempo ou limpeza total da conta)
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
              title: const Text('Limpar Meu Histórico'),
              subtitle: const Text('Apaga as simulações salvas na conta ativa'),
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

  // ⏳ Filtra e apaga apenas os registos mais antigos do e-mail ativo
  Future<void> _apagarSimulacoesAntigas(int diasLimite) async {
    final emailAtual = _obterEmailUsuarioAtual();
    final agora = DateTime.now();
    final chavesParaApagar = <dynamic>[];

    for (var key in _box.keys) {
      final rawItem = _box.get(key);
      if (rawItem is Map) {
        final item = Map<String, dynamic>.from(rawItem);
        final emailDono = item['userEmail'] ?? item['email'] ?? '';

        // Filtra pelo e-mail da sessão ativa
        if (emailDono == emailAtual) {
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

  // ⚠️ Confirmação antes de apagar todo o histórico do e-mail ativo
  void _confirmarLimpezaTotal() {
    final emailAtual = _obterEmailUsuarioAtual();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apagar Histórico Ativo?'),
        content: const Text('Esta ação apagará todas as simulações salvas nesta sessão. Deseja continuar?'),
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
              final chavesParaApagar = <dynamic>[];

              for (var key in _box.keys) {
                final rawItem = _box.get(key);
                if (rawItem is Map) {
                  final item = Map<String, dynamic>.from(rawItem);
                  final emailDono = item['userEmail'] ?? item['email'] ?? '';
                  if (emailDono == emailAtual) {
                    chavesParaApagar.add(key);
                  }
                }
              }

              if (chavesParaApagar.isNotEmpty) {
                await _box.deleteAll(chavesParaApagar);
              }

              if (ctx.mounted) Navigator.pop(ctx);
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
    final emailAtual = _obterEmailUsuarioAtual();

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
            // 🔒 Filtra dinamicamente as simulações pertencentes ao e-mail logado
            final simuFiltradas = <Map<String, dynamic>>[];

            for (var i = 0; i < box.length; i++) {
              final rawItem = box.getAt(i);
              if (rawItem is Map) {
                final item = Map<String, dynamic>.from(rawItem);
                final emailDono = item['userEmail'] ?? item['email'] ?? '';
                final key = box.keyAt(i);

                if (emailDono == emailAtual) {
                  item['hiveKey'] = key; // Anexa a chave para exclusão
                  simuFiltradas.add(item);
                }
              }
            }

            if (simuFiltradas.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    emailAtual.isEmpty
                        ? 'Nenhuma simulação no modo visitante.\nFaça login para acessar o seu histórico.'
                        : 'Nenhuma simulação encontrada para a conta:\n$emailAtual',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: simuFiltradas.length,
              itemBuilder: (context, index) {
                // Inverte para exibir as simulações mais recentes no topo (Corrigido!)
                final item = simuFiltradas[simuFiltradas.length - 1 - index];

                final simulationId = item['simulationId'] ?? 'DS-SemID';
                final dateStr = item['date'] ?? '';
                final processedPath = item['processedPath'];
                final notes = item['notes'] ?? 'Sem observações';
                final key = item['hiveKey'];

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