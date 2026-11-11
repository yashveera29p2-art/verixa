import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'career_goal_editor.dart';
import 'contact_editor.dart';
import 'education_editor.dart';
import 'experience_editor.dart';
import 'extras_editor.dart';
import 'projects_editor.dart';
import 'skills_editor.dart';
import 'status_editor.dart';

/// Loads the profile, then shows the editor for one [section].
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.section,
    this.guided = false,
  });

  final ProfileSection section;
  final bool guided;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  @override
  void initState() {
    super.initState();
    // Clear any error left over from a previous editor.
    Future.microtask(
        () => ref.read(profileSaveControllerProvider.notifier).reset());
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileDataProvider);
    final data = profile.value;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: profile.hasError
              ? Text('Couldn’t load your profile.',
                  style: AppTypography.bodyLarge)
              : const CircularProgressIndicator(
                  color: AppColors.botanicalGreen),
        ),
      );
    }
    return _editorFor(widget.section, data, widget.guided);
  }

  Widget _editorFor(ProfileSection section, ProfileData data, bool guided) =>
      switch (section) {
        ProfileSection.contact => ContactEditor(data: data, guided: guided),
        ProfileSection.status => StatusEditor(data: data, guided: guided),
        ProfileSection.education => EducationEditor(data: data, guided: guided),
        ProfileSection.careerGoal =>
          CareerGoalEditor(data: data, guided: guided),
        ProfileSection.experience =>
          ExperienceEditor(data: data, guided: guided),
        ProfileSection.projects => ProjectsEditor(data: data, guided: guided),
        ProfileSection.skills => SkillsEditor(data: data, guided: guided),
        ProfileSection.extras => ExtrasEditor(data: data, guided: guided),
      };
}
