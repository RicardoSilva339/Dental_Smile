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
  int? _creditos;
  bool _isLoadingCredits = true;

  @override
  void initState() {
    super.initState();
    _buscarCreditos();
  }

  // 🔍 Retorna a chave do utilizador logado no Hive (e-mail) ou string vazia se deslogado
  String _obterApiKeyAtual() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  // 🔄 Busca o saldo de créditos do e-mail ativo no servidor Render
  Future<void> _buscarCreditos() async {
    final apiKey = _obterApiKeyAtual();

    // Se não houver utilizador logado, zera o saldo no ecrã
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _creditos = 0;
          _isLoadingCredits = false;
        });
      }
      return;
    }

    setState(() => _isLoadingCredits = true);
    final resultado = await ApiService.checkCredits(apiKey);
    if (mounted) {
      setState(() {
        if (resultado['success'] == true) {
          _creditos = resultado['creditos'];
        } else {
          _creditos = 0;
        }
        _isLoadingCredits = false;
      });
    }
  }

  // 🚨 Modal para obrigatoriedade de Login/Cadastro caso tente usar deslogado ou sem saldo
  void _mostrarAlertaNecessarioLoginOuCreditos() {
    final apiKey = _obterApiKeyAtual();
    final bool deslogado = apiKey.isEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              deslogado ? Icons.lock_outline : Icons.warning_amber_rounded,
              color: deslogado ? const Color(0xFF5C6BC0) : Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              deslogado ? 'Acesso Necessário' : 'Créditos Esgotados',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          deslogado
              ? 'Por favor, entre com a sua conta de dentista ou cadastre-se para iniciar simulações e gerir os seus créditos.'
              : 'Você não possui créditos suficientes para gerar uma nova simulação com IA.\n\nRecarregue o seu plano para continuar!',
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
            onPressed: () async {
              Navigator.pop(context); // Fecha o alerta
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlansScreen()),
              );
              _buscarCreditos(); // Recarrega saldo e sessão após voltar
            },
            icon: Icon(deslogado ? Icons.login : Icons.shopping_cart, size: 18),
            label: Text(
              deslogado ? 'Entrar / Cadastrar' : 'Comprar Créditos',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
            _buscarCreditos();
          },
        ),
      ),
    );
  }

  // Handler do clique no botão "Nova Simulação"
  void _aoClicarNovaSimulacao() {
    final apiKey = _obterApiKeyAtual();

    // Bloqueia caso o dentista esteja deslogado ou sem créditos
    if (apiKey.isEmpty || (_creditos != null && _creditos! <= 0)) {
      _mostrarAlertaNecessarioLoginOuCreditos();
      return;
    }

    if (_creditos == 1) {
      _mostrarAvisoUltimoCredito();
    }

    Navigator.pushNamed(context, '/capture').then((_) => _buscarCreditos());
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyAtual = _obterApiKeyAtual();
    final bool saldoBaixo = _creditos != null && _creditos! <= 5;

    return Scaffold(
      body: Background(
        imagePath: 'assets/images/antes_depois.jpg',
        opacity: 0.9,
        child: SafeArea(
          child: Column(
            children: [
              // 💎 Topo com o Badge de Créditos e Utilizador Clicável
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
                    // Distintivo de Créditos / Acesso
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PlansScreen()),
                        );
                        _buscarCreditos();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: saldoBaixo
                              ? Colors.red.shade900.withValues(alpha: 0.75)
                              : Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: saldoBaixo ? Colors.redAccent : Colors.white.withValues(alpha: 0.5),
                            width: saldoBaixo ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              apiKeyAtual.isEmpty
                                  ? Icons.person_off
                                  : (saldoBaixo ? Icons.warning_amber_rounded : Icons.monetization_on),
                              color: apiKeyAtual.isEmpty ? Colors.white70 : (saldoBaixo ? Colors.redAccent : Colors.amber),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            _isLoadingCredits
                                ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Row(
                              children: [
                                Text(
                                  apiKeyAtual.isEmpty
                                      ? 'Entrar'
                                      : '${_creditos ?? 0} Créditos',
                                  style: TextStyle(
                                    color: saldoBaixo ? Colors.red.shade100 : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  apiKeyAtual.isEmpty ? Icons.arrow_forward_ios : Icons.shopping_cart,
                                  color: apiKeyAtual.isEmpty ? Colors.white70 : (saldoBaixo ? Colors.redAccent : Colors.amber),
                                  size: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
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