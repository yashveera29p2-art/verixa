import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/resume_version.dart';

/// A mini A4 page that sketches a template's layout with placeholder text
/// and lines, so users see the format before creating the resume.
/// Cross-fades when the template changes.
class TemplatePreview extends StatelessWidget {
  const TemplatePreview({super.key, required this.template});

  final ResumeTemplate template;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: AspectRatio(
          aspectRatio: 1 / 1.414, // A4
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.stone),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.97, end: 1.0).animate(a),
                    child: child,
                  ),
                ),
                // Laid out on a small fixed page, then scaled to fit, so
                // it looks the same on every screen size.
                child: SizedBox.expand(
                  key: ValueKey(template),
                  child: FittedBox(
                    child: SizedBox(
                      width: 200,
                      height: 283,
                      child: switch (template) {
                        ResumeTemplate.classic => const _ClassicPage(),
                        ResumeTemplate.modern => const _ModernPage(),
                        ResumeTemplate.compact => const _CompactPage(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _ink = AppColors.charcoal;
const _green = AppColors.botanicalGreen;
final _line = AppColors.stone;

/// Grey placeholder text line; [w] is the fraction of the available width.
class _Bar extends StatelessWidget {
  const _Bar(this.w, {this.h = 3, this.color});

  final double w;
  final double h;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: w,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: color ?? _line,
          borderRadius: BorderRadius.circular(h),
        ),
      ),
    ),
  );
}

Widget _tiny(
  String text, {
  Color color = _ink,
  double size = 6.5,
  bool bold = true,
}) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.clip,
  style: TextStyle(
    fontFamily: AppTypography.bodyMedium.fontFamily,
    fontSize: size,
    height: 1.2,
    letterSpacing: 0.6,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
  ),
);

/// Placeholder body of one section: a title line and a few text lines.
List<Widget> _entry({bool dense = false}) => [
  _Bar(0.55, h: 3.5, color: AppColors.mutedText.withValues(alpha: 0.45)),
  const _Bar(0.95),
  const _Bar(0.88),
  if (!dense) const _Bar(0.7),
  SizedBox(height: dense ? 3 : 5),
];

/// Classic: centred serif name, ruled small-caps headings, single column.
class _ClassicPage extends StatelessWidget {
  const _ClassicPage();

  Widget _heading(String t) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tiny(t),
        const SizedBox(height: 1.5),
        Container(height: 0.8, color: _ink),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        children: [
          Text(
            'Your Name',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 15,
              color: _ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          _tiny('city · phone · email · linkedin', bold: false, size: 5.5),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('SUMMARY'),
                const _Bar(1),
                const _Bar(0.9),
                _heading('EDUCATION'),
                ..._entry(dense: true),
                _heading('EXPERIENCE'),
                ..._entry(),
                _heading('PROJECTS'),
                ..._entry(),
                _heading('SKILLS'),
                const _Bar(0.9),
                const _Bar(0.6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern: green header band, green headings, skill tags.
class _ModernPage extends StatelessWidget {
  const _ModernPage();

  Widget _heading(String t) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Row(
      children: [
        Container(width: 3, height: 8, color: _green),
        const SizedBox(width: 4),
        _tiny(t, color: _green),
      ],
    ),
  );

  Widget _tag(double w) => Container(
    width: w,
    height: 9,
    decoration: BoxDecoration(
      color: _green.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _green.withValues(alpha: 0.6), width: 0.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: _green,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Name',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 15,
                  color: AppColors.ivory,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              _tiny('Target role', color: AppColors.softSage, size: 6),
              const SizedBox(height: 3),
              _tiny(
                'city · phone · email · github',
                color: AppColors.ivory,
                bold: false,
                size: 5.5,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Summary'),
                const _Bar(1),
                const _Bar(0.85),
                _heading('Skills'),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final w in const <double>[26, 34, 22, 30, 40, 24])
                      _tag(w),
                  ],
                ),
                const SizedBox(height: 3),
                _heading('Projects'),
                ..._entry(),
                _heading('Experience'),
                ..._entry(),
                _heading('Education'),
                ..._entry(dense: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact: section titles in a left column, dense rows.
class _CompactPage extends StatelessWidget {
  const _CompactPage();

  Widget _row(String t, List<Widget> body) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 52, child: _tiny(t, size: 5.8)),
        Container(width: 0.8, height: 30, color: _line),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: body,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Your Name',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 13,
                  color: _ink,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              _tiny('phone · email', bold: false, size: 5.5),
            ],
          ),
          const SizedBox(height: 3),
          Container(height: 1, color: _ink),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              children: [
                _row('SUMMARY', const [_Bar(1), _Bar(0.8)]),
                _row('EDUCATION', _entry(dense: true)),
                _row('EXPERIENCE', [
                  ..._entry(dense: true),
                  ..._entry(dense: true),
                ]),
                _row('PROJECTS', [
                  ..._entry(dense: true),
                  ..._entry(dense: true),
                ]),
                _row('SKILLS', const [_Bar(0.95), _Bar(0.7)]),
                _row('EXTRAS', const [_Bar(0.8), _Bar(0.5)]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
