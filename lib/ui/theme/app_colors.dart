// Mission Résistance — tokens de couleur « Poste Radio TSF » (olive · laiton · LCD).
//
// Palette dérivée du design system (`design/tokens/design-tokens.json`, thème
// « radio militaire WWII »). Pattern : palette brute de bas niveau + extension de
// thème `AppColors` (`ThemeExtension`) consommée dans l'UI via `context.appColors`.
//
// Esthétique skeuomorphique : panneau métal vert olive, plaque laiton, fenêtres
// LCD vertes, voyants ambre, bouton d'émission rouge. Thème volontairement sombre.

import 'package:flutter/material.dart';

/// Palette brute (tokens de bas niveau). Ne pas utiliser directement dans l'UI :
/// toujours passer par [AppColors] / `context.appColors`.
abstract final class TsfPalette {
  // Olive — panneau
  static const olivePanel = Color(0xFF4A4E38);
  static const oliveDark = Color(0xFF2E3122);
  static const oliveLight = Color(0xFF5E6347);
  static const oliveEdge = Color(0xFF191A12);
  static const appBg = Color(0xFF14150E);
  static const bezel = Color(0xFF1B1D15);

  // Laiton
  static const brass = Color(0xFFB39750);
  static const brassDark = Color(0xFF6F5A2A);
  static const brassLight = Color(0xFFE6CF8F);

  // Texte
  static const cream = Color(0xFFEFE6CF);
  static const onOlive = Color(0xFFE9E3CB);
  static const ink = Color(0xFF14150D);
  static const muted = Color(0xFF9A9576);
  static const mutedDim = Color(0xFF8B8A72);

  // Rouge — alerte / émission / erreur
  static const red = Color(0xFFB3331E);
  static const redDark = Color(0xFF6F1C10);
  static const redGlow = Color(0xFFFF6A43);

  // Ambre — voyants / actif
  static const amber = Color(0xFFFFB13A);
  static const amberGlow = Color(0xFFFF8C1A);

  // Vert LCD — OK / signal
  static const green = Color(0xFF7FE389);
  static const greenGlow = Color(0xFF36D24C);
  static const lcdText = Color(0xFF9BD17A);
  static const lcdBg = Color(0xFF0C0F08);

  // Papier (fiches indices)
  static const paperBg = Color(0xFFEFE6CF);
  static const paperText = Color(0xFF221D10);
  static const paperLabel = Color(0xFF7A5A1A);
}

/// Tokens sémantiques exposés à l'UI via `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.panel,
    required this.panelRaised,
    required this.edge,
    required this.brass,
    required this.onBrass,
    required this.textPrimary,
    required this.textMuted,
    required this.emit,
    required this.onEmit,
    required this.signal,
    required this.lcd,
    required this.lcdBackground,
    required this.paper,
    required this.onPaper,
  });

  final Color background; // fond appli (derrière le poste)
  final Color panel; // surface du poste (métal olive)
  final Color panelRaised; // arête éclairée / élément en relief
  final Color edge; // bord quasi-noir / ombre
  final Color brass; // plaque & vis laiton (accent principal)
  final Color onBrass;
  final Color textPrimary; // texte clair sur olive
  final Color textMuted; // légendes, inactif
  final Color emit; // bouton d'émission / alerte (rouge)
  final Color onEmit;
  final Color signal; // voyants actifs (ambre)
  final Color lcd; // texte vert des écrans LCD
  final Color lcdBackground; // fond des fenêtres LCD
  final Color paper; // fiches indices
  final Color onPaper;

  static const AppColors dark = AppColors(
    background: TsfPalette.appBg,
    panel: TsfPalette.olivePanel,
    panelRaised: TsfPalette.oliveLight,
    edge: TsfPalette.oliveEdge,
    brass: TsfPalette.brass,
    onBrass: TsfPalette.ink,
    textPrimary: TsfPalette.cream,
    textMuted: TsfPalette.muted,
    emit: TsfPalette.red,
    onEmit: TsfPalette.cream,
    signal: TsfPalette.amber,
    lcd: TsfPalette.lcdText,
    lcdBackground: TsfPalette.lcdBg,
    paper: TsfPalette.paperBg,
    onPaper: TsfPalette.paperText,
  );

  static const AppColors light = AppColors(
    background: TsfPalette.bezel,
    panel: TsfPalette.oliveLight,
    panelRaised: TsfPalette.olivePanel,
    edge: TsfPalette.oliveEdge,
    brass: TsfPalette.brassLight,
    onBrass: TsfPalette.ink,
    textPrimary: TsfPalette.cream,
    textMuted: TsfPalette.mutedDim,
    emit: TsfPalette.red,
    onEmit: TsfPalette.cream,
    signal: TsfPalette.amber,
    lcd: TsfPalette.lcdText,
    lcdBackground: TsfPalette.lcdBg,
    paper: TsfPalette.paperBg,
    onPaper: TsfPalette.paperText,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? panel,
    Color? panelRaised,
    Color? edge,
    Color? brass,
    Color? onBrass,
    Color? textPrimary,
    Color? textMuted,
    Color? emit,
    Color? onEmit,
    Color? signal,
    Color? lcd,
    Color? lcdBackground,
    Color? paper,
    Color? onPaper,
  }) {
    return AppColors(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      edge: edge ?? this.edge,
      brass: brass ?? this.brass,
      onBrass: onBrass ?? this.onBrass,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      emit: emit ?? this.emit,
      onEmit: onEmit ?? this.onEmit,
      signal: signal ?? this.signal,
      lcd: lcd ?? this.lcd,
      lcdBackground: lcdBackground ?? this.lcdBackground,
      paper: paper ?? this.paper,
      onPaper: onPaper ?? this.onPaper,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelRaised: Color.lerp(panelRaised, other.panelRaised, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      brass: Color.lerp(brass, other.brass, t)!,
      onBrass: Color.lerp(onBrass, other.onBrass, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      emit: Color.lerp(emit, other.emit, t)!,
      onEmit: Color.lerp(onEmit, other.onEmit, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      lcd: Color.lerp(lcd, other.lcd, t)!,
      lcdBackground: Color.lerp(lcdBackground, other.lcdBackground, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      onPaper: Color.lerp(onPaper, other.onPaper, t)!,
    );
  }
}

/// Accès ergonomique aux tokens : `context.appColors.brass`.
extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

/// Construction des thèmes Material à partir des tokens [AppColors].
abstract final class AppThemeData {
  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: TsfPalette.olivePanel,
      brightness: brightness,
    ).copyWith(
      surface: colors.panel,
      primary: colors.brass,
      onPrimary: colors.onBrass,
      error: colors.emit,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }

  static ThemeData buildDarkTheme() => _build(AppColors.dark, Brightness.dark);
  static ThemeData buildLightTheme() =>
      _build(AppColors.light, Brightness.light);
}
