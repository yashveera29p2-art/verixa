import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../profile/domain/profile_data.dart';
import '../../../profile/domain/profile_section.dart';
import '../../domain/parsed_resume.dart';

/// One section found in the resume, with a tick box and a short preview.
class ImportSectionCard extends StatelessWidget {
  const ImportSectionCard({
    super.key,
    required this.section,
    required this.result,
    required this.selected,
    required this.onToggle,
  });

  final ProfileSection section;
  final ParsedResume result;
  final bool selected;
  final VoidCallback onToggle;

  List<String> get _preview {
    final r = result;
    String join(Iterable<String> parts) =>
        parts.where((p) => p.trim().isNotEmpty).join(' · ');
    return switch (section) {
      ProfileSection.contact => [
        join([r.contact.fullName, r.contact.city]),
        join([r.email, r.phone]),
        join([r.contact.linkedin, r.contact.github]),
      ],
      ProfileSection.status => [
        join([r.degree.degree, r.degree.branch]),
        join([
          r.degree.college,
          if (r.degree.cgpa.isNotEmpty) 'CGPA ${r.degree.cgpa}',
          r.degree.graduationYear,
        ]),
      ],
      ProfileSection.education => [
        if (r.education.class12.year.isNotEmpty ||
            r.education.class12.score.isNotEmpty)
          join([
            '12th',
            r.education.class12.school,
            r.education.class12.score,
            r.education.class12.year,
          ]),
        if (r.education.class10.year.isNotEmpty ||
            r.education.class10.score.isNotEmpty)
          join([
            '10th',
            r.education.class10.school,
            r.education.class10.score,
            r.education.class10.year,
          ]),
        for (final q in r.education.additional)
          join([q.qualification, q.institution, q.year]),
      ],
      ProfileSection.careerGoal => [r.careerGoal.objective],
      ProfileSection.experience => [
        for (final e in r.experience) join([e.role, e.company, e.duration]),
      ],
      ProfileSection.projects => [
        for (final p in r.projects)
          join([p.title, p.techStack.take(4).join(', ')]),
      ],
      ProfileSection.skills => [
        [...r.skills.technical, ...r.skills.tools].take(12).join(', '),
        if (r.skills.soft.isNotEmpty) 'Soft: ${r.skills.soft.join(', ')}',
        if (r.skills.languages.isNotEmpty)
          'Languages: ${r.skills.languages.join(', ')}',
      ],
      ProfileSection.extras => [
        for (final entry in r.extras.lists.entries)
          if (entry.value.isNotEmpty)
            '${Extras.fields[entry.key]}: ${entry.value.length}',
      ],
    }.where((l) => l.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _preview;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? AppColors.botanicalGreen : AppColors.stone,
          width: selected ? 1.5 : AppSizes.borderWidth,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(section.icon, color: AppColors.botanicalGreen),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppTypography.labelLarge.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    for (final line in lines.take(4))
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall,
                      ),
                    if (lines.length > 4)
                      Text(
                        '+ ${lines.length - 4} more',
                        style: AppTypography.bodySmall,
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.botanicalGreen,
                side: const BorderSide(color: AppColors.softSage, width: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
