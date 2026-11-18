import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/app_button.dart';
import '../auth/application/auth_providers.dart';
import '../profile/application/profile_providers.dart';
import '../profile/domain/profile_data.dart';
import '../resume/domain/match_report.dart' show matchProfileJson;

/// The five work-style traits from the quiz (ids match the backend).
enum Trait {
  teamwork('Teamwork', 'Works well with and through others'),
  ownership('Ownership', 'Takes responsibility and sees things through'),
  structure('Structure', 'Plans, organises and pays attention to detail'),
  communication('Communication', 'Explains ideas clearly, speaks up'),
  adaptability('Adaptability', 'Comfortable with change and new things');

  const Trait(this.label, this.meaning);
  final String label;
  final String meaning;
}

class _Q {
  const _Q(this.text, this.trait, {this.reverse = false});
  final String text;
  final Trait trait;
  final bool reverse;
}

/// 15 short statements, three per trait (one reverse-worded each), based on
/// widely used Big Five-style work-preference items.
const _questions = [
  _Q('I enjoy working on tasks with others more than alone.', Trait.teamwork),
  _Q('When a teammate is stuck, I stop to help them.', Trait.teamwork),
  _Q('I prefer that others don’t depend on my part of the work.', Trait.teamwork, reverse: true),
  _Q('I finish what I start, even when it gets boring.', Trait.ownership),
  _Q('If something breaks in my work, I fix it without being asked.', Trait.ownership),
  _Q('I wait for someone to tell me what to do next.', Trait.ownership, reverse: true),
  _Q('I plan my work before I start.', Trait.structure),
  _Q('I double-check details before I submit something.', Trait.structure),
  _Q('My notes and files are usually messy.', Trait.structure, reverse: true),
  _Q('I can explain a technical idea to someone non-technical.', Trait.communication),
  _Q('I speak up in meetings or class discussions.', Trait.communication),
  _Q('I find it hard to write clear messages or emails.', Trait.communication, reverse: true),
  _Q('I like trying new tools and ways of working.', Trait.adaptability),
  _Q('Sudden changes of plan don’t bother me much.', Trait.adaptability),
  _Q('I get stressed when I have to learn something new quickly.', Trait.adaptability, reverse: true),
];

/// Quiz results and recruiter visibility, from `users/{uid}`.
class WorkStyle {
  const WorkStyle({this.traits = const {}, this.visible = false});

  /// Trait name → 0..100. Empty until the quiz is taken.
  final Map<String, double> traits;
  final bool visible;

  bool get taken => traits.isNotEmpty;

  /// The two strongest traits, e.g. "Ownership · Structure".
  String get summary {
    final top = traits.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return top.take(2).map((e) => Trait.values.byName(e.key).label).join(' · ');
  }
}

final workStyleProvider = StreamProvider<WorkStyle>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const WorkStyle());
  return ref.watch(firestoreProvider).collection('users').doc(uid).snapshots().map((s) {
    final d = s.data() ?? const {};
    final t = (d['workStyle'] as Map?)?['traits'] as Map?;
    return WorkStyle(
      traits: {for (final e in (t ?? const {}).entries) e.key as String: (e.value as num).toDouble()},
      visible: d['visibleToRecruiters'] == true,
    );
  });
});

/// Writes / removes the student's card that recruiters can see.
class CandidateSync {
  CandidateSync(this._db);

  final FirebaseFirestore _db;

  Future<void> setVisible(String uid, bool visible, ProfileData? profile,
      Map<String, double> traits) async {
    await _db.collection('users').doc(uid).set(
        {'visibleToRecruiters': visible}, SetOptions(merge: true));
    if (!visible || profile == null) {
      await _db.collection('candidates').doc(uid).delete();
      return;
    }
    await publish(uid, profile, traits);
  }

  Future<void> publish(String uid, ProfileData p, Map<String, double> traits) {
    final s = p.statusDetails;
    return _db.collection('candidates').doc(uid).set({
      'fullName': p.contact.fullName,
      'college': s.college,
      'degree': s.degree,
      'branch': s.branch,
      'graduationYear': s.graduationYear,
      'city': [p.contact.city, p.contact.state].where((x) => x.isNotEmpty).join(', '),
      'targetRole': p.careerGoal.targetRole.isNotEmpty ? p.careerGoal.targetRole : s.targetRole,
      'skills': [...p.skills.technical, ...p.skills.tools].take(30).toList(),
      'projectTitles': p.projects.map((x) => x.title).where((x) => x.isNotEmpty).take(8).toList(),
      'links': [p.contact.linkedin, p.contact.github, p.contact.portfolio]
          .where((x) => x.isNotEmpty)
          .toList(),
      'traits': traits,
      'matchProfile': matchProfileJson(p),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final candidateSyncProvider =
    Provider<CandidateSync>((ref) => CandidateSync(ref.watch(firestoreProvider)));

/// 15 statements, 1–5 agreement, 2 minutes.
class WorkStyleQuizScreen extends ConsumerStatefulWidget {
  const WorkStyleQuizScreen({super.key});

  @override
  ConsumerState<WorkStyleQuizScreen> createState() => _WorkStyleQuizScreenState();
}

class _WorkStyleQuizScreenState extends ConsumerState<WorkStyleQuizScreen> {
  final _answers = <int, int>{};
  bool _saving = false;

  Map<String, double> _score() {
    final sums = {for (final t in Trait.values) t: <int>[]};
    for (final e in _answers.entries) {
      final q = _questions[e.key];
      sums[q.trait]!.add(q.reverse ? 6 - e.value : e.value);
    }
    return {
      for (final e in sums.entries)
        e.key.name: e.value.isEmpty
            ? 50
            : ((e.value.reduce((a, b) => a + b) / e.value.length - 1) / 4 * 100)
                .roundToDouble(),
    };
  }

  Future<void> _save() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    final traits = _score();
    try {
      await ref.read(firestoreProvider).collection('users').doc(user.uid).set({
        'workStyle': {'traits': traits, 'takenAt': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
      // Keep the recruiter card current if the student is visible.
      final ws = ref.read(workStyleProvider).value;
      final profile = ref.read(profileDataProvider).value;
      if (ws?.visible == true && profile != null) {
        await ref.read(candidateSyncProvider).publish(user.uid, profile, traits);
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t save. Check your connection.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _answers.length == _questions.length;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter, 0, AppSpacing.pageGutter, AppSpacing.md),
        child: AppButton(
          label: done ? 'See my work style' : '${_answers.length} of ${_questions.length} answered',
          isLoading: _saving,
          onPressed: done ? _save : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter, 0, AppSpacing.pageGutter, AppSpacing.xl),
        children: [
          Text('Your work style', style: AppTypography.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How much do you agree? There are no right answers. Recruiters '
            'only see the result if you turn on “Visible to recruiters”.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _questions.length; i++) ...[
            Text('${i + 1}. ${_questions[i].text}', style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (var v = 1; v <= 5; v++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text('$v', textAlign: TextAlign.center),
                        ),
                        selected: _answers[i] == v,
                        onSelected: (_) => setState(() => _answers[i] = v),
                        showCheckmark: false,
                        selectedColor: AppColors.botanicalGreen,
                        backgroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.stone),
                        labelStyle: AppTypography.labelLarge.copyWith(
                          color: _answers[i] == v ? AppColors.ivory : AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Disagree', style: AppTypography.bodySmall),
                  Text('Agree', style: AppTypography.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Five labelled bars, 0–100.
class TraitBars extends StatelessWidget {
  const TraitBars({super.key, required this.traits});

  final Map<String, double> traits;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in Trait.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 108, child: Text(t.label, style: AppTypography.bodySmall)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (traits[t.name] ?? 0) / 100,
                      minHeight: 8,
                      color: AppColors.botanicalGreen,
                      backgroundColor: AppColors.stone,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${(traits[t.name] ?? 0).round()}',
                      textAlign: TextAlign.end, style: AppTypography.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
