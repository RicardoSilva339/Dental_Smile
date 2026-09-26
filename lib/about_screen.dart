import 'package:flutter/material.dart';
import 'background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o Tratamento')),
      body: Background(
        imagePath: 'assets/images/antes_depois.png',
        opacity: 0.25, // intensidade equilibrada
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Aplicativo Dental Smile - versão inicial\n\n'
                  'Este app foi desenvolvido para simulação de sorriso, '
                  'comparação de tratamentos e acompanhamento dos relatórios.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
