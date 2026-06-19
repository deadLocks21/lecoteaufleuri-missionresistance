import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo de Mission Résistance — la marque « poste radio » (cadran TSF), rendue
/// depuis l'asset SVG partagé avec `design/`.
class ResistanceLogo extends StatelessWidget {
  const ResistanceLogo({super.key, this.size = 96});

  /// Côté du logo (carré), en pixels logiques.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/mission-resistance-logo.svg',
      width: size,
      height: size,
      semanticsLabel: 'Mission Résistance',
    );
  }
}
