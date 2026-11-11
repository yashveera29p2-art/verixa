import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/data/auth_errors.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Section 1: name, location, links, optional date of birth and Gmail.
class ContactEditor extends ConsumerStatefulWidget {
  const ContactEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends ConsumerState<ContactEditor> {
  late final _name = TextEditingController(text: widget.data.contact.fullName);
  late final _city = TextEditingController(text: widget.data.contact.city);
  late final _state = TextEditingController(text: widget.data.contact.state);
  late final _linkedin =
      TextEditingController(text: widget.data.contact.linkedin);
  late final _github = TextEditingController(text: widget.data.contact.github);
  late final _portfolio =
      TextEditingController(text: widget.data.contact.portfolio);
  late DateTime? _dob = widget.data.contact.dateOfBirth;
  String? _nameError;
  bool _linking = false;

  @override
  void dispose() {
    for (final c in [_name, _city, _state, _linkedin, _github, _portfolio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _save() async {
    final nameError =
        _name.text.trim().length < 2 ? 'Please enter your full name.' : null;
    setState(() => _nameError = nameError);
    if (nameError != null) return false;

    final contact = ContactInfo(
      fullName: _name.text,
      city: _city.text,
      state: _state.text,
      linkedin: _linkedin.text,
      github: _github.text,
      portfolio: _portfolio.text,
      dateOfBirth: _dob,
    );
    return ref
        .read(profileSaveControllerProvider.notifier)
        .save((uid, repo) => repo.saveContact(uid, contact));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 14),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _linkGoogle() async {
    setState(() => _linking = true);
    try {
      await ref.read(authServiceProvider).linkGoogleAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google account linked.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    ref.watch(authStateProvider); // rebuild after linking
    final googleEmail = auth.currentUser?.providerData
        .where((p) => p.providerId == 'google.com')
        .map((p) => p.email)
        .firstOrNull;

    return EditorPage(
      section: ProfileSection.contact,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'How recruiters will reach and find you.',
      onSave: _save,
      children: [
        LabeledTextField(
          controller: _name,
          label: 'Full name',
          capitalization: TextCapitalization.words,
          errorText: _nameError,
        ),
        FieldRow(
          left: LabeledTextField(
            controller: _city,
            label: 'City',
            capitalization: TextCapitalization.words,
          ),
          right: LabeledTextField(
            controller: _state,
            label: 'State',
            capitalization: TextCapitalization.words,
          ),
        ),
        const FormGroupLabel('Links'),
        LabeledTextField(
          controller: _linkedin,
          label: 'LinkedIn',
          hint: 'linkedin.com/in/your-name',
          keyboardType: TextInputType.url,
          capitalization: TextCapitalization.none,
        ),
        LabeledTextField(
          controller: _github,
          label: 'GitHub',
          hint: 'github.com/your-name',
          keyboardType: TextInputType.url,
          capitalization: TextCapitalization.none,
        ),
        LabeledTextField(
          controller: _portfolio,
          label: 'Portfolio (optional)',
          keyboardType: TextInputType.url,
          capitalization: TextCapitalization.none,
        ),
        const FormGroupLabel('Optional'),
        _DobRow(date: _dob, onPick: _pickDob, onClear: () => setState(() => _dob = null)),
        const SizedBox(height: AppSpacing.sm),
        _GmailRow(email: googleEmail, linking: _linking, onLink: _linkGoogle),
      ],
    );
  }
}

class _DobRow extends StatelessWidget {
  const _DobRow({required this.date, required this.onPick, required this.onClear});

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = date == null
        ? 'Add date of birth'
        : 'Date of birth: ${date!.day}/${date!.month}/${date!.year}';
    return Row(
      children: [
        const Icon(Icons.cake_outlined, color: AppColors.botanicalGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: AppColors.charcoal,
              textStyle: AppTypography.bodyLarge,
            ),
            child: Text(text),
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, color: AppColors.mutedText),
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// Gmail is optional (CLAUDE.md §3.2); linking happens here.
class _GmailRow extends StatelessWidget {
  const _GmailRow({
    required this.email,
    required this.linking,
    required this.onLink,
  });

  final String? email;
  final bool linking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.mail_outline, color: AppColors.botanicalGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: email != null
              ? Text('Gmail linked: $email', style: AppTypography.bodyLarge)
              : Text('Gmail not linked', style: AppTypography.bodyLarge),
        ),
        if (email == null)
          TextButton(
            onPressed: linking ? null : onLink,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.botanicalGreen,
              textStyle: AppTypography.labelLarge,
            ),
            child: Text(linking ? 'Linking…' : 'Link Google'),
          ),
      ],
    );
  }
}
