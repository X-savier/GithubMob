import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'services/paymongo.dart';
import 'services/payments_service.dart';
import 'services/payment_methods_service.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'widgets/add_payment_method_modal.dart';

const bool _kMockEnabled =
    bool.fromEnvironment('MOCK_PAYMENTS_ENABLED', defaultValue: false);
const String _kReturnUrl = 'https://viewxrent.app/payment-return';

const List<String> _kEwalletTypes = ['gcash', 'paymaya', 'grab_pay'];

enum _Step { form, processing, success }

class ContractPaymentScreen extends StatefulWidget {
  final String contractId;
  final int amountPhp;
  final String? listingTitle;
  final int? monthlyRent;
  final int? securityDeposit;
  final int? advancePayment;

  const ContractPaymentScreen({
    super.key,
    required this.contractId,
    required this.amountPhp,
    this.listingTitle,
    this.monthlyRent,
    this.securityDeposit,
    this.advancePayment,
  });

  @override
  State<ContractPaymentScreen> createState() => _ContractPaymentScreenState();
}

class _ContractPaymentScreenState extends State<ContractPaymentScreen> {
  _Step _step = _Step.form;
  String? _error;
  Map<String, dynamic>? _intent;
  List<SavedPaymentMethod> _saved = const [];
  SavedPaymentMethod? _selectedSaved;
  String _newType = 'card';
  bool _useMock = false;
  String? _successPaymentIntentId;

  final _cardNumber = TextEditingController();
  final _cardExp = TextEditingController();
  final _cardCvc = TextEditingController();
  final _billingName = TextEditingController();
  final _billingEmail = TextEditingController();
  final _billingPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _cardNumber.dispose();
    _cardExp.dispose();
    _cardCvc.dispose();
    _billingName.dispose();
    _billingEmail.dispose();
    _billingPhone.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _selectedSaved = null;
    final results = await Future.wait([
      createPaymongoPaymentIntent(widget.contractId),
      listMyPaymentMethods(),
    ]);
    if (!mounted) return;
    final intentRes = results[0] as PaymentsResult<Map<String, dynamic>>;
    final methods = results[1] as List<SavedPaymentMethod>;
    setState(() {
      _saved = methods;
      _selectedSaved = methods.isEmpty
          ? null
          : methods.firstWhere((m) => m.isDefault, orElse: () => methods.first);
      if (intentRes.ok) {
        _intent = intentRes.data;
      } else {
        _error = intentRes.error;
      }
    });
  }

  Future<void> _refreshMethods() async {
    final methods = await listMyPaymentMethods();
    if (!mounted) return;
    setState(() {
      _saved = methods;
      _selectedSaved ??= methods.isEmpty
          ? null
          : methods.firstWhere((m) => m.isDefault, orElse: () => methods.first);
    });
  }

  int get _total => widget.amountPhp;
  bool get _canPay => _intent != null && _step == _Step.form && _error == null;

  String get _intentId => (_intent?['paymentIntentId'] ?? '').toString();

  Future<void> _pay() async {
    if (!_canPay) return;
    setState(() {
      _step = _Step.processing;
      _error = null;
    });

    try {
      if (_useMock && _kMockEnabled) {
        if (_selectedSaved == null) {
          throw 'Pick or add a saved method first to use mock mode.';
        }
        final res = await recordMockPayment(
          contractId: widget.contractId,
          paymentMethodRecordId: _selectedSaved!.id,
        );
        if (!res.ok) throw res.error ?? 'Mock payment failed';
        setState(() {
          _successPaymentIntentId = 'mock';
          _step = _Step.success;
        });
        return;
      }

      // Determine the PayMongo PaymentMethod to attach.
      Map<String, dynamic> pm;
      String typeForAttach;
      if (_selectedSaved != null) {
        // Saved e-wallet/bank — recreate a PayMongo method for it on the fly.
        typeForAttach = _selectedSaved!.type;
        pm = await createEwalletPaymentMethod(
          type: typeForAttach,
          billing: _billingFromSaved(_selectedSaved!),
        );
      } else if (_newType == 'card') {
        typeForAttach = 'card';
        pm = await createCardPaymentMethod(
          card: _parseCard(),
          billing: _billingFromForm(),
        );
      } else {
        typeForAttach = _newType;
        pm = await createEwalletPaymentMethod(
          type: _newType,
          billing: _billingFromForm(),
        );
      }
      final pmId = pm['id'].toString();

      final attach = await attachPaymentMethod(
        paymentIntentId: _intentId,
        paymentMethodId: pmId,
        returnUrl: _kReturnUrl,
        paymentMethodRecordId: _selectedSaved?.id,
      );
      if (!attach.ok) throw attach.error ?? 'Attach failed';
      final status = (attach.data?['status'] ?? '').toString();
      final nextAction = attach.data?['next_action'];
      final redirectUrl = nextAction is Map
          ? (nextAction['redirect']?['url'] ?? nextAction['redirect_url'])
              ?.toString()
          : null;

      if (status == 'succeeded') {
        await _finalize(_intentId);
        return;
      }

      if (status == 'awaiting_next_action' || redirectUrl != null) {
        if (redirectUrl == null) throw 'Missing redirect URL';
        final redirected = await _runRedirectFlow(redirectUrl);
        if (!redirected) {
          setState(() {
            _step = _Step.form;
            _error = 'Payment was cancelled.';
          });
          return;
        }
        await _finalize(_intentId);
        return;
      }

      throw 'Unexpected PayMongo status: $status';
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.form;
        _error = e.toString();
      });
    }
  }

  Future<void> _finalize(String intentId) async {
    final res = await recordPaymongoPayment(widget.contractId, intentId);
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _step = _Step.form;
        _error = res.error;
      });
      return;
    }
    setState(() {
      _successPaymentIntentId = intentId;
      _step = _Step.success;
    });
  }

  Future<bool> _runRedirectFlow(String redirectUrl) async {
    final controller = WebViewController();
    final completer = ValueNotifier<bool?>(null);
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (req) {
        if (req.url.startsWith(_kReturnUrl)) {
          completer.value = true;
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ));
    await controller.loadRequest(Uri.parse(redirectUrl));
    if (!mounted) return false;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RedirectWebView(
          controller: controller,
          completion: completer,
        ),
      ),
    );
    return ok == true;
  }

  PaymongoCard _parseCard() {
    final exp = _cardExp.text.trim();
    final parts = exp.split(RegExp(r'[/\s]'));
    if (parts.length < 2) throw 'Card expiry must be MM/YY';
    final m = int.tryParse(parts[0]) ?? 0;
    var y = int.tryParse(parts[1]) ?? 0;
    if (y < 100) y += 2000;
    return PaymongoCard(
      number: _cardNumber.text,
      expMonth: m,
      expYear: y,
      cvc: _cardCvc.text.trim(),
    );
  }

  PaymongoBilling _billingFromForm() => PaymongoBilling(
        name: _billingName.text.trim(),
        email: _billingEmail.text.trim(),
        phone: _billingPhone.text.trim(),
      );

  PaymongoBilling _billingFromSaved(SavedPaymentMethod m) => PaymongoBilling(
        name: m.billingName ??
            Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']
                ?.toString(),
        email: Supabase.instance.client.auth.currentUser?.email,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: VxrAppBar(
        title: 'Pay your move-in',
        subtitle: widget.listingTitle ?? 'Secure checkout',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: _step == _Step.success
            ? _SuccessView(
                amount: _total,
                intentId: _successPaymentIntentId ?? '',
                listingTitle: widget.listingTitle,
                onDone: () => Navigator.of(context).pop(true),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _OrderSummaryCard(
                    listingTitle: widget.listingTitle,
                    monthlyRent: widget.monthlyRent ?? _total,
                    securityDeposit: widget.securityDeposit ?? 0,
                    advancePayment: widget.advancePayment ?? 0,
                    total: _total,
                  ),
                  const SizedBox(height: 16),
                  if (_intent == null && _error != null)
                    _ErrorBanner(message: _error!),
                  if (_intent != null) ...[
                    _SavedMethodsSection(
                      saved: _saved,
                      selected: _selectedSaved,
                      onSelect: (m) =>
                          setState(() => _selectedSaved = m),
                      onAdd: () async {
                        final added =
                            await AddPaymentMethodModal.show(context);
                        if (added == true) await _refreshMethods();
                      },
                    ),
                    const SizedBox(height: 16),
                    _NewMethodSection(
                      type: _newType,
                      onChanged: (t) {
                        setState(() {
                          _newType = t;
                          _selectedSaved = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedSaved == null && _newType == 'card')
                      _CardForm(
                        number: _cardNumber,
                        exp: _cardExp,
                        cvc: _cardCvc,
                      ),
                    if (_selectedSaved == null) ...[
                      const SizedBox(height: 12),
                      _BillingForm(
                        name: _billingName,
                        email: _billingEmail,
                        phone: _billingPhone,
                      ),
                    ],
                    if (_kMockEnabled) ...[
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: _useMock,
                        onChanged: (v) => setState(() => _useMock = v),
                        title: Text(
                          'Use mock payment (demo)',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5, fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Bypasses PayMongo. Requires a saved method.',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5, color: VxrTokens.textSub,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 20),
                    VxrPrimaryButton(
                      label: _step == _Step.processing
                          ? 'Processing…'
                          : 'Pay ₱${_formatPeso(_total)}',
                      loading: _step == _Step.processing,
                      onPressed: _canPay ? _pay : null,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 12, color: VxrTokens.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Secured by PayMongo',
                            style: GoogleFonts.dmSans(
                              fontSize: 11, color: VxrTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}

String _formatPeso(num amount) {
  final whole = amount.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return buf.toString();
}

class _OrderSummaryCard extends StatelessWidget {
  final String? listingTitle;
  final int monthlyRent;
  final int securityDeposit;
  final int advancePayment;
  final int total;
  const _OrderSummaryCard({
    required this.listingTitle,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.advancePayment,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (listingTitle != null && listingTitle!.isNotEmpty) ...[
            Text(
              listingTitle!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: VxrTokens.text,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _row('First month rent', monthlyRent),
          _row('Security deposit', securityDeposit),
          _row('Advance rent', advancePayment),
          const Divider(height: 18, color: VxrTokens.border),
          _row('Total', total, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, int amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: bold ? 14 : 12.5,
                color: bold ? VxrTokens.text : VxrTokens.textSub,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₱${_formatPeso(amount)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: bold ? 16 : 13,
              color: bold ? VxrTokens.accent : VxrTokens.text,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMethodsSection extends StatelessWidget {
  final List<SavedPaymentMethod> saved;
  final SavedPaymentMethod? selected;
  final ValueChanged<SavedPaymentMethod?> onSelect;
  final VoidCallback onAdd;
  const _SavedMethodsSection({
    required this.saved,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Saved methods',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: VxrTokens.text,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16, color: VxrTokens.accent),
              label: Text(
                'Add',
                style: GoogleFonts.dmSans(
                    color: VxrTokens.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (saved.isEmpty)
          Text(
            'No saved methods yet.',
            style: GoogleFonts.dmSans(
                fontSize: 12, color: VxrTokens.textSub),
          )
        else
          ...saved.map(
            (m) => _SavedMethodTile(
              method: m,
              selected: selected?.id == m.id,
              onTap: () => onSelect(m),
            ),
          ),
      ],
    );
  }
}

class _SavedMethodTile extends StatelessWidget {
  final SavedPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  const _SavedMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = kPaymongoMethodLabels[method.type];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? VxrTokens.accentSoft : VxrTokens.surface,
            borderRadius: BorderRadius.circular(VxrTokens.radius),
            border: Border.all(
              color: selected ? VxrTokens.accent : VxrTokens.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: VxrTokens.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          method.label ?? meta?.label ?? method.type,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: VxrTokens.text),
                        ),
                        if (method.isDefault) ...[
                          const SizedBox(width: 6),
                          _Pill(label: 'Default', color: VxrTokens.success),
                        ],
                        if (method.isMock) ...[
                          const SizedBox(width: 6),
                          _Pill(label: 'Mock', color: VxrTokens.warning),
                        ],
                      ],
                    ),
                    if ((method.accountHint ?? '').isNotEmpty)
                      Text(
                        method.accountHint!,
                        style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: VxrTokens.textSub),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? VxrTokens.accent : VxrTokens.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9.5,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _NewMethodSection extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  const _NewMethodSection({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = ['card', ..._kEwalletTypes, 'bank_transfer'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or pay with a new method',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: VxrTokens.text,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final meta = kPaymongoMethodLabels[t];
            final selected = type == t;
            return ChoiceChip(
              selected: selected,
              label: Text(meta?.label ?? t),
              labelStyle: GoogleFonts.dmSans(
                color: selected ? Colors.white : VxrTokens.text,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              selectedColor: VxrTokens.accent,
              backgroundColor: VxrTokens.surface2,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(VxrTokens.radiusPill),
                side: BorderSide(
                  color: selected ? VxrTokens.accent : VxrTokens.border,
                ),
              ),
              onSelected: (_) => onChanged(t),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CardForm extends StatelessWidget {
  final TextEditingController number;
  final TextEditingController exp;
  final TextEditingController cvc;
  const _CardForm({
    required this.number,
    required this.exp,
    required this.cvc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VxrInputField(
          label: 'Card number',
          hint: '4343 4343 4343 4345',
          controller: number,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.credit_card,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: VxrInputField(
                label: 'Expiry (MM/YY)',
                hint: '12/29',
                controller: exp,
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VxrInputField(
                label: 'CVC',
                hint: '123',
                controller: cvc,
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BillingForm extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  const _BillingForm({
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: VxrTokens.text,
          ),
        ),
        const SizedBox(height: 8),
        VxrInputField(
          label: 'Name',
          hint: 'Juan dela Cruz',
          controller: name,
        ),
        const SizedBox(height: 10),
        VxrInputField(
          label: 'Email (optional)',
          hint: 'juan@example.com',
          controller: email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        VxrInputField(
          label: 'Phone (optional)',
          hint: '+63 917 ••• ••••',
          controller: phone,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VxrTokens.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: VxrTokens.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: VxrTokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final int amount;
  final String intentId;
  final String? listingTitle;
  final VoidCallback onDone;
  const _SuccessView({
    required this.amount,
    required this.intentId,
    required this.listingTitle,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VxrTokens.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(42),
            ),
            child: const Icon(Icons.check_circle,
                color: VxrTokens.success, size: 48),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Payment successful',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: VxrTokens.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '₱${_formatPeso(amount)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: VxrTokens.accent,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VxrTokens.surface,
              borderRadius: BorderRadius.circular(VxrTokens.radius),
              border: Border.all(color: VxrTokens.border),
            ),
            child: Column(
              children: [
                _row('Listing', listingTitle ?? '—'),
                _row('Transaction', intentId),
                _row(
                  'Paid at',
                  DateTime.now().toLocal().toString().split('.').first,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          VxrPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: GoogleFonts.dmSans(
                fontSize: 12, color: VxrTokens.textSub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: VxrTokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedirectWebView extends StatefulWidget {
  final WebViewController controller;
  final ValueNotifier<bool?> completion;
  const _RedirectWebView({
    required this.controller,
    required this.completion,
  });

  @override
  State<_RedirectWebView> createState() => _RedirectWebViewState();
}

class _RedirectWebViewState extends State<_RedirectWebView> {
  @override
  void initState() {
    super.initState();
    widget.completion.addListener(_onComplete);
  }

  @override
  void dispose() {
    widget.completion.removeListener(_onComplete);
    super.dispose();
  }

  void _onComplete() {
    if (widget.completion.value == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        backgroundColor: VxrTokens.surface,
        foregroundColor: VxrTokens.text,
        elevation: 0.5,
        title: Text(
          'Authorize payment',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: VxrTokens.text,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: WebViewWidget(controller: widget.controller),
    );
  }
}

// keep the import used to silence analyzer if SystemChrome is referenced later
// ignore: unused_element
void _noopHaptic() => HapticFeedback.lightImpact();
