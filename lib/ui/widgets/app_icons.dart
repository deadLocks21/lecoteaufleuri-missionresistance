import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icônes du poste, rendues depuis les tracés SVG **exacts** du prototype
/// (BRIEF §4.3) via `flutter_svg`. La teinte est appliquée par filtre (srcIn),
/// l'équivalent de `stroke="currentColor"`.
abstract final class AppIcons {
  static const _mic =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="11" rx="3"/><path d="M5 10a7 7 0 0 0 14 0"/><line x1="12" y1="17" x2="12" y2="21"/><line x1="8" y1="21" x2="16" y2="21"/></svg>';

  static const _alert =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 2 20h20L12 3z"/><line x1="12" y1="10" x2="12" y2="14"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>';

  static const _radio =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="2"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4M5 5a10 10 0 0 0 0 14M19 5a10 10 0 0 1 0 14"/></svg>';

  static const _carnet =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1"/><line x1="8" y1="9" x2="16" y2="9"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="13" y2="17"/></svg>';

  static const _lock =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';

  static const _play =
      '<svg viewBox="0 0 24 24" fill="#000"><path d="M8 5v14l11-7z"/></svg>';

  static const _chevron =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>';

  static Widget _icon(String svg, double size, Color color) => SvgPicture.string(
        svg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );

  static Widget mic(double size, Color color) => _icon(_mic, size, color);
  static Widget alert(double size, Color color) => _icon(_alert, size, color);
  static Widget radio(double size, Color color) => _icon(_radio, size, color);
  static Widget carnet(double size, Color color) => _icon(_carnet, size, color);
  static Widget lock(double size, Color color) => _icon(_lock, size, color);
  static Widget play(double size, Color color) => _icon(_play, size, color);
  static Widget chevron(double size, Color color) => _icon(_chevron, size, color);
}
