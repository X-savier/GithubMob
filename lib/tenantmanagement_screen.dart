import 'package:flutter/material.dart';

import 'payment_screen.dart';
import 'property_data.dart';
import 'report_management_screen.dart';

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

  static const Color brand = Color(0xFFF36C6C);
  static const Color coral = Color(0xFFE8735A);
  static const Color light = Color(0xFFFF8A80);
  static const Color ink = Color(0xFF101321);
  static const Color muted = Color(0xFF6B7280);
  static const Color bg = Color(0xFFFAF7F6);
  static const Color border = Color(0xFFEFE7E5);

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
      fetchActiveTenants(),
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
            Color(0xFFFF8A80),
            Color(0xFFF36C6C),
            Color(0xFFE8735A),
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
}
