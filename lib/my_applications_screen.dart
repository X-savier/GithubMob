import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application_edit_screen.dart';
import 'contract_payment_screen.dart';
import 'contract_view_screen.dart';
import 'in_stay_dashboard_screen.dart';
import 'property_data.dart';
import 'theme/vxr_theme.dart';
import 'unit_details.dart';

/// Tenant-facing inbox of all rental applications they've submitted.
/// Tabs by status (Pending / Approved / Rejected); each row shows a
/// status-aware CTA derived from the contract status when applicable.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  static const _statusOrder = ['pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await fetchMyApplicationsWithListing();
    if (!mounted) return;
    setState(() {
      _rows = data;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _forStatus(String status) =>
      _rows.where((r) => (r['status'] ?? '') == status).toList();

  int _countFor(String status) => _forStatus(status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: const Text('My Applications'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Pending (${_countFor('pending')})'),
            Tab(text: 'Approved (${_countFor('approved')})'),
            Tab(text: 'Rejected (${_countFor('rejected')})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : TabBarView(
              controller: _tabs,
              children: _statusOrder.map(_buildTab).toList(),
            ),
    );
  }

  Widget _buildTab(String status) {
    final rows = _forStatus(status);
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Icon(Icons.inbox_outlined, size: 56, color: VxrTokens.textMuted),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _emptyMessage(status),
                style: GoogleFonts.dmSans(
                    color: VxrTokens.textSub, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ApplicationCard(
          row: rows[i],
          onChanged: _refresh,
        ),
      ),
    );
  }

  String _emptyMessage(String status) {
    switch (status) {
      case 'pending':
        return 'No pending applications.';
      case 'approved':
        return 'No approved applications yet.';
      case 'rejected':
        return 'No rejected applications.';
      default:
        return 'No applications yet.';
    }
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  const _ApplicationCard({required this.row, required this.onChanged});

  String get _status => (row['status'] ?? 'pending').toString();

  Map<String, dynamic> get _listing =>
      (row['listings'] as Map?)?.cast<String, dynamic>() ?? const {};

  Map<String, dynamic>? get _contract {
    final c = row['contract'];
    if (c is Map) return c.cast<String, dynamic>();
    return null;
  }

  String get _title =>
      (_listing['title']?.toString() ?? 'Listing').trim().isEmpty
          ? 'Listing'
          : _listing['title'].toString();

  String get _location {
    final loc = _listing['listing_locations'];
    if (loc is List && loc.isNotEmpty) {
      final m = loc.first;
      if (m is Map) {
        final parts = [m['city'], m['province']]
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        return parts.join(', ');
      }
    }
    return '';
  }

  ({Color color, String label}) get _statusBadge {
    switch (_status) {
      case 'approved':
        return (color: VxrTokens.success, label: 'Approved');
      case 'rejected':
        return (color: VxrTokens.danger, label: 'Rejected');
      default:
        return (color: VxrTokens.warning, label: 'Pending');
    }
  }

  String _formatDate(dynamic iso) {
    final s = iso?.toString();
    if (s == null || s.isEmpty) return '';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final badge = _statusBadge;
    final rent = _listing['monthly_rent'];

    return Container(
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.home_work_outlined, color: badge.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (_location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: VxrTokens.textSub),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (rent != null) '₱$rent / mo',
                        _formatDate(row['submitted_at']),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: VxrTokens.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge.label,
                  style: TextStyle(
                    color: badge.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _actions(context),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    switch (_status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openListing(context),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View listing'),
                style: _ghostStyle(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openEdit(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit details'),
                style: _primaryStyle(),
              ),
            ),
          ],
        );
      case 'rejected':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openListing(context),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('View listing'),
            style: _ghostStyle(),
          ),
        );
      case 'approved':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openListing(context),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View listing'),
                style: _ghostStyle(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _contractCta(context)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _contractCta(BuildContext context) {
    final contract = _contract;
    final contractStatus = (contract?['status'] ?? '').toString();
    final landlordId = _listing['landlord_id']?.toString() ?? '';
    final listingId =
        _listing['id']?.toString() ?? row['listing_id']?.toString() ?? '';
    final appId = row['id']?.toString() ?? '';

    if (contractStatus == 'awaiting_landlord') {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded, size: 16),
        label: const Text('Awaiting landlord'),
        style: _primaryStyle().copyWith(
          backgroundColor:
              WidgetStateProperty.all(VxrTokens.textMuted.withValues(alpha: 0.5)),
        ),
      );
    }

    if (contractStatus == 'fully_signed') {
      return ElevatedButton.icon(
        onPressed: () async {
          final id = contract?['id']?.toString() ?? '';
          if (id.isEmpty) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContractPaymentScreen(
                contractId: id,
                amountPhp: _listing['monthly_rent'] is num
                    ? (_listing['monthly_rent'] as num).toInt()
                    : 0,
                listingTitle: _title,
              ),
            ),
          );
          onChanged();
        },
        icon: const Icon(Icons.payments_outlined, size: 16),
        label: const Text('Proceed to payment'),
        style: _primaryStyle(),
      );
    }

    if (contractStatus == 'paid') {
      return ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InStayDashboardScreen(),
          ),
        ),
        icon: const Icon(Icons.home_outlined, size: 16),
        label: const Text('View rental'),
        style: _primaryStyle(),
      );
    }

    // default: 'awaiting_tenant' or no contract yet → Sign contract
    return ElevatedButton.icon(
      onPressed: (listingId.isEmpty || landlordId.isEmpty || appId.isEmpty)
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContractViewScreen(
                    applicationId: appId,
                    listingId: listingId,
                    landlordId: landlordId,
                  ),
                ),
              );
              onChanged();
            },
      icon: const Icon(Icons.draw_outlined, size: 16),
      label: const Text('Sign contract'),
      style: _primaryStyle(),
    );
  }

  Future<void> _openListing(BuildContext context) async {
    final listingId =
        _listing['id']?.toString() ?? row['listing_id']?.toString() ?? '';
    if (listingId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final raw = await fetchListingDetails(listingId);
    if (raw == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Listing not found.')),
      );
      return;
    }
    if (!context.mounted) return;
    final property = Property.fromMap(raw);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UnitDetailsScreen(property: property)),
    );
    onChanged();
  }

  Future<void> _openEdit(BuildContext context) async {
    final appId = row['id']?.toString() ?? '';
    final tenantId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    if (appId.isEmpty || tenantId.isEmpty) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationEditScreen(
          applicationId: appId,
          tenantId: tenantId,
        ),
      ),
    );
    if (saved == true) onChanged();
  }

  ButtonStyle _ghostStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: VxrTokens.textSub,
      side: const BorderSide(color: VxrTokens.border),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    );
  }

  ButtonStyle _primaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: VxrTokens.accent,
      foregroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      elevation: 0,
    );
  }
}
