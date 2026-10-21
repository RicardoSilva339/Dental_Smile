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
  // 📝 Controllers para os formulários de autenticação / cadastro
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _croController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _lembrarEmail = true;
  bool _modoCadastro = false; // Alterna entre Login (false) e Cadastro (true)

  @override
  void initState() {
    super.initState();
    _carregarEmailSalvo();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _croController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // 💾 Carrega o e-mail salvo se a opção "Lembrar meu e-mail" estiver ativa
  void _carregarEmailSalvo() {
    final boxUser = Hive.box('box_usuario');
    final emailSalvo = boxUser.get('email_salvo', defaultValue: '') as String;
    final lembrar = boxUser.get('lembrar_email', defaultValue: true) as bool;

    setState(() {
      _lembrarEmail = lembrar;
      if (lembrar && emailSalvo.isNotEmpty) {
        _emailController.text = emailSalvo;
      }
    });
  }

  // 🔍 Retorna o e-mail/api_key do utilizador com sessão ativa
  String _obterApiKeyAtual() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  bool _usuarioEstaLogado() {
    return _obterApiKeyAtual().isNotEmpty;
  }

  // 🚪 Efetua o Logout (Sair da Conta) para permitir trocar de utilizador
  Future<void> _fazerLogout() async {
    final boxUser = Hive.box('box_usuario');
    final emailAnterior = _emailController.text;

    await boxUser.put('is_registrado', false);
    await boxUser.put('email', ''); // Limpa a sessão ativa

    // Mantém o e-mail no controller se "Lembrar" estiver marcado
    if (!_lembrarEmail) {
      _emailController.clear();
    } else {
      _emailController.text = emailAnterior;
    }
    _senhaController.clear();

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão encerrada. Você pode entrar com outra conta.')),
      );
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

  // 🔐 Dialogo de Autenticação / Cadastro Seguro com Senha
  Future<bool> _exibirDialogoAutenticacao() async {
    bool autenticadoComSucesso = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  _modoCadastro ? Icons.person_add_alt_1 : Icons.lock_outline,
                  color: const Color(0xFF5C6BC0),
                ),
                const SizedBox(width: 10),
                Text(
                  _modoCadastro ? 'Criar Nova Conta' : 'Acesso do Dentista',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _modoCadastro
                        ? 'Cadastre-se uma única vez para vincular os seus créditos e emitir relatórios clínicos com segurança.'
                        : 'Introduza a sua senha para confirmar a sua identidade e vincular a sua recarga.',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  if (_modoCadastro) ...[
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome Completo / Clínica',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Campo E-mail
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-mail do Dentista',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_modoCadastro) ...[
                    TextField(
                      controller: _croController,
                      decoration: InputDecoration(
                        labelText: 'CRO / Registo Profissional (Opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Campo Senha
                  TextField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Sua Senha de Acesso',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 📌 Opção de Lembrar E-mail
                  Row(
                    children: [
                      Checkbox(
                        value: _lembrarEmail,
                        activeColor: const Color(0xFF5C6BC0),
                        onChanged: (val) {
                          setModalState(() {
                            _lembrarEmail = val ?? true;
                          });
                          setState(() {
                            _lembrarEmail = val ?? true;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Permanecer e-mail na tela',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),

                  // Alternar entre Login e Criar Conta
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _modoCadastro = !_modoCadastro;
                      });
                    },
                    child: Text(
                      _modoCadastro
                          ? 'Já possui uma conta? Faça Login'
                          : 'Ainda não tem conta? Cadastre-se aqui',
                      style: const TextStyle(color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold),
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
                  final email = _emailController.text.trim();
                  final senha = _senhaController.text.trim();

                  if (email.isEmpty || senha.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, preencha o E-mail e a Senha.')),
                    );
                    return;
                  }

                  // Guarda a preferência de lembrar e-mail
                  final boxUser = Hive.box('box_usuario');
                  await boxUser.put('lembrar_email', _lembrarEmail);
                  if (_lembrarEmail) {
                    await boxUser.put('email_salvo', email);
                  } else {
                    await boxUser.put('email_salvo', '');
                  }

                  if (_modoCadastro) {
                    // Fluxo de Cadastro
                    final res = await ApiService.register(
                      nome: _nomeController.text.trim(),
                      email: email,
                      cro: _croController.text.trim(),
                      senha: senha,
                    );

                    if (res['success'] == true) {
                      await boxUser.put('nome', _nomeController.text.trim());
                      await boxUser.put('email', email);
                      await boxUser.put('cro', _croController.text.trim());
                      await boxUser.put('is_registrado', true);
                      autenticadoComSucesso = true;
                      if (ctx.mounted) Navigator.pop(ctx);
                    } else {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['error'] ?? 'Erro no cadastro.'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    // Fluxo de Login
                    final res = await ApiService.login(email: email, senha: senha);

                    if (res['success'] == true) {
                      await boxUser.put('nome', res['nome'] ?? 'Dentista');
                      await boxUser.put('email', email);
                      await boxUser.put('is_registrado', true);
                      autenticadoComSucesso = true;
                      if (ctx.mounted) Navigator.pop(ctx);
                    } else {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['error'] ?? 'Erro ao efetuar login.'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(
                  _modoCadastro ? 'Cadastrar e Continuar' : 'Entrar e Continuar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    return autenticadoComSucesso;
  }

  // 🛍️ Fluxo Principal de Compra
  Future<void> _comprarPlano(int creditos, String nomePlano, String preco) async {
    // Passagem 1: Garantir Autenticação
    if (!_usuarioEstaLogado()) {
      final autenticou = await _exibirDialogoAutenticacao();
      if (!autenticou) return;
    }

    if (!mounted) return;

    final apiKeyAtual = _obterApiKeyAtual();

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

    await Future.delayed(const Duration(seconds: 2));

    try {
      final sucesso = await ApiService.adicionarCreditos(apiKeyAtual, creditos);

      if (!mounted) return;
      Navigator.pop(context); // Fecha diálogo de loading

      if (sucesso) {
        await _registrarHistoricoCompra(nomePlano, creditos, preco);

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Pagamento Aprovado! 🎉'),
            content: Text('Foram adicionados $creditos créditos à conta de ($apiKeyAtual) com sucesso.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
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
      Navigator.pop(context);
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
    final emailAtual = _obterApiKeyAtual();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja de Créditos'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          if (_usuarioEstaLogado())
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair / Trocar Conta',
              onPressed: _fazerLogout,
            ),
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
              if (_usuarioEstaLogado())
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sessão ativa: $emailAtual',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

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

              // Plano 2: Profissional (50 créditos)
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