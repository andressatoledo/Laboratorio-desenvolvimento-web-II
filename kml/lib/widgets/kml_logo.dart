import 'package:flutter/material.dart';

/// Logo do KML. O logotipo é petróleo escuro, então no tema escuro ele
/// ganha uma "plaquinha" clara atrás para continuar legível.
class KmlLogo extends StatelessWidget {
  const KmlLogo({super.key, this.height = 34});
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      'assets/images/kml_logo.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'KML - Quilômetros e lucratividade',
    );
    if (!dark) return image;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: image,
    );
  }
}
