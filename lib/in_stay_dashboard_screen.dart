import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_thread_screen.dart';
import 'contract_payment_screen.dart';
import 'payment_screen.dart';
import 'property_data.dart';
import 'report_management_screen.dart';
import 'services/payments_service.dart';

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
  static const _brand = VxrTokens.accent;
  static const _coral = VxrTokens.gradMid;
  static const _light = VxrTokens.gradEnd;
  static const _ink = VxrTokens.text;
  static const _muted = VxrTokens.textSub;
  static const _bg = VxrTokens.bg;
  static const _surface = VxrTokens.surface;
  static const _border = VxrTokens.border;
  static const _success = VxrTokens.success;
  static const _warn = VxrTokens.warning;
  static const _danger = VxrTokens.danger;

  bool _loading = true;
  Map<String, dynamic>? _rental;
  Map<String, dynamic>? _termination;
  List<Map<String, dynamic>> _recentReports = [];
  List<RentMonth> _rentMonths = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      fetchMyActiveContract(),
      fetchMyReports(),
    ]);
    if (!mounted) return;
    final rental = results[0] as Map<String, dynamic>?;
    Map<String, dynamic>? termination;
    List<RentMonth> rentMonths = const [];
    if (rental != null) {
      termination = await getTermination(rental['id'].toString());
      rentMonths = await fetchRentMonths(rental['id'].toString());
    }
    setState(() {
      _rental = rental;
      _termination = termination;
      _recentReports = (results[1] as List<Map<String, dynamic>>)
          .take(3)
          .toList();
      _rentMonths = rentMonths;
      _loading = false;
    });
  }

  Future<void> _openLandlordChat() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final listing = (_rental?['listings'] as Map?) ?? {};
    final landlordId = listing['landlord_id']?.toString();
    final listingId = _rental?['listing_id']?.toString();
    if (me == null || landlordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active rental yet.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _brand)),
    );

    final convId = await getOrCreateConversation(
      landlordId: landlordId,
      tenantId: me,
      listingId: listingId,
    );

    Map<String, dynamic>? landlordProfile;
    try {
      landlordProfile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', landlordId)
          .maybeSingle();
    } catch (_) {
      landlordProfile = null;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close loader

    if (convId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open chat. Try again.')),
      );
      return;
    }

    final name = (landlordProfile?['full_name']?.toString().trim() ?? '');
    final avatar = landlordProfile?['avatar_url']?.toString() ?? '';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationId: convId,
          otherName: name.isEmpty ? 'Your Landlord' : name,
          otherAvatarUrl: avatar,
          listingTitle: listing['title']?.toString(),
        ),
      ),
    );
    if (mounted) _refresh();
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

  // ── Termination derived ───────────────────────────────────────────

  String get _contractStatus =>
      _rental?['status']?.toString() ?? 'paid';

  bool get _isTerminating =>
      const {'terminating', 'expiring', 'ended'}.contains(_contractStatus);

  DateTime? get _effectiveEnd {
    final iso = _rental?['effective_end_date']?.toString() ??
        _termination?['effective_date']?.toString();
    return iso == null ? null : DateTime.tryParse(iso);
  }

  int get _daysUntilEffective =>
      _effectiveEnd?.difference(DateTime.now()).inDays ?? 0;

  bool get _canConfirmVacated =>
      _isTerminating && _daysUntilEffective <= 0 &&
      _termination?['tenant_vacated_confirmed_at'] == null;

  bool get _alreadyVacated =>
      _termination?['tenant_vacated_confirmed_at'] != null;

  bool get _isMutualPending =>
      _contractStatus == 'paid' &&
      _termination != null &&
      _termination!['mutual_proposed_at'] != null &&
      (_termination!['mutual_accepted_by_tenant_at'] == null ||
          _termination!['mutual_accepted_by_landlord_at'] == null) &&
      _termination!['mutual_withdrawn_at'] == null;

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
                                    if (_isTerminating || _isMutualPending) ...
                                      [_terminationBanner(context), const SizedBox(height: 18)],
                                    _quickStats(),
                                    const SizedBox(height: 18),
                                    _quickActions(context),
                                    const SizedBox(height: 18),
                                    _leaseDetailsCard(),
                                    const SizedBox(height: 18),
                                    _rentHistorySection(),
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
      backgroundColor: _bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: const Text('My Rental'),
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
      decoration: const BoxDecoration(gradient: VxrTokens.brandGradient),
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
                    builder: (_) => ContractPaymentScreen(
                      contractId: _rental!['id'].toString(),
                      amountPhp: _rent.round(),
                      listingTitle:
                          (_rental?['listings']?['title'] ?? '').toString(),
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

  // ── Termination banner ────────────────────────────────────────────

  Widget _terminationBanner(BuildContext context) {
    final isMutualPending = _isMutualPending;
    final daysLeft = _daysUntilEffective;
    final effectiveDateStr = _effectiveEnd == null
        ? '—'
        : '${_monthName(_effectiveEnd!.month)} ${_effectiveEnd!.day}, ${_effectiveEnd!.year}';

    String title;
    String body;
    Color bannerColor;
    IconData bannerIcon;

    if (isMutualPending) {
      title = 'Mutual Termination Pending';
      body = 'A mutual termination has been proposed and is awaiting both parties to accept.';
      bannerColor = _warn;
      bannerIcon = Icons.handshake_outlined;
    } else if (_contractStatus == 'ended') {
      title = 'Lease Ended';
      body = 'Your lease term has ended. Please confirm that you have vacated.';
      bannerColor = _danger;
      bannerIcon = Icons.door_front_door_outlined;
    } else {
      title = 'Termination in Progress';
      body = daysLeft > 0
          ? '$daysLeft day${daysLeft == 1 ? '' : 's'} until effective date ($effectiveDateStr).'
          : 'Effective date has passed ($effectiveDateStr). Please confirm you have vacated.';
      bannerColor = daysLeft > 0 ? _warn : _danger;
      bannerIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(bannerIcon, color: bannerColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: bannerColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(fontSize: 12, color: bannerColor, height: 1.4)),
          if (isMutualPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await acceptMutualTermination(
                        contractId: _rental!['id'].toString(),
                        terminationId: _termination!['id'].toString(),
                        acceptingRole: 'tenant',
                      );
                      if (ok && mounted) _refresh();
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _success,
                        side: const BorderSide(color: _success)),
                    child: const Text('Accept', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await withdrawMutualTermination(
                        contractId: _rental!['id'].toString(),
                        terminationId: _termination!['id'].toString(),
                      );
                      if (ok && mounted) _refresh();
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _danger,
                        side: const BorderSide(color: _danger)),
                    child: const Text('Withdraw', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ] else if (_canConfirmVacated) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await confirmTenantVacated(
                    contractId: _rental!['id'].toString(),
                    terminationId: _termination!['id'].toString(),
                  );
                  if (ok && mounted) _refresh();
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Confirm I Have Vacated'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bannerColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else if (_alreadyVacated) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check_circle, color: _success, size: 14),
                const SizedBox(width: 4),
                const Text('Vacated confirmed. Waiting for landlord to close.',
                    style: TextStyle(fontSize: 11, color: _success)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick actions row ─────────────────────────────────────────────

  Widget _quickActions(BuildContext context) {
    final canRequestTermination = _contractStatus == 'paid' && _termination == null;
    return Column(
      children: [
        Row(
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
                icon: Icons.chat_bubble_outline,
                label: 'Chat Landlord',
                color: _light,
                onTap: _openLandlordChat,
              ),
            ),
          ],
        ),
        if (canRequestTermination) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showRequestTerminationSheet(context),
              icon: const Icon(Icons.exit_to_app, size: 16),
              label: const Text('Request Termination'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: const BorderSide(color: _danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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

  // ── Rent history strip ────────────────────────────────────────────

  Widget _rentHistorySection() {
    if (_rentMonths.isEmpty) return const SizedBox.shrink();
    const monthShort = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
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
              const Text('Rent history',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _ink)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap an unpaid month to pay.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _rentMonths.reversed.map((m) {
                final label =
                    '${monthShort[m.billingMonth.month - 1]} ${m.billingMonth.year}';
                final color = m.paid ? _success : _warn;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: m.paid
                        ? null
                        : () => _payMonth(m),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 96,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${(m.amountCents / 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.paid ? 'Paid' : 'Unpaid',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payMonth(RentMonth m) async {
    if (_rental == null) return;
    final ym =
        '${m.billingMonth.year.toString().padLeft(4, '0')}-${m.billingMonth.month.toString().padLeft(2, '0')}';
    final rentPhp = (m.amountCents / 100).round();
    final listing = (_rental?['listings'] as Map?) ?? const {};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractPaymentScreen(
          contractId: _rental!['id'].toString(),
          amountPhp: rentPhp,
          monthlyRent: rentPhp,
          listingTitle: listing['title']?.toString(),
          billingMonth: ym,
        ),
      ),
    );
    _refresh();
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

  // ── Request Termination sheet ─────────────────────────────────────

  Future<void> _showRequestTerminationSheet(BuildContext context) async {
    final contractId = _rental!['id'].toString();
    final listingType = _rental?['listing_type']?.toString() ?? 'rent';
    final isFixedTerm = listingType == 'lease';
    final depositAmt =
        (_rental?['security_deposit'] as num?)?.toDouble() ?? 0.0;
    final reasonCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
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
              Text(
                isFixedTerm ? 'Propose Mutual Termination' : '30-Day Termination Notice',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isFixedTerm
                    ? 'This will propose a mutual termination. The landlord must also accept before the contract is cancelled.'
                    : 'This will file a 30-day notice. Your tenancy ends 30 days from today.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason (required)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (reasonCtrl.text.trim().isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final now = DateTime.now();
                    final effectiveDate =
                        isFixedTerm ? now.add(const Duration(days: 1)) : now.add(const Duration(days: 30));
                    final ok = await requestTermination(
                      contractId: contractId,
                      type: isFixedTerm ? 'mutual' : 'notice',
                      initiatedBy: 'tenant',
                      noticeDate: now,
                      effectiveDate: effectiveDate,
                      reason: reasonCtrl.text.trim(),
                      securityDepositAmount: depositAmt,
                    );
                    if (!mounted) return;
                    if (ok) {
                      _refresh();
                    } else {
                      messenger.showSnackBar(const SnackBar(
                        content: Text(
                            'Could not initiate termination — please refresh and try again.'),
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isFixedTerm ? 'Submit Proposal' : 'File Notice'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
