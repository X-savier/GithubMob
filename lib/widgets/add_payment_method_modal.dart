import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/paymongo.dart' show kPaymongoMethodLabels;
import '../services/payment_methods_service.dart';
import '../theme/vxr_theme.dart';
import '../theme/vxr_widgets.dart';

const bool _kMockEnabled =
    bool.fromEnvironment('MOCK_PAYMENTS_ENABLED', defaultValue: false);

const List<String> _kSaveableTypes = [
  'gcash',
  'paymaya',
  'grab_pay',
  'bank_transfer',
];

class AddPaymentMethodModal extends StatefulWidget {
  const AddPaymentMethodModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VxrTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VxrTokens.radiusSheet),
        ),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const AddPaymentMethodModal(),
      ),
    );
  }

  @override
  State<AddPaymentMethodModal> createState() => _AddPaymentMethodModalState();
}

class _AddPaymentMethodModalState extends State<AddPaymentMethodModal> {
  String _type = 'gcash';
  final _label = TextEditingController();
  final _hint = TextEditingController();
  final _billingName = TextEditingController();
  bool _setDefault = false;
  bool _mockMode = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _hint.dispose();
    _billingName.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_type == 'bank_transfer' &&
        _label.text.trim().isEmpty &&
        _hint.text.trim().isEmpty) {
      return 'Provide a label or account hint for bank transfer.';
    }
    return null;
  }

  Future<void> _submit() async {
    final v = _validate();
    if (v != null) {
      setState(() => _error = v);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await addPaymentMethod(
      type: _type,
      label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      accountHint: _hint.text.trim().isEmpty ? null : _hint.text.trim(),
      billingName:
          _billingName.text.trim().isEmpty ? null : _billingName.text.trim(),
      setDefault: _setDefault,
      isMock: _kMockEnabled && _mockMode,
    );
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _saving = false;
        _error = res.error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VxrTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Add Payment Method',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: VxrTokens.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Save an e-wallet or bank for one-tap checkout. Cards are entered fresh at payment time.',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: VxrTokens.textSub,
            ),
          ),
          const SizedBox(height: 16),
          _MethodPickerGrid(
            value: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 16),
          VxrInputField(
            label: 'Label (optional)',
            controller: _label,
            hint: _type == 'bank_transfer' ? 'BPI main' : 'My GCash',
          ),
          const SizedBox(height: 10),
          VxrInputField(
            label: _type == 'bank_transfer'
                ? 'Account hint'
                : 'Mobile / account hint',
            controller: _hint,
            hint: _type == 'bank_transfer' ? 'BPI • •••1234' : '0917 ••• 1234',
          ),
          const SizedBox(height: 10),
          VxrInputField(
            label: 'Billing name (optional)',
            controller: _billingName,
            hint: 'Juan dela Cruz',
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _setDefault,
            onChanged: (v) => setState(() => _setDefault = v),
            title: Text(
              'Set as default',
              style: GoogleFonts.dmSans(
                fontSize: 13.5, fontWeight: FontWeight.w600,
              ),
            ),
            activeColor: VxrTokens.accent,
            contentPadding: EdgeInsets.zero,
          ),
          if (_kMockEnabled)
            SwitchListTile.adaptive(
              value: _mockMode,
              onChanged: (v) => setState(() => _mockMode = v),
              title: Text(
                'Mark as mock (demo)',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                ),
              ),
              activeColor: VxrTokens.warning,
              contentPadding: EdgeInsets.zero,
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: GoogleFonts.dmSans(
                fontSize: 12, color: VxrTokens.danger,
              ),
            ),
          ],
          const SizedBox(height: 16),
          VxrPrimaryButton(
            label: 'Save method',
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _MethodPickerGrid extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _MethodPickerGrid({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      physics: const NeverScrollableScrollPhysics(),
      children: _kSaveableTypes.map((t) {
        final meta = kPaymongoMethodLabels[t];
        final selected = value == t;
        return InkWell(
          onTap: () => onChanged(t),
          borderRadius: BorderRadius.circular(VxrTokens.radius),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? VxrTokens.accentSoft : VxrTokens.surface2,
              borderRadius: BorderRadius.circular(VxrTokens.radius),
              border: Border.all(
                color: selected ? VxrTokens.accent : VxrTokens.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _iconFor(t),
                  size: 18,
                  color: selected ? VxrTokens.accent : VxrTokens.textSub,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meta?.label ?? t,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? VxrTokens.accent : VxrTokens.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'gcash':
      case 'paymaya':
        return Icons.account_balance_wallet_outlined;
      case 'grab_pay':
        return Icons.directions_car_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
    }
    return Icons.payments_outlined;
  }
}
