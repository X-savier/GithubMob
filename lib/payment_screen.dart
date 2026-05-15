import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'contract_payment_screen.dart';
import 'services/payments_service.dart';
import 'services/payment_methods_service.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'widgets/add_payment_method_modal.dart';

class PaymentScreen extends StatefulWidget {
  /// When provided, the Overview tab includes this specific contract at the
  /// top of the actionable list. When null, the screen is hub mode.
  final String? contractId;
  final int? amountPhp;

  const PaymentScreen({super.key, this.contractId, this.amountPhp});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loading = true;
  NextDueContract? _next;
  List<InProgressContract> _inProgress = const [];
  List<PaymentTransactionRow> _history = const [];
  List<SavedPaymentMethod> _methods = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        fetchMyNextDueContract(),
        fetchMyInProgressContracts(),
        fetchMyPaymentsWithContext(),
        listMyPaymentMethods(),
      ]);
      if (!mounted) return;
      _next = results[0] as NextDueContract?;
      _inProgress = results[1] as List<InProgressContract>;
      _history = results[2] as List<PaymentTransactionRow>;
      _methods = results[3] as List<SavedPaymentMethod>;
    } catch (_) {/* show empty states */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: VxrAppBar(
        title: 'Payments',
        subtitle: 'Rent, deposits & receipts',
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Methods'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: VxrTokens.accent,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(
                    next: _next,
                    inProgress: _inProgress,
                    history: _history,
                    contractIdOverride: widget.contractId,
                    amountOverride: widget.amountPhp,
                    onPaid: _load,
                  ),
                  _HistoryTab(rows: _history),
                  _MethodsTab(methods: _methods, onChanged: _load),
                ],
              ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final NextDueContract? next;
  final List<InProgressContract> inProgress;
  final List<PaymentTransactionRow> history;
  final String? contractIdOverride;
  final int? amountOverride;
  final VoidCallback onPaid;
  const _OverviewTab({
    required this.next,
    required this.inProgress,
    required this.history,
    required this.contractIdOverride,
    required this.amountOverride,
    required this.onPaid,
  });

  int get _totalPaidCents => history
      .where((r) => r.status == 'succeeded')
      .fold<int>(0, (acc, r) => acc + r.amountCents);

  int get _outstandingCents => next?.totalDueCents ?? 0;

  @override
  Widget build(BuildContext context) {
    final overrideContract =
        contractIdOverride != null && amountOverride != null
            ? _ContractActionData(
                id: contractIdOverride!,
                title: null,
                totalCents: amountOverride! * 100,
                status: 'fully_signed',
              )
            : null;

    final actionContracts = <_ContractActionData>[
      if (overrideContract != null) overrideContract,
      ...inProgress.map(
        (c) => _ContractActionData(
          id: c.id,
          title: c.listingTitle,
          totalCents: c.totalDueCents,
          status: c.status,
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'TOTAL PAID',
                value: '₱${_formatPeso(_totalPaidCents / 100)}',
                color: VxrTokens.success,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'OUTSTANDING',
                value: '₱${_formatPeso(_outstandingCents / 100)}',
                color: VxrTokens.accent,
                icon: Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Actionable contracts',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: VxrTokens.text,
          ),
        ),
        const SizedBox(height: 8),
        if (actionContracts.isEmpty)
          const _EmptyState(
            icon: Icons.check_circle_outline,
            title: "You're all caught up",
            body: 'No active contracts need attention right now.',
          )
        else
          ...actionContracts.map((c) => _ContractActionCard(
                data: c,
                onPay: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContractPaymentScreen(
                        contractId: c.id,
                        amountPhp: (c.totalCents / 100).round(),
                        listingTitle: c.title,
                      ),
                    ),
                  );
                  onPaid();
                },
              )),
      ],
    );
  }
}

class _ContractActionData {
  final String id;
  final String? title;
  final int totalCents;
  final String status;
  const _ContractActionData({
    required this.id,
    required this.title,
    required this.totalCents,
    required this.status,
  });
}

class _ContractActionCard extends StatelessWidget {
  final _ContractActionData data;
  final VoidCallback onPay;
  const _ContractActionCard({required this.data, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final readyToPay = data.status == 'fully_signed';
    final awaitingTenant = data.status == 'awaiting_tenant';
    final label = readyToPay
        ? 'Ready to pay'
        : awaitingTenant
            ? 'Sign needed'
            : 'Waiting on landlord';
    final color = readyToPay
        ? VxrTokens.success
        : awaitingTenant
            ? VxrTokens.warning
            : VxrTokens.textSub;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title ??
                      'Contract ${data.id.substring(0, data.id.length.clamp(0, 6))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: VxrTokens.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₱${_formatPeso(data.totalCents / 100)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: VxrTokens.accent,
            ),
          ),
          const SizedBox(height: 12),
          if (readyToPay)
            VxrPrimaryButton(
              label: 'Pay now',
              icon: Icons.lock_outline,
              onPressed: onPay,
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  color: VxrTokens.textSub,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: VxrTokens.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  final List<PaymentTransactionRow> rows;
  const _HistoryTab({required this.rows});
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String? _status;

  List<PaymentTransactionRow> get _filtered {
    if (_status == null) return widget.rows;
    return widget.rows.where((r) => r.status == _status).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 30),
          _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            body: 'Your transaction history will show up here.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          children: [
            _filterChip('All', null),
            _filterChip('Succeeded', 'succeeded'),
            _filterChip('Pending', 'pending'),
            _filterChip('Failed', 'failed'),
            _filterChip('Refunded', 'refunded'),
          ],
        ),
        const SizedBox(height: 12),
        ..._filtered.map((r) => _HistoryRow(row: r)),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _status == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: selected ? Colors.white : VxrTokens.text,
      ),
      selectedColor: VxrTokens.accent,
      backgroundColor: VxrTokens.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
        side: BorderSide(
            color: selected ? VxrTokens.accent : VxrTokens.border),
      ),
      onSelected: (_) => setState(() => _status = value),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final PaymentTransactionRow row;
  const _HistoryRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(row.status);
    final paid = row.paidAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: VxrTokens.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long,
                color: VxrTokens.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.listingTitle ?? 'Property',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VxrTokens.text,
                  ),
                ),
                Text(
                  paid == null ? '—' : '${paid.toLocal()}'.split('.').first,
                  style: GoogleFonts.dmSans(
                    fontSize: 11, color: VxrTokens.textSub,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${_formatPeso(row.amountCents / 100)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: VxrTokens.text,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
                ),
                child: Text(
                  row.status,
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'succeeded':
        return VxrTokens.success;
      case 'pending':
      case 'requires_action':
        return VxrTokens.warning;
      case 'failed':
        return VxrTokens.danger;
      case 'refunded':
      case 'cancelled':
        return VxrTokens.textSub;
    }
    return VxrTokens.textSub;
  }
}

class _MethodsTab extends StatelessWidget {
  final List<SavedPaymentMethod> methods;
  final VoidCallback onChanged;
  const _MethodsTab({required this.methods, required this.onChanged});

  Future<void> _delete(BuildContext context, SavedPaymentMethod m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove method?'),
        content: Text('Remove ${m.label ?? m.type} from saved methods?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final res = await deletePaymentMethod(m.id);
      if (res.ok) onChanged();
    }
  }

  Future<void> _setDefault(SavedPaymentMethod m) async {
    final res = await setDefaultPaymentMethod(m.id);
    if (res.ok) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        VxrPrimaryButton(
          label: 'Add payment method',
          icon: Icons.add,
          onPressed: () async {
            final added = await AddPaymentMethodModal.show(context);
            if (added == true) onChanged();
          },
        ),
        const SizedBox(height: 16),
        if (methods.isEmpty)
          const _EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No saved methods',
            body: 'Save GCash, Maya, GrabPay, or bank for one-tap checkout.',
          )
        else
          ...methods.map(
            (m) => _MethodRow(
              method: m,
              onSetDefault: () => _setDefault(m),
              onDelete: () => _delete(context, m),
            ),
          ),
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  final SavedPaymentMethod method;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;
  const _MethodRow({
    required this.method,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
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
                    Flexible(
                      child: Text(
                        method.label ?? method.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: VxrTokens.text,
                        ),
                      ),
                    ),
                    if (method.isDefault) ...[
                      const SizedBox(width: 6),
                      const _StatusPill(label: 'Default', color: VxrTokens.success),
                    ],
                    if (method.isMock) ...[
                      const SizedBox(width: 6),
                      const _StatusPill(label: 'Mock', color: VxrTokens.warning),
                    ],
                  ],
                ),
                if ((method.accountHint ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      method.accountHint!,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        color: VxrTokens.textSub,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: VxrTokens.textSub),
            onSelected: (v) {
              if (v == 'default') onSetDefault();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              if (!method.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Text('Set as default'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});
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
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: VxrTokens.accentSoft,
                borderRadius: BorderRadius.circular(VxrTokens.radius),
              ),
              child: Icon(icon, color: VxrTokens.accent, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: VxrTokens.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: VxrTokens.textSub,
              ),
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
