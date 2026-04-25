import 'package:flutter/material.dart';

import 'payment_screen.dart';
import 'property_data.dart';
import 'report_management_screen.dart';

/// Tenant in-stay dashboard. Lands here once a contract is paid:
/// shows the rental's key info, the upcoming rent cycle, and quick
/// links to make the next payment or file a maintenance report.
class InStayDashboardScreen extends StatefulWidget {
  const InStayDashboardScreen({super.key});

  @override
  State<InStayDashboardScreen> createState() => _InStayDashboardScreenState();
}

class _InStayDashboardScreenState extends State<InStayDashboardScreen> {
  static const _kPrimary = Color(0xFFE8735A);
  static const _kInk = Color(0xFF1A1A2E);
  static const _kMuted = Color(0xFF7A7A88);

  bool _loading = true;
  Map<String, dynamic>? _rental;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final r = await fetchMyActiveRental();
    if (mounted) {
      setState(() {
        _rental = r;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('My Rental'),
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rental == null
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _heroCard(),
                      const SizedBox(height: 14),
                      _nextDueCard(),
                      const SizedBox(height: 14),
                      _detailsCard(),
                      const SizedBox(height: 14),
                      _quickActions(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No active rental yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Once your application is approved, the contract is signed by '
              'both parties, and the first payment is settled, your rental '
              'will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    final title = _rental?['listings']?['title']?.toString() ?? 'My Rental';
    final addrParts = [
      _rental?['full_address'],
      _rental?['city'],
      _rental?['province'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    final movedIn = _formatDate(
        _rental?['available_from']?.toString() ??
            _rental?['landlord_signed_at']?.toString());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7B7B), Color(0xFFE85D5D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Currently staying at',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          if (addrParts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(addrParts,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.event_available,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text('Move-in: $movedIn',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nextDueCard() {
    final lastPaidIso = _rental?['last_paid_at']?.toString();
    final lastPaidDate =
        lastPaidIso != null ? DateTime.tryParse(lastPaidIso) : null;
    DateTime? nextDue;
    int? daysUntil;
    if (lastPaidDate != null) {
      nextDue = DateTime(
          lastPaidDate.year, lastPaidDate.month + 1, lastPaidDate.day);
      daysUntil = nextDue.difference(DateTime.now()).inDays;
    }
    final rent = (_rental?['monthly_rent'] as num?)?.toDouble() ?? 0.0;

    final isOverdue = daysUntil != null && daysUntil < 0;
    final color = isOverdue ? Colors.redAccent : _kPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: color, size: 18),
              const SizedBox(width: 6),
              const Text('Next rent cycle',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kv('Amount',
                    '₱${rent.toStringAsFixed(2)}', color),
              ),
              Expanded(
                child: _kv(
                  'Due date',
                  nextDue == null
                      ? '—'
                      : '${_monthName(nextDue.month)} ${nextDue.day}, ${nextDue.year}',
                  color,
                ),
              ),
              Expanded(
                child: _kv(
                  'Status',
                  daysUntil == null
                      ? 'Pending'
                      : isOverdue
                          ? '${-daysUntil}d overdue'
                          : '$daysUntil days left',
                  color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(
                      contractId: _rental!['id'].toString(),
                      amountPhp: rent,
                      summaryLabel:
                          'Monthly rent — ${_rental?['listings']?['title'] ?? ''}',
                    ),
                  ),
                );
                _refresh();
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pay next month'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    final term = _rental?['lease_term']?.toString() ?? '—';
    final type = _rental?['listing_type']?.toString() == 'rent'
        ? 'Month-to-Month'
        : 'Lease (Fixed Term)';
    final rent = (_rental?['monthly_rent'] as num?)?.toDouble() ?? 0.0;
    final dep = (_rental?['security_deposit'] as num?)?.toDouble() ?? 0.0;
    final adv = (_rental?['advance_payment'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lease details',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _row('Type', type),
          _row('Term', term),
          _row('Monthly rent', '₱${rent.toStringAsFixed(2)}'),
          _row('Security deposit', '₱${dep.toStringAsFixed(2)}'),
          _row('Advance rent', '₱${adv.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.receipt_long_outlined,
            label: 'Payments',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentScreen(
                  contractId: _rental!['id'].toString(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionTile(
            icon: Icons.build_outlined,
            label: 'Maintenance',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReportManagementScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: _kPrimary, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: _kMuted)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor)),
      ],
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: const TextStyle(fontSize: 12, color: _kMuted)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kInk)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_monthName(d.month)} ${d.day}, ${d.year}';
  }

  String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[(m - 1).clamp(0, 11)];
  }

}
