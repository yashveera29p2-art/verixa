import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../../../core/widgets/form_fields.dart';
import '../../companies/application/company_providers.dart';
import '../../companies/domain/company.dart';
import '../application/resume_builder_controller.dart';
import '../domain/resume_version.dart';

/// Pick what to tailor a new resume for (feature 9).
class NewResumeScreen extends ConsumerStatefulWidget {
  const NewResumeScreen({super.key, this.companyId});

  /// Preselects "Company" with this company (from company detail).
  final String? companyId;

  @override
  ConsumerState<NewResumeScreen> createState() => _NewResumeScreenState();
}

class _NewResumeScreenState extends ConsumerState<NewResumeScreen> {
  final _name = TextEditingController();
  final _jd = TextEditingController();
  late ResumeTargetKind _kind = widget.companyId == null
      ? ResumeTargetKind.general
      : ResumeTargetKind.company;
  ResumeTemplate _template = ResumeTemplate.classic;
  late String? _companyId = widget.companyId;
  String? _localError;

  @override
  void dispose() {
    _name.dispose();
    _jd.dispose();
    super.dispose();
  }

  Future<void> _create(List<Company> companies) async {
    Company? company;
    if (_kind == ResumeTargetKind.company) {
      company = companies.where((c) => c.id == _companyId).firstOrNull;
      if (company == null) {
        setState(() => _localError = 'Choose a company.');
        return;
      }
    }
    setState(() => _localError = null);
    final id = await ref
        .read(newResumeControllerProvider.notifier)
        .create(
          NewResumeRequest(
            name: _name.text,
            targetKind: _kind,
            template: _template,
            company: company,
            jobDescription: _jd.text,
          ),
        );
    if (id != null && mounted) {
      context.pushReplacement(AppRoutes.resumeEdit(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newResumeControllerProvider);
    final companies =
        ref.watch(allCompaniesProvider).value ?? const <Company>[];
    final error =
        _localError ?? (state.hasError ? state.error.toString() : null);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AuthPage(
        title: 'New resume',
        subtitle: const Text(
          'Built only from your profile. Pick what to tailor it for — we '
          'reorder sections and highlight the skills you genuinely have.',
        ),
        bottom: AppButton(
          label: _kind == ResumeTargetKind.job
              ? 'Match & create'
              : 'Create resume',
          isLoading: state.isLoading,
          onPressed: () => _create(companies),
        ),
        children: [
          const FormGroupLabel('Tailor for'),
          ChoiceChips<ResumeTargetKind>(
            options: ResumeTargetKind.values,
            selected: _kind,
            labelOf: (k) => k.label,
            onSelected: (k) => setState(() => _kind = k),
          ),
          if (_kind == ResumeTargetKind.company)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DropdownButtonFormField<String>(
                initialValue: _companyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Company'),
                items: [
                  for (final c in companies)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.name} · ${c.category.title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _companyId = id),
              ),
            ),
          if (_kind == ResumeTargetKind.job)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TextField(
                controller: _jd,
                minLines: 6,
                maxLines: 12,
                maxLength: 20000,
                style: AppTypography.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Job description',
                  hintText:
                      'Paste the job title, responsibilities and requirements…',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          LabeledTextField(
            controller: _name,
            label: 'Version name (optional)',
            hint: 'e.g. Infosys – SDE, Backend internship',
          ),
          const FormGroupLabel('Template'),
          ChoiceChips<ResumeTemplate>(
            options: ResumeTemplate.values,
            selected: _template,
            labelOf: (t) => t.label,
            onSelected: (t) => setState(() => _template = t),
          ),
          Text(_template.description, style: AppTypography.bodySmall),
          InlineError(error),
        ],
      ),
    );
  }
}
