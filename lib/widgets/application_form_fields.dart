import 'package:flutter/material.dart';

import '../theme/vxr_theme.dart';
import '../theme/vxr_widgets.dart';

// Form-field building blocks shared between the multi-step
// RentalApplicationScreen and the single-page ApplicationEditScreen.
// Keeping these in one place ensures the rental and edit flows render
// the same input chrome and run the same validators.

const double kAppRadius = 14.0;
const double kAppCardPadding = 20.0;
const double kAppFieldSpacing = 14.0;

/// Employment statuses that hide the job/income detail fields.
/// Matches `INCOME_STATUS_NO_DETAILS` in the web validation module.
const Set<String> kIncomeNoDetails = {'Unemployed', 'Student', 'Retired'};

/// 5-option employment-length dropdown (same options reused for rental
/// duration in Step 3).
const List<String> kEmploymentLengths = [
  'Less than 6 months',
  '6 months – 1 year',
  '1 – 2 years',
  '2 – 5 years',
  '5+ years',
];

const List<String> kRentalDurations = kEmploymentLengths;

String? requiredValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'This field is required' : null;

/// Card container with title used for each step section.
class ApplicationFormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ApplicationFormCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(kAppRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(kAppCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: VxrTokens.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class ApplicationTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const ApplicationTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: VxrTokens.textSub,
              letterSpacing: 0.1,
            ),
            children: [
              if (validator != null)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: VxrTokens.accent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(
            fontSize: 14,
            color: VxrTokens.text,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: VxrTokens.textMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: VxrTokens.surface2,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 14 : 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VxrTokens.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VxrTokens.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: VxrTokens.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VxrTokens.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: VxrTokens.danger, width: 1.5),
            ),
            errorStyle:
                const TextStyle(fontSize: 11, color: VxrTokens.danger),
          ),
        ),
      ],
    );
  }
}

class ApplicationDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const ApplicationDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: VxrTokens.textSub,
            ),
            children: [
              if (validator != null)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: VxrTokens.accent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          validator: validator,
          hint: Text(hint,
              style: const TextStyle(
                  color: VxrTokens.textMuted, fontSize: 13.5)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: VxrTokens.textSub, size: 20),
          decoration: InputDecoration(
            filled: true,
            fillColor: VxrTokens.surface2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VxrTokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VxrTokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: VxrTokens.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VxrTokens.danger),
            ),
            errorStyle:
                const TextStyle(fontSize: 11, color: VxrTokens.danger),
          ),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 14, color: VxrTokens.text)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Date picker bound to a controller. Stores yyyy-MM-dd into the
/// controller's text.
class ApplicationDateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialDate;
  final String? Function(String?)? validator;

  const ApplicationDateField({
    super.key,
    required this.label,
    required this.controller,
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return ApplicationTextField(
      label: label,
      hint: 'yyyy-mm-dd',
      controller: controller,
      readOnly: true,
      validator: validator,
      suffixIcon: const Icon(Icons.calendar_today_rounded,
          size: 18, color: VxrTokens.textSub),
      onTap: () async {
        // Parse existing text so the picker re-opens at the right date.
        DateTime initial = initialDate;
        final existing = controller.text.trim();
        if (existing.isNotEmpty) {
          final parsed = DateTime.tryParse(existing);
          if (parsed != null) initial = parsed;
        }
        if (initial.isBefore(firstDate)) initial = firstDate;
        if (initial.isAfter(lastDate)) initial = lastDate;
        final date = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (c, child) => Theme(
            data: Theme.of(c).copyWith(
              colorScheme: const ColorScheme.light(primary: VxrTokens.accent),
            ),
            child: child!,
          ),
        );
        if (date != null) {
          controller.text =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }
}

/// Standard back/next button row used between steps.
class ApplicationStepNav extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String nextLabel;

  const ApplicationStepNav({
    super.key,
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: VxrSecondaryButton(label: 'Back', onPressed: onBack),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: VxrPrimaryButton(
            label: nextLabel,
            onPressed: onNext,
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}
