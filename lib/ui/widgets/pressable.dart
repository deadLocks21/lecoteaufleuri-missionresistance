import 'package:flutter/widgets.dart';

/// Comportement « touche physique » : enfoncement au pressé (BRIEF §4.4).
/// Expose l'état `pressed` au builder pour permuter dégradé/ombres.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, this.onTap});

  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap,
      child: widget.builder(_pressed),
    );
  }
}
