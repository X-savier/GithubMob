import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/vxr_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_thread_screen.dart';
import 'move_out_checklist_screen.dart';
import 'payment_screen.dart';
import 'property_data.dart';
import 'report_management_screen.dart';
import 'services/payments_service.dart';

/// Landlord-facing tenant management. Lists every active tenant
/// (contract status='paid') across all the landlord's listings with
/// quick links to contact, view payments, or open the reports queue.
///
/// Branding: ViewxRent coral palette
///   primary  = #F36C6C  (CTAs, accents)
///   coral    = #E8735A  (icons, hero deep stop)
///   light    = #FF8A80  (hero light stop)
///   ink      = #101321  (primary text)
///   muted    = #6B7280  (secondary text)
///   bg       = #FAF7F6  (warm neutral surface)
///   surface  = #FFFFFF  (cards)
class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  static const Color brand = VxrTokens.accent;
  static const Color coral = VxrTokens.gradMid;
  static const Color light = VxrTokens.gradEnd;
  static const Color ink = VxrTokens.text;
  static const Color muted = VxrTokens.textSub;
  static const Color bg = VxrTokens.bg;
  static const Color border = VxrTokens.border;

  @override
  State<TenantManagementScreen> createState() =>
      _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _openReports = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      fetchActiveTenantsAll(),
      fetchLandlordReports(),
    ]);
    if (!mounted) return;
    setState(() {
      _tenants = results[0];
      _openReports = results[1]
          .where((r) =>
              r['status'] == 'open' || r['status'] == 'in_progress')
          .toList();
      _loading = false;
    });
  }

  // ── Derived ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _tenants;
    final q = _query.toLowerCase();
    return _tenants.where((t) {
      final app = (t['application'] as Map?) ?? {};
      final listing = (t['listings'] as Map?) ?? {};
      final profile = (t['tenant_profile'] as Map?) ?? {};
      final name =
          ('${app['first_name'] ?? ''} ${app['last_name'] ?? ''} '
                  '${profile['full_name'] ?? ''}')
              .toLowerCase();
      final title = (listing['title'] ?? '').toString().toLowerCase();
      final email = (app['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || title.contains(q) || email.contains(q);
    }).toList();
  }

  int _openReportsForTenant(String contractId) {
    return _openReports
        .where((r) => r['contract_id']?.toString() == contractId)
        .length;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TenantManagementScreen.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: TenantManagementScreen.brand))
          : Stack(
              children: [
                RefreshIndicator(
                  color: TenantManagementScreen.brand,
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _heroSection(),
                        // The entire content block is shifted up so the
                        // floating stats card overlaps the bottom of the
                        // hero — done with Transform.translate so the
                        // hero gradient stays its full visual height.
                        Transform.translate(
                          offset: const Offset(0, -36),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 24),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                _statsRow(),
                                const SizedBox(height: 18),
                                _searchField(),
                                const SizedBox(height: 14),
                                _sectionHeader(),
                                const SizedBox(height: 8),
                                if (_filtered.isEmpty) _emptyState() else
                                  for (final t in _filtered) ...[
                                    _tenantCard(t),
                                    const SizedBox(height: 12),
                                  ],
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

  // ── Hero section (in-flow, scrolls with content) ──────────────────

  Widget _heroSection() {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      // Total height = status bar inset + visible hero (~210px).
      // The bottom 36px is reserved as overlap real estate for the
      // floating stats card that follows.
      padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VxrTokens.gradEnd,
            VxrTokens.accent,
            VxrTokens.gradMid,
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Decorative circles
          Positioned(
            right: -56,
            top: -56,
            child: Container(
              width: 180,
              height: 180,
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
              // ViewxRent wordmark with logo
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
                                color: TenantManagementScreen.brand,
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
                    child: const Text('VIEWXRENT · LANDLORD',
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
              const Text('Tenants & Stays',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15)),
              const SizedBox(height: 6),
              Text(
                _tenants.isEmpty
                    ? 'You have no active tenants yet'
                    : 'Manage ${_tenants.length} active tenant${_tenants.length == 1 ? '' : 's'}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats row (floating, overlaps hero) ───────────────────────────

  Widget _statsRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: TenantManagementScreen.brand.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _statColumn(
              icon: Icons.people_alt_outlined,
              color: TenantManagementScreen.brand,
              label: 'Active',
              value: _tenants.length.toString(),
            ),
          ),
          Container(
              width: 1,
              height: 40,
              color: TenantManagementScreen.border),
          Expanded(
            child: _statColumn(
              icon: Icons.report_outlined,
              color: TenantManagementScreen.coral,
              label: 'Open reports',
              value: _openReports.length.toString(),
            ),
          ),
          Container(
              width: 1,
              height: 40,
              color: TenantManagementScreen.border),
          Expanded(
            child: _statColumn(
              icon: Icons.home_work_outlined,
              color: TenantManagementScreen.light,
              label: 'Properties',
              value: _tenants
                  .map((t) =>
                      (t['listings'] as Map?)?['title']?.toString() ?? '')
                  .toSet()
                  .length
                  .toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: TenantManagementScreen.ink)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: TenantManagementScreen.muted)),
      ],
    );
  }

  // ── Search ────────────────────────────────────────────────────────

  Widget _searchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TenantManagementScreen.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search,
              color: TenantManagementScreen.brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search tenant, property, email…',
                hintStyle: TextStyle(
                    color: TenantManagementScreen.muted, fontSize: 13),
                filled: false,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: TenantManagementScreen.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Active Tenants',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TenantManagementScreen.ink)),
          const Spacer(),
          Text('${_filtered.length}',
              style: const TextStyle(
                  fontSize: 12,
                  color: TenantManagementScreen.muted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _emptyState() {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TenantManagementScreen.border),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline,
              size: 56,
              color: TenantManagementScreen.brand.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('No active tenants yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: TenantManagementScreen.ink)),
          const SizedBox(height: 4),
          Text(
            _query.isEmpty
                ? 'Tenants appear here once their contract is fully signed and paid.'
                : 'No tenants match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── Tenant card ───────────────────────────────────────────────────

  Widget _tenantCard(Map<String, dynamic> t) {
    final listing = (t['listings'] as Map?) ?? {};
    final app = (t['application'] as Map?) ?? {};
    final profile = (t['tenant_profile'] as Map?) ?? {};
    final tenantName = _resolveName(profile, app);
    final propertyTitle = listing['title']?.toString() ?? 'Listing';
    final email = app['email']?.toString() ?? '';
    final phone = app['phone_number']?.toString() ?? '';
    final movedInIso = t['landlord_signed_at']?.toString();
    final movedIn = _formatDate(movedInIso);
    final daysSinceMoveIn = movedInIso == null
        ? null
        : DateTime.now()
            .difference(DateTime.tryParse(movedInIso) ?? DateTime.now())
            .inDays;
    final contractId = t['id']?.toString() ?? '';
    final openReports = _openReportsForTenant(contractId);
    final avatarUrl = profile['avatar_url']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TenantManagementScreen.border),
        boxShadow: [
          BoxShadow(
            color: TenantManagementScreen.brand.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatarFor(name: tenantName, url: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenantName.isEmpty ? 'Tenant' : tenantName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: TenantManagementScreen.ink)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.home_outlined,
                            size: 13,
                            color: TenantManagementScreen.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(propertyTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                      TenantManagementScreen.muted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _activePill(),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: TenantManagementScreen.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: TenantManagementScreen.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _kv(
                    icon: Icons.event_available_outlined,
                    label: 'Move-in',
                    value: movedIn,
                  ),
                ),
                Container(
                    width: 1,
                    height: 30,
                    color: TenantManagementScreen.border),
                Expanded(
                  child: _kv(
                    icon: Icons.calendar_today_outlined,
                    label: 'Days in stay',
                    value: daysSinceMoveIn?.toString() ?? '—',
                  ),
                ),
                Container(
                    width: 1,
                    height: 30,
                    color: TenantManagementScreen.border),
                Expanded(
                  child: _kv(
                    icon: Icons.report_outlined,
                    label: 'Open reports',
                    value: openReports.toString(),
                    valueColor: openReports > 0
                        ? TenantManagementScreen.brand
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (email.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (email.isNotEmpty)
                  _contactChip(Icons.mail_outline, email),
                if (phone.isNotEmpty)
                  _contactChip(Icons.phone_outlined, phone),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _action(
                  icon: Icons.report_outlined,
                  label: 'Reports',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ReportManagementScreen(),
                      ),
                    );
                    _refresh();
                  },
                ),
              ),
              Container(
                  width: 1,
                  height: 22,
                  color: TenantManagementScreen.border),
              Expanded(
                child: _action(
                  icon: Icons.payments_outlined,
                  label: 'Payments',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        contractId: contractId,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                  width: 1,
                  height: 22,
                  color: TenantManagementScreen.border),
              Expanded(
                child: _action(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () => _openChat(t),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 1,
            color: TenantManagementScreen.border,
          ),
          Row(
            children: [
              Expanded(
                child: _action(
                  icon: Icons.savings_outlined,
                  label: 'Record payment',
                  onTap: () => _openOfflinePaymentSheet(t),
                ),
              ),
              Container(
                  width: 1,
                  height: 22,
                  color: TenantManagementScreen.border),
              Expanded(
                child: _action(
                  icon: Icons.link_outlined,
                  label: 'Send link',
                  onTap: () => _openPaymentLinkSheet(t),
                ),
              ),
            ],
          ),
          _tenantTerminationRow(t),
        ],
      ),
    );
  }

  // ── Termination / Move-out row per tenant ─────────────────────────

  Widget _tenantTerminationRow(Map<String, dynamic> t) {
    final contractId = t['id']?.toString() ?? '';
    final contractStatus = t['status']?.toString() ?? 'paid';
    final listingId = t['listing_id']?.toString() ?? '';
    final listingType = t['listing_type']?.toString() ?? 'rent';
    final termination = (t['termination'] as Map?)?.cast<String, dynamic>();
    final isTerminating = const {'terminating', 'expiring', 'ended'}.contains(contractStatus);
    final canInitiate = contractStatus == 'paid';

    // Tenant-initiated mutual proposal awaiting landlord acceptance.
    final hasPendingMutualFromTenant = termination != null &&
        termination['type'] == 'mutual' &&
        termination['initiated_by'] == 'tenant' &&
        termination['mutual_accepted_by_landlord_at'] == null &&
        termination['mutual_withdrawn_at'] == null;

    if (hasPendingMutualFromTenant) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _pendingMutualBanner(contractId, termination),
      );
    }

    if (!isTerminating && !canInitiate) return const SizedBox.shrink();

    // Surface tenant-filed 30-day notice as a chip above the checklist.
    final isTenantNotice = isTerminating &&
        termination != null &&
        termination['type'] == 'notice' &&
        termination['initiated_by'] == 'tenant';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: isTerminating
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isTenantNotice) ...[
                  _tenantNoticeChip(termination),
                  const SizedBox(height: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MoveOutChecklistScreen(
                          contractId: contractId,
                          listingId: listingId,
                        ),
                      ),
                    );
                    _refresh();
                  },
                  icon: const Icon(Icons.checklist_outlined, size: 16),
                  label: const Text('Move-Out Checklist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : termination != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.hourglass_top_outlined,
                          size: 14, color: Color(0xFFC2410C)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Termination already in progress.',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFC2410C)),
                        ),
                      ),
                    ],
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () => _initiateTermination(
                      context, t, contractId, listingType),
                  icon: const Icon(Icons.exit_to_app, size: 16),
                  label: const Text('Initiate Termination'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
    );
  }

  Widget _pendingMutualBanner(
      String contractId, Map<String, dynamic> termination) {
    const danger = Color(0xFFEF4444);
    final terminationId = termination['id']?.toString() ?? '';
    final reason = (termination['reason'] as String?)?.trim() ?? '';
    final effectiveDate = _formatDate(termination['effective_date']?.toString());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.handshake_outlined, color: danger, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tenant requested mutual termination',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Proposed effective: $effectiveDate',
            style: const TextStyle(
                fontSize: 12, color: danger, height: 1.4),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: $reason',
              style: const TextStyle(
                  fontSize: 12, color: danger, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptMutual(contractId, terminationId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineMutual(contractId, terminationId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: danger,
                    side: const BorderSide(color: danger),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tenantNoticeChip(Map<String, dynamic> termination) {
    const danger = Color(0xFFEF4444);
    final effectiveDate = _formatDate(termination['effective_date']?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: danger, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tenant filed 30-day notice — effective $effectiveDate',
              style: const TextStyle(
                  fontSize: 11, color: danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptMutual(String contractId, String terminationId) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await acceptMutualTermination(
      contractId: contractId,
      terminationId: terminationId,
      acceptingRole: 'landlord',
    );
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Termination accepted. Move-out can begin.')));
      _refresh();
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not accept termination. Try again.')));
    }
  }

  Future<void> _declineMutual(String contractId, String terminationId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline termination request?'),
        content: const Text(
            'The tenant will be notified the proposal was declined. The contract continues unchanged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await withdrawMutualTermination(
      contractId: contractId,
      terminationId: terminationId,
    );
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Termination request declined.')));
      _refresh();
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not decline request. Try again.')));
    }
  }

  Future<void> _initiateTermination(BuildContext context,
      Map<String, dynamic> t, String contractId, String listingType) async {
    final isFixedTerm = listingType == 'lease';
    final reasonCtrl = TextEditingController();
    String selectedType = isFixedTerm ? 'mutual' : 'notice';

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
                const Text('Initiate Termination',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (isFixedTerm) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                        labelText: 'Termination Type',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                    items: const [
                      DropdownMenuItem(
                          value: 'mutual',
                          child: Text('Mutual Termination')),
                      DropdownMenuItem(
                          value: 'non_renewal',
                          child: Text('Non-Renewal')),
                      DropdownMenuItem(
                          value: 'eviction', child: Text('Eviction')),
                    ],
                    onChanged: (v) =>
                        setSheet(() => selectedType = v ?? selectedType),
                  ),
                  const SizedBox(height: 12),
                ],
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
                      final depositAmt =
                          (t['security_deposit'] as num?)?.toDouble() ?? 0.0;
                      final effectiveDate = selectedType == 'notice'
                          ? now.add(const Duration(days: 30))
                          : now.add(const Duration(days: 1));
                      final ok = await requestTermination(
                        contractId: contractId,
                        type: selectedType,
                        initiatedBy: 'landlord',
                        noticeDate: now,
                        effectiveDate: effectiveDate,
                        reason: reasonCtrl.text.trim(),
                        securityDepositAmount: depositAmt,
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Termination initiated.'
                            : 'Could not initiate termination — an active termination may already exist. Pull to refresh.'),
                      ));
                      _refresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm'),
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

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _openChat(Map<String, dynamic> t) async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final tenantId = t['tenant_id']?.toString();
    final listingId = t['listing_id']?.toString();
    if (me == null || tenantId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
            color: TenantManagementScreen.brand),
      ),
    );
    final convId = await getOrCreateConversation(
      landlordId: me,
      tenantId: tenantId,
      listingId: listingId,
    );
    if (!mounted) return;
    Navigator.of(context).pop(); // close loader

    if (convId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open chat. Try again.')),
      );
      return;
    }

    final profile = (t['tenant_profile'] as Map?) ?? {};
    final app = (t['application'] as Map?) ?? {};
    final listing = (t['listings'] as Map?) ?? {};

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationId: convId,
          otherName: _resolveName(profile, app),
          otherAvatarUrl:
              profile['avatar_url']?.toString() ?? '',
          listingTitle: listing['title']?.toString(),
        ),
      ),
    );
    if (mounted) _refresh();
  }

  // ── Sub-widgets ───────────────────────────────────────────────────

  String _resolveName(Map profile, Map app) {
    final fullName = profile['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final fl =
        '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}'.trim();
    return fl;
  }

  Widget _avatarFor({required String name, required String url}) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            TenantManagementScreen.light,
            TenantManagementScreen.brand,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TenantManagementScreen.brand.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20)),
    );

    if (url.isEmpty) return fallback;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: TenantManagementScreen.brand.withValues(alpha: 0.3),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: TenantManagementScreen.brand.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.network(
          url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (ctx, child, prog) {
            if (prog == null) return child;
            return Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              color: TenantManagementScreen.bg,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TenantManagementScreen.brand),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _activePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
          SizedBox(width: 4),
          Text('Active',
              style: TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _kv({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon,
            color: valueColor ?? TenantManagementScreen.brand, size: 14),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? TenantManagementScreen.ink)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: TenantManagementScreen.muted)),
      ],
    );
  }

  Widget _contactChip(IconData icon, String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TenantManagementScreen.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: TenantManagementScreen.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: TenantManagementScreen.brand),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 11, color: TenantManagementScreen.ink)),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon,
                size: 20, color: TenantManagementScreen.brand),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TenantManagementScreen.brand)),
          ],
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

  Future<void> _openOfflinePaymentSheet(Map<String, dynamic> t) async {
    final contractId = t['id']?.toString() ?? '';
    if (contractId.isEmpty) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _OfflinePaymentSheet(contractId: contractId),
    );
    if (ok == true && mounted) _refresh();
  }

  Future<void> _openPaymentLinkSheet(Map<String, dynamic> t) async {
    final contractId = t['id']?.toString() ?? '';
    if (contractId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PaymentLinkSheet(contractId: contractId),
    );
  }
}

const List<String> _kBillingMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatBillingMonth(DateTime d) =>
    '${_kBillingMonthNames[d.month - 1]} ${d.year}';

/// Build a list of selectable billing months: current + next 12 months ahead.
List<DateTime> _buildMonthOptions() {
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, 1);
  return List<DateTime>.generate(13, (i) => DateTime(base.year, base.month + i, 1));
}

/// Landlord-only sheet to record an off-platform payment (cash, manual
/// GCash, bank transfer). Invokes the `landlord-record-offline-payment`
/// edge function and pops `true` on success.
class _OfflinePaymentSheet extends StatefulWidget {
  final String contractId;
  const _OfflinePaymentSheet({required this.contractId});

  @override
  State<_OfflinePaymentSheet> createState() => _OfflinePaymentSheetState();
}

class _OfflinePaymentSheetState extends State<_OfflinePaymentSheet> {
  static const _methods = <String, String>{
    'cash': 'Cash',
    'bank_transfer': 'Bank Transfer',
    'gcash': 'GCash (direct)',
    'paymaya': 'Maya (direct)',
    'grab_pay': 'GrabPay (direct)',
    'offline_other': 'Other',
  };

  final _formKey = GlobalKey<FormState>();
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  String _method = 'cash';
  DateTime? _billingMonth;
  DateTime _paidAt = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final amount = num.tryParse(_amountCtl.text.trim()) ?? 0;
    String? ym;
    if (_billingMonth != null) {
      ym =
          '${_billingMonth!.year.toString().padLeft(4, '0')}-${_billingMonth!.month.toString().padLeft(2, '0')}';
    }
    final res = await recordOfflinePayment(
      contractId: widget.contractId,
      amountPhp: amount,
      methodType: _method,
      billingMonth: ym,
      paidAt: _paidAt,
      note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.ok) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Failed to record payment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final options = _buildMonthOptions();
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Record offline payment',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (PHP)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = num.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(
                  labelText: 'Method',
                  border: OutlineInputBorder(),
                ),
                items: _methods.entries
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DateTime?>(
                value: _billingMonth,
                decoration: const InputDecoration(
                  labelText: 'Billing month (optional)',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<DateTime?>>[
                  const DropdownMenuItem<DateTime?>(
                    value: null,
                    child: Text('— move-in / not specified'),
                  ),
                  ...options.map(
                    (d) => DropdownMenuItem<DateTime?>(
                      value: d,
                      child: Text(_formatBillingMonth(d)),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _billingMonth = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paidAt,
                    firstDate: DateTime(now.year - 2),
                    lastDate: now,
                  );
                  if (picked != null) setState(() => _paidAt = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Paid at',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${_paidAt.year}-${_paidAt.month.toString().padLeft(2, '0')}-${_paidAt.day.toString().padLeft(2, '0')}'),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. "Cash, receipt #042"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TenantManagementScreen.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Record payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Landlord-only sheet to generate a PayMongo Link the tenant can pay
/// from any device. On success it shows the URL with a copy button and
/// also lists the recent links for the contract underneath.
class _PaymentLinkSheet extends StatefulWidget {
  final String contractId;
  const _PaymentLinkSheet({required this.contractId});

  @override
  State<_PaymentLinkSheet> createState() => _PaymentLinkSheetState();
}

class _PaymentLinkSheetState extends State<_PaymentLinkSheet> {
  late DateTime _billingMonth;
  final _noteCtl = TextEditingController();
  bool _submitting = false;
  String? _lastUrl;
  String? _error;
  List<PaymentLinkRow> _existing = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _billingMonth = DateTime(now.year, now.month, 1);
    _loadExisting();
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final list = await fetchPaymentLinks(widget.contractId);
    if (!mounted) return;
    setState(() => _existing = list);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ym =
        '${_billingMonth.year.toString().padLeft(4, '0')}-${_billingMonth.month.toString().padLeft(2, '0')}';
    final res = await createLandlordPaymentLink(
      contractId: widget.contractId,
      billingMonth: ym,
      note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.ok) {
      setState(() => _lastUrl = res.data?['checkout_url']?.toString());
      await _loadExisting();
    } else {
      setState(() => _error = res.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final options = _buildMonthOptions();
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Send payment link',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<DateTime>(
              value: options.contains(_billingMonth)
                  ? _billingMonth
                  : options.first,
              decoration: const InputDecoration(
                labelText: 'Billing month',
                border: OutlineInputBorder(),
              ),
              items: options
                  .map((d) => DropdownMenuItem<DateTime>(
                        value: d,
                        child: Text(_formatBillingMonth(d)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _billingMonth = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            if (_lastUrl != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TenantManagementScreen.bg,
                  border: Border.all(color: TenantManagementScreen.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Checkout URL',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _lastUrl!,
                      style: const TextStyle(
                          fontSize: 12, color: TenantManagementScreen.brand),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: _lastUrl!));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Link copied to clipboard.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy link'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: TenantManagementScreen.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Generate link'),
            ),
            if (_existing.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Recent links',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final l in _existing.take(5)) _existingLinkRow(l),
            ],
          ],
        ),
      ),
    );
  }

  Widget _existingLinkRow(PaymentLinkRow l) {
    final color = switch (l.status) {
      'paid' => VxrTokens.success,
      'pending' => VxrTokens.warning,
      'expired' || 'cancelled' => VxrTokens.textSub,
      _ => VxrTokens.textSub,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: TenantManagementScreen.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatBillingMonth(l.billingMonth)} · ₱${(l.amountCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  l.checkoutUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: TenantManagementScreen.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.status,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: l.checkoutUrl));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied.')),
              );
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}
