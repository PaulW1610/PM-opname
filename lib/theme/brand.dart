import 'package:flutter/material.dart';

/// Huisstijl van blueprint collective: kleuren + herbruikbare UI-bouwstenen.
///
/// Kleuren zijn afgeleid van het logo (diep koningsblauw/marineblauw) met
/// oranje als accentkleur voor de belangrijkste acties.
class BrandColors {
  BrandColors._();

  /// Donker marineblauw (logo-kleur). Hoofdkleur voor knoppen en app-bar.
  static const Color navy = Color(0xFF002080);

  /// Iets diepere marine-variant (voor verloop/schaduw).
  static const Color navyDark = Color(0xFF001A5E);

  /// Heldere logo-blauw variant (voor accenten/verloop).
  static const Color navyBright = Color(0xFF0024B4);

  /// Accentkleur oranje (huisstijl) voor de belangrijkste acties.
  static const Color orange = Color(0xFFF7931E);

  /// Diepere oranje-variant (voor verloop/schaduw).
  static const Color orangeDark = Color(0xFFE07B00);
}

/// Een vierkante knop met afgeronde hoeken, een icoon en een label.
///
/// Gebruikt door de huisstijl-knoppenroosters. Wordt grijs/uitgeschakeld
/// weergegeven wanneer [onPressed] `null` is, zodat de lay-out stabiel blijft.
class BrandTileButton extends StatelessWidget {
  /// Maak een vierkante huisstijl-knop.
  const BrandTileButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = BrandColors.navy,
  }) : super(key: key);

  /// Het icoon bovenin de knop.
  final IconData icon;

  /// Het label onder het icoon.
  final String label;

  /// Actie bij tikken; `null` schakelt de knop uit (grijs).
  final VoidCallback? onPressed;

  /// Achtergrondkleur (oranje voor hoofdacties, marineblauw voor de rest).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color background = enabled ? color : const Color(0xFFCED2DA);
    final Color foreground = enabled ? Colors.white : const Color(0xFF8A8F99);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      elevation: enabled ? 2 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: foreground),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home-knop voor in de app-bar: keert terug naar het startscherm.
///
/// Plaats deze in `AppBar.actions` of `AppBar.leading` op elk scherm behalve
/// het startscherm zelf.
class BrandHomeButton extends StatelessWidget {
  /// Maak een home-knop die naar het startscherm springt.
  const BrandHomeButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Home',
      icon: const Icon(Icons.home_outlined),
      onPressed: () =>
          Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }
}
