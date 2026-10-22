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

    if (apiKey.isEmpty) {
      // 📱 Utilizador Convidado: Registra/Verifica o Device ID na nuvem e busca os créditos do aparelho
      final dynamic resDevice = await ApiService.checkOrRegisterDevice();

      if (mounted) {
        setState(() {
          if (resDevice is Map<String, dynamic> && resDevice['success'] == true) {
            _creditos = resDevice['creditos'] ?? 0;
            final bool ehNovoAparelho = resDevice['novo'] ?? false;

            // 🎁 Dispara o Pop-up de Boas-Vindas didático no primeiro acesso do aparelho
            if (ehNovoAparelho) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _exibirPopupBoasVindas();
              });
            }
          } else if (resDevice is int) {
            _creditos = resDevice;
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
              'Como usar:\n1. Clique em "Nova Simulação".\n2. Tire ou escolha a foto do paciente.\n3. Visualize o resultado incrível e encante o seu paciente!',
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

  // 🚨 Modal quando o utilizador tenta simular e está com saldo zerado
  void _mostrarAlertaCreditosEsgotados() {
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
        content: const Text(
          'Você utilizou todas as suas simulações de cortesia.\n\nAdquira um novo pacote para continuar gerando simulações de sorriso!',
          style: TextStyle(fontSize: 15),
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
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlansScreen()),
              );
              _inicializarECarregarCreditos();
            },
            icon: const Icon(Icons.shopping_cart, size: 18),
            label: const Text('Comprar Créditos', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ⚠️ Aviso discreto quando restando apenas 1 crédito
  void _mostrarAvisoUltimoCredito() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Atenção: Esta é a sua última simulação disponível!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'RECARREGAR',
          textColor: Colors.amber,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlansScreen()),
            );
            _inicializarECarregarCreditos();
          },
        ),
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
              // 💎 Topo Inteligente com Badge de Créditos e Botão Entrar
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

                    // 🏷️ Pílula Interativa de Créditos + Entrar
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
                          // 🛒 Lado Esquerdo: Saldo de Créditos (Clica e vai para a Loja)
                          InkWell(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PlansScreen()),
                              );
                              _inicializarECarregarCreditos();
                            },
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

                          // 🔐 Lado Direito: Acesso / Login
                          InkWell(
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PlansScreen()),
                              );
                              _inicializarECarregarCreditos();
                            },
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