import 'package:flutter/material.dart';

class Background extends StatelessWidget {
  final Widget child;
  final String imagePath;
  final double opacity;

  const Background({
    super.key,
    required this.child,
    this.imagePath = 'assets/images/antes_depois.jpg', // padrão
    this.opacity = 0.9, // intensidade equilibrada
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: opacity,
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),
        child,
      ],
    );
  }
}
