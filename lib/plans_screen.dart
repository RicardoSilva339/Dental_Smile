import 'package:flutter/material.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {

  Future<void> _comprarPlano(int creditos, String nomePlano, String preco) async {
    // Exibe diálogo de carregamento do processamento
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
      Navigator.pop(context); // Fecha o diálogo de loading

      if (sucesso) {
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
                  Navigator.pop(context); // Fecha diálogo de confirmação
                  Navigator.pop(context, true); // Retorna para a HomeScreen atualizando os créditos
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
      Navigator.pop(context); // Fecha o diálogo de loading em caso de erro
      _mostrarErro('Erro ao processar a compra: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja de Créditos'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
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
              const SizedBox(height: 25),

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