import 'package:flutter/material.dart';

import 'payment_screen.dart';
import 'property_data.dart';
import 'report_management_screen.dart';

/// Tenant in-stay dashboard. Lands here once a contract is paid.
///
/// Branding: ViewxRent coral palette
///   brand    = #F36C6C
///   coral    = #E8735A
///   light    = #FF8A80
///   ink      = #101321
///   muted    = #6B7280
///   bg       = #FAF7F6  (warm neutral)
class InStayDashboardScreen extends StatefulWidget {
  const InStayDashboardScreen({super.key});

  @override
  State<InStayDashboardScreen> createState() => _InStayDashboardScreenState();
}

class _InStayDashboardScreenState extends State<InStayDashboardScreen> {
  static const _brand = Color(0xFFF36C6C);
  static const _coral = Color(0xFFE8735A);
  static const _light = Color(0xFFFF8A80);
  static const _ink = Color(0xFF101321);
  static const _muted = Color(0xFF6B7280);
  static const _bg = Color(0xFFFAF7F6);
  static const _surface = Colors.white;
  static const _border = Color(0xFFEFE7E5);
  static const _success = Color(0xFF22C55E);
  static const _warn = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);

  bool _loading = true;
  Map<String, dynamic>? _rental;
  List<Map<String, dynamic>> _recentReports = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      fetchMyActiveRental(),
      fetchMyReports(),
    ]);
    if (!mounted) return;
    setState(() {
      _rental = results[0] as Map<String, dynamic>?;
      _recentReports = (results[1] as List<Map<String, dynamic>>)
          .take(3)
          .toList();
      _loading = false;
    });
  }

  // ── Derived properties ────────────────────────────────────────────

  String get _title =>
      _rental?['listings']?['title']?.toString() ?? 'My Rental';
  String get _addressLine {
    final parts = [
      _rental?['full_address'],
      _rental?['city'],
      _rental?['province'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return parts.isEmpty ? 'Address unavailable' : parts;
  }

  double get _rent =>
      (_rental?['monthly_rent'] as num?)?.toDouble() ?? 0.0;
  double get _deposit =>
      (_rental?['security_deposit'] as num?)?.toDouble() ?? 0.0;
  double get _advance =>
      (_rental?['advance_payment'] as num?)?.toDouble() ?? 0.0;

  DateTime? get _movedIn {
    final iso = _rental?['available_from']?.toString() ??
        _rental?['landlord_signed_at']?.toString();
    return iso == null ? null : DateTime.tryParse(iso);
  }

  DateTime? get _lastPaid {
    final iso = _rental?['last_paid_at']?.toString();
    return iso == null ? null : DateTime.tryParse(iso);
  }

  DateTime? get _nextDueDate {
    if (_lastPaid == null) return null;
    return DateTime(_lastPaid!.year, _lastPaid!.month + 1, _lastPaid!.day);
  }

  int? get _daysUntilDue =>
      _nextDueDate?.difference(DateTime.now()).inDays;

  Color get _dueColor {
    final d = _daysUntilDue;
    if (d == null) return _muted;
    if (d < 0) return _danger;
    if (d <= 5) return _warn;
    return _success;
  }

  String get _dueChipLabel {
    final d = _daysUntilDue;
    if (d == null) return 'No payments yet';
    if (d < 0) return '${-d}d overdue';
    if (d == 0) return 'Due today';
    return 'Due in ${d}d';
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _brand))
          : _rental == null
              ? _emptyState(context)
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refresh,
                      color: _brand,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _heroSection(context),
                            // Shift the entire content block up by 36px
                            // so the floating Next Payment card overlaps
                            // the bottom of the hero gradient.
                            Transform.translate(
                              offset: const Offset(0, -36),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _nextPaymentCard(),
                                    const SizedBox(height: 18),
                                    _quickStats(),
                                    const SizedBox(height: 18),
                                    _quickActions(context),
                                    const SizedBox(height: 18),
                                    _leaseDetailsCard(),
                                    const SizedBox(height: 18),
                                    _recentReportsSection(context),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Floating top app bar (back + refresh) over the hero.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white),
                              onPressed: _refresh,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('My Rental',
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined,
                  size: 88,
                  color: _brand.withValues(alpha: 0.35)),
              const SizedBox(height: 16),
              const Text('No active rental yet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _ink)),
              const SizedBox(height: 8),
              Text(
                'Apply to a listing, sign the contract, and complete '
                'your first payment — your rental will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero section (in-flow, scrolls with content) ──────────────────

  Widget _heroSection(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 70),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, _brand, _coral],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -56,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 22,
                      height: 22,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Text('V',
                            style: TextStyle(
                                color: _brand,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('VIEWXRENT · TENANT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(_title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(_addressLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.95),
                            fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Next payment card (floating, overlaps hero) ───────────────────

  Widget _nextPaymentCard() {
    final dueDateStr = _nextDueDate == null
        ? 'No prior payment yet'
        : '${_monthName(_nextDueDate!.month)} ${_nextDueDate!.day}, ${_nextDueDate!.year}';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Next Rent Cycle',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.4)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _dueColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_dueChipLabel,
                    style: TextStyle(
                        color: _dueColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('₱',
                  style: TextStyle(
                      fontSize: 18,
                      color: _ink,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              Text(_rent.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 32,
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      height: 1)),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('/ month',
                    style: TextStyle(
                        fontSize: 13,
                        color: _muted,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.event, color: _muted, size: 14),
              const SizedBox(width: 4),
              Text('Due $dueDateStr',
                  style: const TextStyle(
                      fontSize: 12, color: _muted)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(
                      contractId: _rental!['id'].toString(),
                      amountPhp: _rent,
                      summaryLabel:
                          'Monthly rent — ${_rental?['listings']?['title'] ?? ''}',
                    ),
                  ),
                );
                _refresh();
              },
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Pay Next Month'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick stats row ───────────────────────────────────────────────

  Widget _quickStats() {
    final daysIn = _movedIn == null
        ? null
        : DateTime.now().difference(_movedIn!).inDays;
    final term =
        _rental?['lease_term']?.toString().replaceAll(' months', 'm') ??
            '—';
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.calendar_today_outlined,
            color: _brand,
            label: 'Days in stay',
            value: daysIn?.toString() ?? '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            icon: Icons.event_repeat,
            color: _coral,
            label: 'Lease term',
            value: term,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            icon: Icons.shield_outlined,
            color: _light,
            label: 'Deposit',
            value: '₱${_deposit.toStringAsFixed(0)}',
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  // ── Quick actions row ─────────────────────────────────────────────

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.receipt_long_outlined,
            label: 'Payments',
            color: _brand,
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
            label: 'Reports',
            color: _coral,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportManagementScreen(),
                ),
              );
              _refresh();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionTile(
            icon: Icons.support_agent_outlined,
            label: 'Support',
            color: _light,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support chat coming soon')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ink)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lease details card ────────────────────────────────────────────

  Widget _leaseDetailsCard() {
    final term = _rental?['lease_term']?.toString() ?? '—';
    final type = _rental?['listing_type']?.toString() == 'rent'
        ? 'Month-to-Month'
        : 'Lease (Fixed Term)';
    final movedInStr = _movedIn == null
        ? '—'
        : '${_monthName(_movedIn!.month)} ${_movedIn!.day}, ${_movedIn!.year}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
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
                  color: _brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Lease Details',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _ink)),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('Type', type),
          _detailRow('Term', term),
          _detailRow('Move-in', movedInStr),
          const Divider(height: 22),
          _detailRow('Monthly rent', '₱${_rent.toStringAsFixed(2)}'),
          _detailRow('Security deposit', '₱${_deposit.toStringAsFixed(2)}'),
          _detailRow('Advance rent', '₱${_advance.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink)),
          ),
        ],
      ),
    );
  }

  // ── Recent reports ────────────────────────────────────────────────

  Widget _recentReportsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
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
                  color: _brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Recent Reports',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _ink)),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ReportManagementScreen(),
                    ),
                  );
                  _refresh();
                },
                child: const Text('See all',
                    style: TextStyle(color: _brand)),
              ),
            ],
          ),
          if (_recentReports.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No reports yet.',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13)),
              ),
            )
          else
            for (int i = 0; i < _recentReports.length; i++) ...[
              _miniReportRow(_recentReports[i]),
              if (i != _recentReports.length - 1)
                const Divider(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _miniReportRow(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'open').toString();
    final color = switch (status) {
      'open' => _warn,
      'in_progress' => const Color(0xFF2196F3),
      'resolved' => _success,
      _ => _muted,
    };
    final label = switch (status) {
      'open' => 'Open',
      'in_progress' => 'In-progress',
      'resolved' => 'Resolved',
      _ => status,
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(r['title']?.toString() ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ink)),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}
