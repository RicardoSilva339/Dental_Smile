import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';
import 'plans_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _creditos = 0;
  bool _isLoadingCredits = true;

  @override
  void initState() {
    super.initState();
    _inicializarECarregarCreditos();
  }

  // 🔍 Retorna a chave do utilizador logado no Hive (e-mail) ou string vazia se deslogado (convidado)
  String _obterApiKeyAtual() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  // 🚀 Inicializa o dispositivo no backend e exibe o modal de boas-vindas se for o primeiro acesso
  Future<void> _inicializarECarregarCreditos() async {
    setState(() => _isLoadingCredits = true);

    final apiKey = _obterApiKeyAtual();
    final boxUser = Hive.box('box_usuario');
    final bool jaExibiuPopupLocal = boxUser.get('ja_exibiu_popup', defaultValue: false) as bool;

    if (apiKey.isEmpty) {
      // 📱 Utilizador Convidado: Registra/Verifica o Device ID na nuvem e busca os créditos do aparelho
      final dynamic resDevice = await ApiService.checkOrRegisterDevice();

      if (mounted) {
        setState(() {
          if (resDevice is Map<String, dynamic> && resDevice['success'] == true) {
            _creditos = resDevice['creditos'] ?? 0;
            final bool ehNovoServidor = resDevice['novo'] ?? false;

            if (!jaExibiuPopupLocal || ehNovoServidor) {
              boxUser.put('ja_exibiu_popup', true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _exibirPopupBoasVindas();
              });
            }
          } else if (resDevice is int) {
            _creditos = resDevice;
            if (!jaExibiuPopupLocal) {
              boxUser.put('ja_exibiu_popup', true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _exibirPopupBoasVindas();
              });
            }
          } else {
            _creditos = 0;
          }
          _isLoadingCredits = false;
        });
      }
    } else {
      // 👤 Utilizador Logado: Consulta os créditos vinculados à conta dele
      final resultado = await ApiService.checkCredits(apiKey);
      if (mounted) {
        setState(() {
          if (resultado['success'] == true) {
            _creditos = resultado['creditos'] ?? 0;
          } else {
            _creditos = 0;
          }
          _isLoadingCredits = false;
        });
      }
    }
  }

  // 🎁 Modal de Boas-Vindas Didático (Aparece no primeiro acesso do aparelho)
  void _exibirPopupBoasVindas() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.card_giftcard, color: Color(0xFF5C6BC0), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Boas-vindas ao Dental Smile! 🎉',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você ganhou 3 Simulações Gratuitas para testar o aplicativo agora mesmo em sua clínica!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              '1. Como usar:\nClique em "Nova Simulação".\n2. Tire ou escolha a foto do paciente.\n3. Visualize o resultado incrível e encante o seu paciente!',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Começar a Usar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🧭 Menu de Escolha Inteligente: Separa Login, Cadastro e Loja
  void _mostrarMenuAcessoOuLoja() {
    final bool estaLogado = _obterApiKeyAtual().isNotEmpty;

    if (estaLogado) {
      // Se já estiver logado, abre a PlansScreen diretamente para ver conta/compras
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlansScreen()),
      ).then((_) => _inicializarECarregarCreditos());
      return;
    }

    // Se NÃO estiver logado, apresenta as opções transparentes
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Acesso do Dentista / Cadastro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Como você deseja acessar o aplicativo?',
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Opção 1: Fazer Login na Conta Existente
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login),
              label: const Text(
                'Já tenho conta / Fazer Login',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlansScreen(
                      abrirLoginDireto: true, // 👈 Abre direto na janela de LOGIN
                    ),
                  ),
                );
                _inicializarECarregarCreditos();
              },
            ),
            const SizedBox(height: 12),

            // Opção 2: Criar Nova Conta de Dentista
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text(
                'Criar Nova Conta de Dentista',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlansScreen(
                      abrirCadastroDireto: true, // 👈 Abre direto na janela de CADASTRO
                    ),
                  ),
                );
                _inicializarECarregarCreditos();
              },
            ),
            const SizedBox(height: 12),

            // Opção 3: Apenas Navegar pela Loja de Planos
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5C6BC0),
                side: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text(
                'Apenas Ver Pacotes de Créditos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlansScreen()),
                );
                _inicializarECarregarCreditos();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🚨 Modal quando o utilizador tenta simular e está com saldo zerado
  void _mostrarAlertaCreditosEsgotados() {
    final bool estaLogado = _obterApiKeyAtual().isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Créditos Esgotados',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          estaLogado
              ? 'Você utilizou todas as suas simulações. Adquira um novo pacote para continuar!'
              : 'Seus 3 créditos gratuitos acabaram.\n\nAcesse sua conta ou adquira um pacote de simulações.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _mostrarMenuAcessoOuLoja();
            },
            icon: const Icon(Icons.account_circle, size: 18),
            label: const Text('Acessar Conta / Loja', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ⚠️ Aviso discreto e dinâmico que desaparece sozinho em 3 segundos
  void _mostrarAvisoUltimoCredito() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Atenção: Esta é a sua última simulação disponível!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Handler do clique no botão "Nova Simulação"
  void _aoClicarNovaSimulacao() {
    if (_creditos <= 0) {
      _mostrarAlertaCreditosEsgotados();
      return;
    }

    if (_creditos == 1) {
      _mostrarAvisoUltimoCredito();
    }

    Navigator.pushNamed(context, '/capture').then((_) => _inicializarECarregarCreditos());
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyAtual = _obterApiKeyAtual();
    final bool estaLogado = apiKeyAtual.isNotEmpty;
    final bool saldoZerado = _creditos <= 0;

    return Scaffold(
      body: Background(
        imagePath: 'assets/images/antes_depois.jpg',
        opacity: 0.9,
        child: SafeArea(
          child: Column(
            children: [
              // 💎 Topo Inteligente com Badge de Créditos e Botão Entrar / Conta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dental Smile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    // 🏷️ Pílula Interativa de Créditos + Entrar / Conta
                    Container(
                      decoration: BoxDecoration(
                        color: saldoZerado
                            ? Colors.red.shade900.withOpacity(0.8)
                            : Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: saldoZerado ? Colors.redAccent : Colors.white.withOpacity(0.5),
                          width: saldoZerado ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🛒 Lado Esquerdo: Saldo de Créditos
                          InkWell(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                            onTap: _mostrarMenuAcessoOuLoja,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    saldoZerado ? Icons.add_shopping_cart : Icons.stars,
                                    color: saldoZerado ? Colors.redAccent : Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  _isLoadingCredits
                                      ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : Text(
                                    '$_creditos CR',
                                    style: TextStyle(
                                      color: saldoZerado ? Colors.red.shade100 : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Divisória vertical sutil
                          Container(height: 16, width: 1, color: Colors.white30),

                          // 🔐 Lado Direito: Acessa o menu de conta / login
                          InkWell(
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                            onTap: _mostrarMenuAcessoOuLoja,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    estaLogado ? Icons.account_circle : Icons.login,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    estaLogado ? 'Conta' : 'Entrar',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Conteúdo Central
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 60),
                            textStyle: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.indigo[300],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _aoClicarNovaSimulacao,
                          child: const Text('Nova Simulação'),
                        ),
                        const SizedBox(height: 20),
                        _buildButton(context, 'Histórico de Simulações', '/history'),
                        const SizedBox(height: 20),
                        _buildButton(context, 'Sobre o Tratamento', '/about'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, String route) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        textStyle: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.indigo[300],
        foregroundColor: Colors.white,
      ),
      onPressed: () => Navigator.pushNamed(context, route),
      child: Text(label),
    );
  }
}