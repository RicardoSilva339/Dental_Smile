import 'package:flutter/material.dart';

/// Recorta qualquer imagem/molde para ficar restrito estritamente
/// ao polígono interno da boca/lábios fornecido pelos pontos faciais.
class SmileClipper extends CustomClipper<Path> {
  final List<Offset> lipPoints;

  SmileClipper({required this.lipPoints});

  @override
  Path getClip(Size size) {
    Path path = Path();

    if (lipPoints.isEmpty) {
      return path;
    }

    // Move para o primeiro ponto dos lábios e liga as linhas do contorno
    path.moveTo(lipPoints[0].dx, lipPoints[0].dy);
    for (int i = 1; i < lipPoints.length; i++) {
      path.lineTo(lipPoints[i].dx, lipPoints[i].dy);
    }
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}