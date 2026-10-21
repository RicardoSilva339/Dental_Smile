import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  // 📝 Controllers para o formulário de cadastro do utilizador
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _croController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _croController.dispose();
    super.dispose();
  }

  // 🔍 Verifica se o utilizador já realizou o cadastro local
  bool _usuarioPossuiCadastro() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('is_registrado', defaultValue: false) as bool;
  }

  // 💾 Salva o cadastro localmente no Hive e sincroniza com o PostgreSQL no Render
  Future<void> _salvarCadastro() async {
    final boxUser = Hive.box('box_usuario');
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final cro = _croController.text.trim();

    // 1. Gravação local no Hive
    await boxUser.put('nome', nome);
    await boxUser.put('email', email);
    await boxUser.put('cro', cro);
    await boxUser.put('is_registrado', true);

    // 2. Envio automático para o PostgreSQL no Render (para ver no DBeaver)
    try {
      await ApiService.updateProfile('dentista_demo_123', nome, email, cro);
    } catch (e) {
      debugPrint('Aviso: Perfil salvo localmente, mas houve falha ao sincronizar com o servidor: $e');
    }
  }

  // 🛒 Regista a transação efetuada no histórico local
  Future<void> _registrarHistoricoCompra(String nomePlano, int creditos, String preco) async {
    final boxCompras = Hive.box('box_compras');
    final agora = DateTime.now();

    final novaCompra = {
      'idCompra': 'REC-${agora.millisecondsSinceEpoch}',
      'plano': nomePlano,
      'creditos': creditos,
      'preco': preco,
      'dataIso': agora.toIso8601String(),
      'dataFormatada': "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}",
    };

    await boxCompras.add(novaCompra);
  }

  // 📋 Exibe o modal de cadastro obrigatório
  Future<bool> _exibirDialogoCadastro() async {
    bool cadastradoComSucesso = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // Força o preenchimento para avançar na compra
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: Color(0xFF5C6BC0)),
            SizedBox(width: 10),
            Text('Cadastro Rápido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Complete o seu cadastro uma única vez para vincular as suas recargas e emitir relatórios clínicos.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome Completo / Clínica',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail ou WhatsApp',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _croController,
                decoration: InputDecoration(
                  labelText: 'CRO / Registo Profissional (Opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_nomeController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, preencha o Nome e o E-mail/WhatsApp.')),
                );
                return;
              }
              await _salvarCadastro();
              cadastradoComSucesso = true;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar e Continuar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return cadastradoComSucesso;
  }

  // 🛍️ Fluxo Principal de Compra
  Future<void> _comprarPlano(int creditos, String nomePlano, String preco) async {
    // Passagem 1: Verifica/Garante Cadastro
    if (!_usuarioPossuiCadastro()) {
      final confirmouCadastro = await _exibirDialogoCadastro();
      if (!confirmouCadastro) return; // Cancela a compra se desistir no cadastro
    }

    if (!mounted) return;

    // Passagem 2: Diálogo de Processamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text('Processando $nomePlano ($preco)...')),
          ],
        ),
      ),
    );

    // Simulação do tempo de resposta da operadora de cartão / PIX
    await Future.delayed(const Duration(seconds: 2));

    try {
      final sucesso = await ApiService.adicionarCreditos('dentista_demo_123', creditos);

      if (!mounted) return;
      Navigator.pop(context); // Fecha diálogo de loading

      if (sucesso) {
        // Regista a compra no histórico local do Hive
        await _registrarHistoricoCompra(nomePlano, creditos, preco);

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Pagamento Aprovado! 🎉'),
            content: Text('Foram adicionados $creditos créditos à sua conta com sucesso.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context); // Fecha o diálogo de confirmação
                  Navigator.pop(context, true); // Retorna à HomeScreen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _mostrarErro('Não foi possível atualizar os créditos no servidor.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fecha diálogo de loading em erro
      _mostrarErro('Erro ao processar a compra: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  // 📜 Exibe o BottomSheet com o Histórico de Recargas
  void _exibirHistoricoCompras() {
    final boxCompras = Hive.box('box_compras');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
            ),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Color(0xFF5C6BC0)),
                  SizedBox(width: 8),
                  Text('Histórico de Recargas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: boxCompras.listenable(),
                builder: (context, Box box, _) {
                  if (box.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma recarga encontrada.\nAs suas compras aparecerão aqui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: box.length,
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(box.getAt(box.length - 1 - index) as Map);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                            child: const Icon(Icons.add_shopping_cart, color: Color(0xFF5C6BC0)),
                          ),
                          title: Text(
                            '${item['plano']} (+${item['creditos']} créditos)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Data: ${item['dataFormatada'] ?? "-"}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Text(
                            '${item['preco']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja de Créditos'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Histórico de Compras',
            onPressed: _exibirHistoricoCompras,
          ),
        ],
      ),
      body: Background(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Escolha seu Pacote de Créditos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aumente sua capacidade de simulação e encante mais pacientes na clínica.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 12),

              // 🧾 Botão para abrir o Histórico de Recargas
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _exibirHistoricoCompras,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Ver Meu Histórico de Recargas', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),

              // Plano 1: Inicial (10 créditos)
              _buildPlanCard(
                titulo: 'Plano Inicial',
                creditos: '10 Créditos',
                preco: 'R\$ 29,90',
                detalhePreco: 'R\$ 2,99 por simulação',
                descricao: 'Ideal para uso ocasional e testes em consultas diárias.',
                corCard: Colors.white,
                isPopular: false,
                onPressed: () => _comprarPlano(10, 'Plano Inicial', 'R\$ 29,90'),
              ),
              const SizedBox(height: 16),

              // Plano 2: Profissional (50 créditos) - O mais vantajoso!
              _buildPlanCard(
                titulo: 'Plano Profissional',
                creditos: '50 Créditos',
                preco: 'R\$ 99,90',
                detalhePreco: 'R\$ 1,99 por simulação (Economia de 33%)',
                descricao: 'O plano preferido dos dentistas para uso recorrente na clínica.',
                corCard: Colors.indigo.shade50,
                isPopular: true,
                onPressed: () => _comprarPlano(50, 'Plano Profissional', 'R\$ 99,90'),
              ),
              const SizedBox(height: 16),

              // Plano 3: Master (100 créditos)
              _buildPlanCard(
                titulo: 'Plano Master',
                creditos: '100 Créditos',
                preco: 'R\$ 179,90',
                detalhePreco: 'R\$ 1,79 por simulação (Melhor valor)',
                descricao: 'Máximo rendimento e menor custo por simulação para clínicas.',
                corCard: Colors.white,
                isPopular: false,
                onPressed: () => _comprarPlano(100, 'Plano Master', 'R\$ 179,90'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String titulo,
    required String creditos,
    required String preco,
    required String detalhePreco,
    required String descricao,
    required Color corCard,
    required bool isPopular,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: corCard,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'MAIS VENDIDO 🌟',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              creditos,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              preco,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
            ),
            Text(
              detalhePreco,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onPressed,
                child: const Text('Comprar Pacote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}