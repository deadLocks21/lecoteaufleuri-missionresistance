import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/config/timings.dart';
import '../../../application/session/session_controller.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/id_plate.dart';
import '../../widgets/k_button.dart';
import '../../widgets/panel_scaffold.dart';

/// Écran de verrouillage (BRIEF §7) : plaque `VERROUILLÉ`, champ LCD interlettré,
/// bouton `Déverrouiller`, shake + halo rouge sur erreur.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: Timings.shake,
  );
  bool _bad = false;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(sessionControllerProvider.notifier).submit(_code.text);
  }

  void _onBadCode() {
    setState(() => _bad = true);
    _shake.forward(from: 0);
    _code.clear();
    _focus.requestFocus();
    Future<void>.delayed(Timings.shake, () {
      if (mounted) setState(() => _bad = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      final wasInvalid = previous is Locked && previous.error == LockError.invalidCode;
      final isInvalid = next is Locked && next.error == LockError.invalidCode;
      if (isInvalid && !wasInvalid) {
        _onBadCode();
      }
    });

    final session = ref.watch(sessionControllerProvider);
    final unlocking = session is Unlocking || session is Unlocked;
    final plateTeam = switch (session) {
      Unlocking(:final team) => team.name,
      Unlocked(:final team) => team.name,
      _ => Strings.locked,
    };

    final (String hint, Color hintColor) = switch (session) {
      Unlocking() || Unlocked() => (Strings.lockHintOk, TsfPalette.green),
      Locked(error: LockError.invalidCode) => (Strings.lockHintBad, TsfPalette.redGlow),
      Locked(error: LockError.network) => (Strings.lockHintNetwork, TsfPalette.amber),
      _ => (Strings.lockHintIdle, TsfPalette.lcdText),
    };

    return PanelScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IdPlate(team: plateTeam),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Strings.lockPrompt,
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 13,
                        color: const Color(0xFFCDBB88),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) {
                        final t = _shake.value;
                        final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 4) * 6 * (1 - t);
                        return Transform.translate(offset: Offset(dx, 0), child: child);
                      },
                      child: _CodeBox(
                        controller: _code,
                        focusNode: _focus,
                        bad: _bad,
                        enabled: !unlocking,
                        onSubmit: _submit,
                      ),
                    ),
                    const SizedBox(height: 14),
                    KButton(
                      Strings.unlock,
                      variant: KButtonVariant.brass,
                      fullWidth: true,
                      onTap: unlocking ? null : _submit,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: AppText.mono(
                        size: 12,
                        color: hintColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.bad,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool bad;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final style = AppText.mono(
      size: 26,
      color: bad ? TsfPalette.redGlow : TsfPalette.lcdText,
      letterSpacing: 8,
      height: 1.1,
    );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: TsfPalette.lcdBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF000000)),
        boxShadow: [
          BoxShadow(
            color: bad
                ? TsfPalette.red.withValues(alpha: 0.6)
                : const Color(0xFF285A14).withValues(alpha: 0.2),
            blurRadius: bad ? 12 : 16,
            spreadRadius: bad ? 0 : -4,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: true,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 12,
        cursorColor: TsfPalette.lcdText,
        keyboardType: TextInputType.text,
        style: style,
        inputFormatters: [_UpperCaseFormatter()],
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          hintText: Strings.codePlaceholder,
          hintStyle: AppText.mono(
            size: 26,
            color: const Color(0xFF2F5A2A),
            letterSpacing: 8,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
