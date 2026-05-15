import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';

import 'property_data.dart';
import 'relist_prompt_screen.dart';

/// Landlord-only Move-Out Checklist.
///
/// All four gates must pass before Close Contract is enabled:
///   1. contract.status ∈ {terminating, ended}
///   2. tenant_vacated_confirmed_at IS NOT NULL
///   3. No open/in-progress reports  OR  reports_carry_over_ack = true
///   4. outstanding_balance = 0      OR  outstanding_balance_waived = true
class MoveOutChecklistScreen extends StatefulWidget {
  final String contractId;
  final String listingId;

  const MoveOutChecklistScreen({
    super.key,
    required this.contractId,
    required this.listingId,
  });

  static const Color brand = VxrTokens.accent;
  static const Color coral = VxrTokens.gradMid;
  static const Color ink = VxrTokens.text;
  static const Color muted = VxrTokens.textSub;
  static const Color bg = VxrTokens.bg;
  static const Color border = VxrTokens.border;
  static const Color success = VxrTokens.success;
  static const Color danger = VxrTokens.danger;
  static const Color warn = VxrTokens.warning;

  @override
  State<MoveOutChecklistScreen> createState() => _MoveOutChecklistScreenState();
}

class _MoveOutChecklistScreenState extends State<MoveOutChecklistScreen> {
  bool _loading = true;
  Map<String, dynamic>? _contract;
  Map<String, dynamic>? _termination;
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _openReports = [];
  Map<String, dynamic> _totals = {};
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final state = await getTerminationState(widget.contractId);
    if (!mounted) return;
    setState(() {
      _contract = state['contract'] as Map<String, dynamic>?;
      _termination = state['termination'] as Map<String, dynamic>?;
      _deductions = (state['deductions'] as List<Map<String, dynamic>>?) ?? [];
      _openReports = (state['openReports'] as List<Map<String, dynamic>>?) ?? [];
      _totals = state['totals'] as Map<String, dynamic>? ?? {};
      _loading = false;
    });
  }

  Map<String, dynamic> get _gates => evaluateMoveOutGates(
        contract: _contract,
        termination: _termination,
        openReports: _openReports,
      );

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoveOutChecklistScreen.bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: const Text('Move-Out Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: MoveOutChecklistScreen.brand))
          : _termination == null
              ? _noTerminationState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: MoveOutChecklistScreen.brand,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _gatesCard(),
                        const SizedBox(height: 16),
                        _depositSummaryCard(),
                        const SizedBox(height: 16),
                        _deductionsCard(),
                        const SizedBox(height: 16),
                        _reportsCard(),
                        const SizedBox(height: 24),
                        _closeContractButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _noTerminationState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No termination record found for this contract.',
          textAlign: TextAlign.center,
          style: TextStyle(color: MoveOutChecklistScreen.muted),
        ),
      ),
    );
  }

  // ── Gate checklist card ───────────────────────────────────────────

  Widget _gatesCard() {
    final g = _gates;
    return _card(
      title: 'Checklist',
      child: Column(
        children: [
          _gateRow('Contract status', g['statusOk'] == true,
              hint: 'Must be terminating or ended'),
          _gateRow('Tenant vacated', g['tenantVacated'] == true,
              hint: 'Tenant must confirm vacated',
              trailing: g['tenantVacated'] != true
                  ? TextButton(
                      onPressed: () async {
                        if (_termination == null) return;
                        await confirmTenantVacated(
                          contractId: widget.contractId,
                          terminationId: _termination!['id'].toString(),
                        );
                        _refresh();
                      },
                      child: const Text('Mark Vacated',
                          style: TextStyle(
                              fontSize: 12,
                              color: MoveOutChecklistScreen.brand)),
                    )
                  : null),
          _gateRow('Reports cleared', g['reportsClear'] == true,
              hint: _openReports.isEmpty
                  ? 'No open reports'
                  : '${_openReports.length} open report(s)',
              trailing: _openReports.isNotEmpty &&
                      _termination?['reports_carry_over_ack'] != true
                  ? TextButton(
                      onPressed: () async {
                        if (_termination == null) return;
                        await setReportsCarryOver(
                          contractId: widget.contractId,
                          terminationId: _termination!['id'].toString(),
                        );
                        _refresh();
                      },
                      child: const Text('Acknowledge & Carry Over',
                          style: TextStyle(
                              fontSize: 12,
                              color: MoveOutChecklistScreen.warn)),
                    )
                  : null),
          _gateRow('Balance cleared', g['balanceClear'] == true,
              hint: 'No outstanding balance',
              trailing: g['balanceClear'] != true
                  ? TextButton(
                      onPressed: () async {
                        if (_termination == null) return;
                        await waiveOutstandingBalance(
                          contractId: widget.contractId,
                          terminationId: _termination!['id'].toString(),
                        );
                        _refresh();
                      },
                      child: const Text('Waive Balance',
                          style: TextStyle(
                              fontSize: 12,
                              color: MoveOutChecklistScreen.danger)),
                    )
                  : null),
        ],
      ),
    );
  }

  Widget _gateRow(String label, bool passed,
      {String? hint, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: passed
                ? MoveOutChecklistScreen.success
                : MoveOutChecklistScreen.muted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: passed
                            ? MoveOutChecklistScreen.ink
                            : MoveOutChecklistScreen.muted)),
                if (hint != null)
                  Text(hint,
                      style: const TextStyle(
                          fontSize: 11,
                          color: MoveOutChecklistScreen.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ── Deposit summary card ──────────────────────────────────────────

  Widget _depositSummaryCard() {
    final deposit = (_totals['securityDeposit'] as num?)?.toDouble() ?? 0.0;
    final totalDeductions =
        (_totals['totalDeductions'] as num?)?.toDouble() ?? 0.0;
    final refund = (_totals['amountReturned'] as num?)?.toDouble() ?? 0.0;

    return _card(
      title: 'Deposit Summary',
      child: Column(
        children: [
          _summaryRow('Security Deposit', '₱${deposit.toStringAsFixed(2)}'),
          _summaryRow('Total Deductions',
              '- ₱${totalDeductions.toStringAsFixed(2)}',
              color: MoveOutChecklistScreen.danger),
          const Divider(height: 20),
          _summaryRow('Refund to Tenant', '₱${refund.toStringAsFixed(2)}',
              bold: true,
              color: refund > 0
                  ? MoveOutChecklistScreen.success
                  : MoveOutChecklistScreen.ink),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: MoveOutChecklistScreen.muted)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w600,
                  color: color ?? MoveOutChecklistScreen.ink)),
        ],
      ),
    );
  }

  // ── Deductions card ───────────────────────────────────────────────

  Widget _deductionsCard() {
    return _card(
      title: 'Deductions',
      trailing: IconButton(
        icon: const Icon(Icons.add, color: MoveOutChecklistScreen.brand),
        onPressed: _showAddDeductionSheet,
        tooltip: 'Add Deduction',
      ),
      child: _deductions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No deductions added.',
                  style: TextStyle(
                      color: MoveOutChecklistScreen.muted, fontSize: 13)),
            )
          : Column(
              children: [
                for (final d in _deductions) _deductionRow(d),
              ],
            ),
    );
  }

  Widget _deductionRow(Map<String, dynamic> d) {
    final cat = d['category']?.toString() ?? '';
    final desc = d['description']?.toString() ?? '';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_deductionLabel(cat),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MoveOutChecklistScreen.ink)),
                if (desc.isNotEmpty)
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 11,
                          color: MoveOutChecklistScreen.muted)),
              ],
            ),
          ),
          Text('₱${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MoveOutChecklistScreen.danger)),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: MoveOutChecklistScreen.muted, size: 18),
            onPressed: () async {
              await removeDeduction(d['id'].toString());
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  String _deductionLabel(String cat) {
    const labels = {
      'damage': 'Damage to Property',
      'cleaning': 'Cleaning Fee',
      'unpaid_rent': 'Unpaid Rent',
      'utilities': 'Utilities Owed',
      'keys': 'Lost Keys / Replacement',
      'other': 'Other',
    };
    return labels[cat] ?? cat;
  }

  Future<void> _showAddDeductionSheet() async {
    if (_termination == null) return;
    final cats = ['damage', 'cleaning', 'unpaid_rent', 'utilities', 'keys', 'other'];
    String selectedCat = cats.first;
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Deduction',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                  items: cats
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(_deductionLabel(c))))
                      .toList(),
                  onChanged: (v) =>
                      setSheet(() => selectedCat = v ?? selectedCat),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₱)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text) ?? 0.0;
                      if (amount <= 0) return;
                      Navigator.pop(ctx);
                      await addDeduction(
                        terminationId: _termination!['id'].toString(),
                        category: selectedCat,
                        description: descCtrl.text.trim(),
                        amount: amount,
                      );
                      _refresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MoveOutChecklistScreen.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Open reports card ─────────────────────────────────────────────

  Widget _reportsCard() {
    if (_openReports.isEmpty) return const SizedBox.shrink();
    return _card(
      title: 'Open Reports (${_openReports.length})',
      child: Column(
        children: [
          for (final r in _openReports)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: MoveOutChecklistScreen.warn, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r['title']?.toString() ?? '—',
                        style: const TextStyle(
                            fontSize: 13,
                            color: MoveOutChecklistScreen.ink)),
                  ),
                  Text(r['status']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: MoveOutChecklistScreen.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Close Contract button ─────────────────────────────────────────

  Widget _closeContractButton() {
    final canClose = _gates['canClose'] == true;
    return ElevatedButton.icon(
      onPressed: canClose && !_closing ? _confirmAndClose : null,
      icon: _closing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.lock_outline, size: 18),
      label: const Text('Close Contract'),
      style: ElevatedButton.styleFrom(
        backgroundColor: MoveOutChecklistScreen.danger,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade500,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _confirmAndClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Contract?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'This will mark the contract as closed and archive the listing. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: MoveOutChecklistScreen.danger,
                foregroundColor: Colors.white),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (confirmed != true || _termination == null) return;
    setState(() => _closing = true);
    final ok = await closeContract(
      contractId: widget.contractId,
      terminationId: _termination!['id'].toString(),
      listingId: widget.listingId,
    );
    if (!mounted) return;
    setState(() => _closing = false);
    if (ok) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RelistPromptScreen(listingId: widget.listingId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to close contract. Try again.')),
      );
    }
  }

  // ── Card wrapper ──────────────────────────────────────────────────

  Widget _card(
      {required String title,
      required Widget child,
      Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MoveOutChecklistScreen.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: MoveOutChecklistScreen.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: MoveOutChecklistScreen.ink)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
