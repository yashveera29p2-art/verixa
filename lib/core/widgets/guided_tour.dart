import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// One stop of the guided tour: what to point at and what to say.
class TourStep {
  const TourStep({required this.target, required this.title, required this.body});

  final GlobalKey target;
  final String title;
  final String body;
}

/// Walks through [steps] one at a time: the screen dims, the option is
/// highlighted, and a small message bubble points at it with Skip and
/// Next / Got it. Steps whose option isn't on screen are skipped.
/// Completes when the user finishes or skips.
/// The guide on screen right now; the next one waits for it.
Future<void>? _showing;

Future<void> showGuidedTour(BuildContext context, List<TourStep> steps) async {
  // One guide at a time: wait for any guide already on screen.
  while (_showing != null) {
    await _showing;
  }
  if (!context.mounted) return;
  final visible = steps.where((s) => s.target.currentContext != null).toList();
  if (visible.isEmpty) return;
  final run = _run(context, visible);
  _showing = run;
  try {
    await run;
  } finally {
    if (identical(_showing, run)) _showing = null;
  }
}

Future<void> _run(BuildContext context, List<TourStep> visible) async {
  // An overlay, not a page: pushing a page would fade out the screen the
  // tour is pointing at.
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Tour(
      steps: visible,
      onDone: () {
        entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return done.future;
}

class _Tour extends StatefulWidget {
  const _Tour({required this.steps, required this.onDone});

  final List<TourStep> steps;
  final VoidCallback onDone;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int _i = 0;

  Rect? _targetRect() {
    final box = widget.steps[_i].target.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _next() {
    if (_i < widget.steps.length - 1) {
      setState(() => _i++);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final size = MediaQuery.sizeOf(context);
    final target = _targetRect() ?? Rect.fromCenter(
      center: size.center(Offset.zero), width: 0, height: 0);
    final hole = target.inflate(6);
    // Bubble goes below the option if there's room, otherwise above.
    final below = hole.center.dy < size.height * 0.55;
    const bubbleWidth = 300.0;
    final left = (hole.center.dx - bubbleWidth / 2)
        .clamp(AppSpacing.md, size.width - bubbleWidth - AppSpacing.md);
    final arrowX = (hole.center.dx - left).clamp(20.0, bubbleWidth - 20.0);
    final last = _i == widget.steps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim everything except the highlighted option.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // taps outside the bubble do nothing
              child: CustomPaint(painter: _DimPainter(hole)),
            ),
          ),
          AnimatedPositioned(
            duration: AppMotion.page,
            curve: Curves.easeOutCubic,
            left: left,
            width: bubbleWidth,
            top: below ? hole.bottom + 10 : null,
            bottom: below ? null : size.height - hole.top + 10,
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              child: _Bubble(
                key: ValueKey(_i),
                step: step,
                index: _i,
                count: widget.steps.length,
                arrowX: arrowX,
                arrowUp: below,
                last: last,
                onNext: _next,
                onSkip: widget.onDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(18)));
    canvas.drawPath(path, Paint()..color = AppColors.charcoal.withValues(alpha: 0.45));
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ivory,
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}

/// Solid ivory message card with a thin green border and an arrow.
class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.arrowX,
    required this.arrowUp,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final double arrowX;
  final bool arrowUp;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 2, AppSpacing.sm, AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.botanicalGreen, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${index + 1} of $count',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.botanicalGreen,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(step.title,
              style: AppTypography.titleLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            step.body,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.charcoal,
              height: 1.4,
            ),
          ),
          Row(
            children: [
              if (!last)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mutedText,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Skip'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.botanicalGreen,
                  foregroundColor: AppColors.ivory,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: Text(last ? 'Got it' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
    final arrow = Padding(
      padding: EdgeInsets.only(left: arrowX - 9),
      child: CustomPaint(size: const Size(18, 9), painter: _ArrowPainter(up: arrowUp)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: arrowUp ? [arrow, card] : [card, arrow],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.up});

  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
          ..moveTo(0, size.height + 1)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height + 1))
        : (Path()
          ..moveTo(0, -1)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, -1));
    canvas.drawPath(path, Paint()..color = AppColors.ivory);
    canvas.drawPath(
      up
          ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
          : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.botanicalGreen,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up;
}
