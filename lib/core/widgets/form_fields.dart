import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// Small uppercase label that starts a group of fields, e.g. "12TH".
class FormGroupLabel extends StatelessWidget {
  const FormGroupLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.botanicalGreen),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A themed text field with a floating label, spaced for forms.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.capitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType ??
            (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        textCapitalization: capitalization,
        maxLines: maxLines,
        minLines: 1,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: AppTypography.bodyLarge,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperStyle: AppTypography.bodySmall,
          errorText: errorText,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

/// Two fields side by side (e.g. Score + Year).
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );
  }
}

/// Type a value, tap + (or press enter) to add it as a chip; tap × to
/// remove. Used for skills, tech stack and extras.
class ChipListField extends StatefulWidget {
  const ChipListField({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.hint,
    this.maxItems = 30,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String? hint;
  final int maxItems;

  @override
  State<ChipListField> createState() => _ChipListFieldState();
}

class _ChipListFieldState extends State<ChipListField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    _controller.clear();
    if (value.isEmpty) return;
    final exists =
        widget.values.any((v) => v.toLowerCase() == value.toLowerCase());
    if (exists || widget.values.length >= widget.maxItems) return;
    widget.onChanged([...widget.values, value]);
  }

  void _remove(String value) =>
      widget.onChanged(widget.values.where((v) => v != value).toList());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodyLarge,
            // onEditingComplete (instead of onSubmitted) keeps the keyboard
            // open after Enter, so several items can be added in a row.
            onEditingComplete: _add,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              suffixIcon: IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.add, color: AppColors.botanicalGreen),
                onPressed: _add,
              ),
            ),
          ),
          if (widget.values.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final v in widget.values)
                  InputChip(
                    label: Text(v),
                    labelStyle: AppTypography.bodyMedium
                        .copyWith(color: AppColors.ivory),
                    backgroundColor: AppColors.botanicalGreen,
                    deleteIconColor: AppColors.ivory,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    onDeleted: () => _remove(v),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A row of selectable options; the chosen one fills with botanical green.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(labelOf(option)),
              selected: option == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(option),
              labelStyle: AppTypography.labelLarge.copyWith(
                color: option == selected
                    ? AppColors.ivory
                    : AppColors.charcoal,
              ),
              selectedColor: AppColors.botanicalGreen,
              backgroundColor: AppColors.white,
              side: BorderSide(
                color: option == selected
                    ? AppColors.botanicalGreen
                    : AppColors.stone,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "Remove" text button shown next to an entry's heading.
class RemoveButton extends StatelessWidget {
  const RemoveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Remove'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.mutedText,
        textStyle: AppTypography.labelMedium,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// "+ Add internship" style text button.
class AddEntryButton extends StatelessWidget {
  const AddEntryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 20),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.botanicalGreen,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        ),
      ),
    );
  }
}
