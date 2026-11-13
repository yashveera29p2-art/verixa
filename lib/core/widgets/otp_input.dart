import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// A 6-box one-time-code field.
///
/// One real (invisible) TextField takes the input, so paste, SMS autofill
/// and backspace all work; the boxes just draw its current text.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final int length;
  final bool hasError;
  final bool enabled;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    // While a code is checked the field is disabled and loses focus; give
    // it back (and the keyboard) when it's enabled again, e.g. after a
    // wrong code, so the user can type straight away.
    if (!old.enabled && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus();
      });
    }
  }

  /// Focuses the hidden field with the caret at the end, and makes sure
  /// the keyboard is showing even if the field already had focus.
  void _focus() {
    final c = widget.controller;
    c.selection = TextSelection.collapsed(offset: c.text.length);
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onChanged(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focus : null,
      child: Stack(
        children: [
          // The real input, kept transparent behind the boxes.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: true,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
              onChanged: _onChanged,
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < widget.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs),
                    child: _OtpBox(
                      digit: i < text.length ? text[i] : '',
                      isActive: _focusNode.hasFocus &&
                          (i == text.length ||
                              (i == widget.length - 1 &&
                                  text.length == widget.length)),
                      hasError: widget.hasError,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  final String digit;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.charcoal
        : isActive
            ? AppColors.botanicalGreen
            : AppColors.stone;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: borderColor,
          width: isActive || hasError ? 1.5 : AppSizes.borderWidth,
        ),
      ),
      child: Text(digit, style: AppTypography.headlineMedium),
    );
  }
}
