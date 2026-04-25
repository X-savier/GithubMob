import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'in_stay_dashboard_screen.dart';
import 'property_data.dart';

/// Tenant-facing payment hub. Two modes:
///
/// 1. **Contract mode** (constructed with [contractId] + [amountPhp]):
///    pay a specific contract. Renders a focused Pay button for that
///    contract. Used from `ContractViewScreen.proceedToPayment`.
/// 2. **Overview mode** (no constructor args): shows the tenant's
///    next due contract, lifetime totals, and payment history. Pay
///    button targets the next due contract; hidden when nothing is
///    pending.
class PaymentScreen extends StatefulWidget {
  /// Optional contract this payment is settling. When provided, the
  /// post-payment handler will record the payment row + advance the
  /// contract status to 'paid'.
  final String? contractId;

  /// Total amount to charge in PHP (peso, not cents). Stripe payment
  /// intent is created server-side using `(amountPhp * 100).round()`.
  final double? amountPhp;

  /// Display label rendered in the upcoming-payment card.
  final String? summaryLabel;

  const PaymentScreen({
    super.key,
    this.contractId,
    this.amountPhp,
    this.summaryLabel,
  });

  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color lightOrange = Color(0xFFFFF3E0);
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color borderColor = Color(0xFFEEEEEE);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color pendingOrange = Color(0xFFFF9800);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = true;
  Map<String, dynamic>? _nextDue;
  List<Map<String, dynamic>> _payments = [];
  int _totalPaidCents = 0;

  /// What the Pay button should target: contract-mode params win,
  /// otherwise fall back to the next-due contract pulled from DB.
  String? get _payContractId =>
      widget.contractId ?? _nextDue?['id']?.toString();
  double get _payAmountPhp {
    if (widget.amountPhp != null) return widget.amountPhp!;
    if (_nextDue == null) return 0.0;
    final rent = (_nextDue!['monthly_rent'] as num?)?.toDouble() ?? 0.0;
    final dep = (_nextDue!['security_deposit'] as num?)?.toDouble() ?? 0.0;
    final adv = (_nextDue!['advance_payment'] as num?)?.toDouble() ?? 0.0;
    return rent + dep + adv;
  }

  String get _payListingTitle {
    final t = _nextDue?['listings']?['title']?.toString();
    if (t != null && t.isNotEmpty) return t;
    return widget.summaryLabel ?? 'Rental';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      fetchMyPaymentsWithContext(),
      fetchMyNextDueContract(),
    ]);
    final payments = results[0] as List<Map<String, dynamic>>;
    final next = results[1] as Map<String, dynamic>?;
    int total = 0;
    for (final p in payments) {
      if ((p['status'] ?? '') == 'succeeded') {
        total += ((p['amount_cents'] as num?)?.toInt() ?? 0);
      }
    }
    if (!mounted) return;
    setState(() {
      _payments = payments;
      _nextDue = next;
      _totalPaidCents = total;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: PaymentScreen.darkText,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PaymentScreen.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: PaymentScreen.darkText),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _upcomingCard(),
                  const SizedBox(height: 20),
                  _totalsRow(),
                  const SizedBox(height: 16),
                  _methodCard(),
                  const SizedBox(height: 20),
                  _historyCard(),
                  const SizedBox(height: 20),
                  if (_payContractId != null && _payAmountPhp > 0)
                    _payCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────

  Widget _upcomingCard() {
    final hasDue = _payContractId != null && _payAmountPhp > 0;
    final due = hasDue
        ? 'Your next payment of ₱${_payAmountPhp.toStringAsFixed(2)} '
            'for $_payListingTitle is due now.'
        : 'No pending payments. You\'re all caught up.';
    final iconColor =
        hasDue ? PaymentScreen.primaryOrange : PaymentScreen.successGreen;
    final bgColor =
        hasDue ? PaymentScreen.lightOrange : const Color(0xFFE8F5E9);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDue ? Icons.notifications_active : Icons.check_circle,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasDue ? 'Upcoming Payment Reminder' : 'Up to date',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: PaymentScreen.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            due,
            style: const TextStyle(
              fontSize: 14,
              color: PaymentScreen.lightText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsRow() {
    final paid = '₱${(_totalPaidCents / 100).toStringAsFixed(2)}';
    final pending = _payAmountPhp > 0
        ? '₱${_payAmountPhp.toStringAsFixed(2)}'
        : '₱0.00';
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total Paid',
            value: paid,
            color: PaymentScreen.successGreen,
            sub: 'All completed payments',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Pending Payments',
            value: pending,
            color: PaymentScreen.pendingOrange,
            sub: _payAmountPhp > 0 ? 'Awaiting payment' : 'Nothing pending',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentScreen.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: PaymentScreen.lightText)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(
                  fontSize: 12, color: PaymentScreen.lightText)),
        ],
      ),
    );
  }

  Widget _methodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentScreen.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PaymentScreen.lightOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.credit_card,
                color: PaymentScreen.primaryOrange, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Method',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: PaymentScreen.lightText)),
                SizedBox(height: 4),
                Text('Card via Stripe',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: PaymentScreen.darkText)),
                Text('Sandbox — test cards only',
                    style: TextStyle(
                        fontSize: 12, color: PaymentScreen.lightText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentScreen.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaction History',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PaymentScreen.darkText)),
          const SizedBox(height: 4),
          const Text('All recorded payments on your account',
              style: TextStyle(
                  fontSize: 14, color: PaymentScreen.lightText)),
          const SizedBox(height: 16),
          if (_payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No payments yet.',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: PaymentScreen.borderColor),
                  ),
                  child: Row(
                    children: [
                      _buildTableHeader('Date', flex: 2),
                      _buildTableHeader('Property', flex: 3),
                      _buildTableHeader('Amount', flex: 2),
                      _buildTableHeader('Status', flex: 2),
                    ],
                  ),
                ),
                for (int i = 0; i < _payments.length; i++)
                  _txRow(_payments[i], i == _payments.length - 1),
              ],
            ),
        ],
      ),
    );
  }

  Widget _txRow(Map<String, dynamic> p, bool isLast) {
    final paidAt = p['paid_at']?.toString();
    final dateText = _formatDate(paidAt);
    final cents = ((p['amount_cents'] as num?)?.toInt() ?? 0);
    final amount = '₱${(cents / 100).toStringAsFixed(2)}';
    final status = (p['status'] ?? 'succeeded').toString();
    final statusColor = switch (status) {
      'succeeded' => PaymentScreen.successGreen,
      'pending' => PaymentScreen.pendingOrange,
      'refunded' => Colors.blueGrey,
      _ => Colors.redAccent,
    };
    final listingTitle =
        p['contract']?['listings']?['title']?.toString() ?? 'Listing';

    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: PaymentScreen.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(dateText, style: _txStyle())),
          Expanded(
              flex: 3,
              child: Text(listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _txStyle())),
          Expanded(
              flex: 2,
              child: Text(amount,
                  style: _txStyle().copyWith(fontWeight: FontWeight.w600))),
          Expanded(
            flex: 2,
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: _txStyle().copyWith(
                  color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _txStyle() =>
      const TextStyle(fontSize: 12, color: PaymentScreen.darkText);

  Widget _payCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentScreen.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Property',
                        style: TextStyle(
                            fontSize: 14,
                            color: PaymentScreen.lightText)),
                    const SizedBox(height: 4),
                    Text(_payListingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PaymentScreen.darkText)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount Due',
                        style: TextStyle(
                            fontSize: 14,
                            color: PaymentScreen.lightText)),
                    const SizedBox(height: 4),
                    Text('₱${_payAmountPhp.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PaymentScreen.primaryOrange)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StripePayButton(
            contractId: _payContractId,
            amountPhp: _payAmountPhp,
            onSuccess: _refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: PaymentScreen.lightText,
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─────────────────────────────────────────────
// STRIPE SANDBOX PAY BUTTON
// ─────────────────────────────────────────────

/// Calls the create-payment-intent Edge Function, presents Stripe's
/// PaymentSheet, and on success records the payment + flips the contract
/// status to 'paid' via [recordPayment].
class _StripePayButton extends StatefulWidget {
  final String? contractId;
  final double amountPhp;
  final VoidCallback? onSuccess;
  const _StripePayButton({
    required this.contractId,
    required this.amountPhp,
    this.onSuccess,
  });

  @override
  State<_StripePayButton> createState() => _StripePayButtonState();
}

class _StripePayButtonState extends State<_StripePayButton> {
  bool _busy = false;

  Future<void> _onPay() async {
    setState(() => _busy = true);
    try {
      final amountCents = (widget.amountPhp * 100).round();
      final res = await Supabase.instance.client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount_cents': amountCents,
          'currency': 'php',
          if (widget.contractId != null) 'contract_id': widget.contractId,
        },
      );
      final data = (res.data as Map?)?.cast<String, dynamic>();
      final clientSecret = data?['client_secret']?.toString();
      final paymentIntentId = data?['payment_intent_id']?.toString();
      if (clientSecret == null || paymentIntentId == null) {
        throw Exception('Edge function returned no client_secret');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ViewxRent',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      if (widget.contractId != null) {
        await recordPayment(
          contractId: widget.contractId!,
          paymentIntentId: paymentIntentId,
          amountCents: amountCents,
          currency: 'php',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful.')),
      );
      widget.onSuccess?.call();
      // Move the tenant straight into the in-stay dashboard so the
      // post-payment flow is obvious — they immediately see their
      // active rental, next due date, and quick actions.
      if (widget.contractId != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const InStayDashboardScreen(),
          ),
        );
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Payment cancelled: ${e.error.localizedMessage ?? ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = 'Pay ₱ ${widget.amountPhp.toStringAsFixed(2)} Now';
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _busy ? null : _onPay,
        style: ElevatedButton.styleFrom(
          backgroundColor: PaymentScreen.primaryOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
