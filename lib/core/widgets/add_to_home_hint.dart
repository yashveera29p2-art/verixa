import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../platform/web_bridge.dart';
import '../theme/theme.dart';
import 'glass_popup.dart';

const _key = 'verixa.homeHintClosed';

/// iPhone web app opened in a Safari tab (not from the home screen): a
/// small glass card at the top with the "Add to Home Screen" steps, so
/// people don't need to go back to the download page. Close it with ✕.
class AddToHomeHint extends StatefulWidget {
  const AddToHomeHint({super.key, required this.child});

  final Widget child;

  @override
  State<AddToHomeHint> createState() => _AddToHomeHintState();
}

class _AddToHomeHintState extends State<AddToHomeHint> {
  late bool _show = kIsWeb &&
      RegExp('iPhone|iPad|iPod').hasMatch(browserUserAgent) &&
      !isStandaloneWebApp &&
      storageGet(_key) == null;

  void _close() {
    storageSet(_key, '1');
    setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return widget.child;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: top + AppSpacing.xs,
          child: GlassPanel(
            radius: AppRadius.lg,
            frost: 1.6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.add_to_home_screen,
                      color: AppColors.botanicalGreen),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.charcoal,
                          height: 1.35,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Install Verixa: ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: 'tap Share ⬆︎ in Safari (or ⋯ then Share), '
                                'then "Add to Home Screen".',
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Plain tap target: this card sits above the navigator,
                  // where tooltips have no overlay to show in.
                  Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(Icons.close,
                            size: 20, color: AppColors.mutedText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
