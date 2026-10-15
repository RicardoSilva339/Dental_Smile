import 'package:flutter/material.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';

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

  // Busca o saldo de créditos atualizado no servidor Render
  Future<void> _buscarCreditos() async {
    setState(() => _isLoadingCredits = true);
    final resultado = await ApiService.checkCredits('dentista_demo_123');
    if (mounted) {
      setState(() {
        if (resultado['success'] == true) {
          _creditos = resultado['creditos'];
        }
        _isLoadingCredits = false;
      });
    }
  }

  // 🚨 Modal quando tenta iniciar simulação sem créditos
  void _mostrarAlertaCreditosEsgotados() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Créditos Esgotados', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você não possui créditos suficientes para gerar uma nova simulação com IA.\n\nRecarregue seu plano para continuar encantando seus pacientes!',
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
              Navigator.pop(context); // Fecha o alerta
              await Navigator.pushNamed(context, '/plans');
              _buscarCreditos(); // Atualiza após voltar da compra
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
            await Navigator.pushNamed(context, '/plans');
            _buscarCreditos();
          },
        ),
      ),
    );
  }

  // Handler do clique no botão "Nova Simulação"
  void _aoClicarNovaSimulacao() {
    if (_creditos != null && _creditos! <= 0) {
      _mostrarAlertaCreditosEsgotados();
    } else {
      if (_creditos != null && _creditos! == 1) {
        _mostrarAvisoUltimoCredito();
      }
      Navigator.pushNamed(context, '/capture').then((_) => _buscarCreditos());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool saldoBaixo = _creditos != null && _creditos! <= 5;

    return Scaffold(
      body: Background(
        imagePath: 'assets/images/antes_depois.jpg',
        opacity: 0.9,
        child: SafeArea(
          child: Column(
            children: [
              // 💎 Topo com o Badge de Créditos Clicável
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
                    // Distintivo com mudança dinâmica de cor para vermelho se <= 5 créditos
                    GestureDetector(
                      onTap: () async {
                        await Navigator.pushNamed(context, '/plans');
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
                              saldoBaixo ? Icons.warning_amber_rounded : Icons.monetization_on,
                              color: saldoBaixo ? Colors.redAccent : Colors.amber,
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
                                  '${_creditos ?? 0} Créditos',
                                  style: TextStyle(
                                    color: saldoBaixo ? Colors.red.shade100 : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.shopping_cart,
                                  color: saldoBaixo ? Colors.redAccent : Colors.amber,
                                  size: 16,
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