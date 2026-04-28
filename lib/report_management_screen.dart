import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'property_data.dart';

/// Role-aware reports screen.
///
/// - When the current user is the tenant on at least one paid contract,
///   they see their own reports + a floating "+ New Report" button.
/// - When the current user owns listings (landlord), they see every
///   report against their properties with status controls and a
///   response box.
///
/// If a user is both, both sections render.
class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  static const Color primaryOrange = Color(0xFFFF7043);
  static const Color darkText = Color(0xFF1A1A2E);
  static const Color lightText = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFEEEEEE);
  static const Color highPriority = Color(0xFFF44336);
  static const Color mediumPriority = Color(0xFFFF9800);
  static const Color lowPriority = Color(0xFF4CAF50);
  static const Color statusOpen = Color(0xFFFF9800);
  static const Color statusInProgress = Color(0xFF2196F3);
  static const Color statusResolved = Color(0xFF4CAF50);
  static const Color statusCancelled = Color(0xFF9E9E9E);

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _isLandlord = false;
  Map<String, dynamic>? _activeRental; // for tenant submit form
  List<Map<String, dynamic>> _myReports = [];
  List<Map<String, dynamic>> _landlordReports = [];

  String _typeFilter = 'All';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      hasUserListings(),
      fetchMyActiveRental(),
      fetchMyReports(),
      fetchLandlordReports(),
    ]);
    if (!mounted) return;
    final isLandlord = results[0] as bool;
    setState(() {
      _isLandlord = isLandlord;
      _activeRental = results[1] as Map<String, dynamic>?;
      _myReports = results[2] as List<Map<String, dynamic>>;
      _landlordReports = results[3] as List<Map<String, dynamic>>;
      // Only build the TabController once we know how many tabs
      // exist; otherwise dispose any prior one.
      final tabCount =
          (_isLandlord && _activeRental != null) ? 2 : 1;
      _tabs?.dispose();
      _tabs = TabController(length: tabCount, vsync: this);
      _loading = false;
    });
  }

  // ── Filters ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    return rows.where((r) {
      if (_typeFilter != 'All' &&
          (r['type']?.toString().toLowerCase() ?? '') !=
              _typeFilter.toLowerCase()) {
        return false;
      }
      if (_statusFilter != 'All' &&
          _normalizeStatus(r['status']?.toString()) != _statusFilter) {
        return false;
      }
      if (_priorityFilter != 'All' &&
          (r['priority']?.toString().toLowerCase() ?? '') !=
              _priorityFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  String _normalizeStatus(String? raw) {
    switch (raw) {
      case 'in_progress':
        return 'In-progress';
      case 'open':
        return 'Open';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw ?? '';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasTenantSection = _activeRental != null;
    final hasLandlordSection = _isLandlord;
    final hasBoth = hasTenantSection && hasLandlordSection;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Reports',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ReportManagementScreen.primaryOrange,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: ReportManagementScreen.primaryOrange),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: ReportManagementScreen.primaryOrange),
            onPressed: _loading ? null : _refresh,
          ),
        ],
        bottom: hasBoth
            ? TabBar(
                controller: _tabs,
                labelColor: ReportManagementScreen.primaryOrange,
                unselectedLabelColor: ReportManagementScreen.lightText,
                indicatorColor: ReportManagementScreen.primaryOrange,
                tabs: const [
                  Tab(text: 'My Reports'),
                  Tab(text: 'Incoming'),
                ],
              )
            : null,
      ),
      floatingActionButton: hasTenantSection
          ? FloatingActionButton.extended(
              onPressed: _openSubmitSheet,
              backgroundColor: ReportManagementScreen.primaryOrange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Report'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasTenantSection && !hasLandlordSection
              ? _emptyAccount()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: hasBoth
                      ? TabBarView(
                          controller: _tabs,
                          children: [
                            _tenantList(),
                            _landlordList(),
                          ],
                        )
                      : hasTenantSection
                          ? _tenantList()
                          : _landlordList(),
                ),
    );
  }

  Widget _emptyAccount() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_gmailerrorred_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No reports yet',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Reports will appear here once you have an active rental '
              '(tenant) or a paid tenant on one of your listings (landlord).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tenant section ────────────────────────────────────────────────

  Widget _tenantList() {
    final filtered = _applyFilters(_myReports);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _filtersRow(),
        const SizedBox(height: 12),
        if (_myReports.isEmpty)
          _sectionEmpty(
            icon: Icons.assignment_outlined,
            title: 'No reports yet',
            subtitle:
                'Tap "New Report" to file a maintenance, cleaning, or noise issue.',
          )
        else if (filtered.isEmpty)
          _sectionEmpty(
            icon: Icons.search_off,
            title: 'No reports match your filters',
            subtitle: 'Reset filters to see everything.',
          )
        else
          for (final r in filtered) ...[
            _reportCard(r, asLandlord: false),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  // ── Landlord section ──────────────────────────────────────────────

  Widget _landlordList() {
    final filtered = _applyFilters(_landlordReports);
    final open = _landlordReports
        .where((r) => r['status'] == 'open' || r['status'] == 'in_progress')
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB199), Color(0xFFFF7043)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.inbox_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$open open / ${_landlordReports.length} total reports',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _filtersRow(),
        const SizedBox(height: 12),
        if (_landlordReports.isEmpty)
          _sectionEmpty(
            icon: Icons.inbox_outlined,
            title: 'Inbox empty',
            subtitle: 'No tenants have filed any reports yet.',
          )
        else if (filtered.isEmpty)
          _sectionEmpty(
            icon: Icons.search_off,
            title: 'No reports match your filters',
            subtitle: 'Reset filters to see everything.',
          )
        else
          for (final r in filtered) ...[
            _reportCard(r, asLandlord: true),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  // ── Filters row ───────────────────────────────────────────────────

  Widget _filtersRow() {
    return Row(
      children: [
        Expanded(
          child: _filterChip(
            value: _typeFilter,
            options: const [
              'All', 'Maintenance', 'Cleaning', 'Amenity', 'Noise', 'Other',
            ],
            onSelected: (v) => setState(() => _typeFilter = v),
            label: 'Type',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterChip(
            value: _statusFilter,
            options: const ['All', 'Open', 'In-progress', 'Resolved'],
            onSelected: (v) => setState(() => _statusFilter = v),
            label: 'Status',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterChip(
            value: _priorityFilter,
            options: const ['All', 'High', 'Medium', 'Low'],
            onSelected: (v) => setState(() => _priorityFilter = v),
            label: 'Priority',
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String value,
    required List<String> options,
    required void Function(String) onSelected,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ReportManagementScreen.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down,
            color: ReportManagementScreen.primaryOrange),
        items: options
            .map((o) => DropdownMenuItem(
                value: o,
                child: Text(o,
                    style: const TextStyle(
                        fontSize: 13,
                        color: ReportManagementScreen.darkText))))
            .toList(),
        onChanged: (v) {
          if (v != null) onSelected(v);
        },
        hint: Text(label,
            style: const TextStyle(
                fontSize: 13, color: ReportManagementScreen.lightText)),
      ),
    );
  }

  // ── Report card ───────────────────────────────────────────────────

  Widget _reportCard(Map<String, dynamic> r, {required bool asLandlord}) {
    final type = (r['type'] ?? 'maintenance').toString();
    final priority = (r['priority'] ?? 'medium').toString();
    final status = (r['status'] ?? 'open').toString();
    final title = (r['title'] ?? '').toString();
    final desc = (r['description'] ?? '').toString();
    final createdAt = r['created_at']?.toString();
    final listing = (r['listings'] as Map?) ?? {};
    final listingTitle = listing['title']?.toString() ?? 'Listing';
    final response = r['landlord_response']?.toString();

    String? tenantName;
    if (asLandlord) {
      final contract = (r['contract'] as Map?) ?? {};
      final app = (contract['application'] as Map?) ??
          (r['application'] as Map?) ??
          {};
      final f = app['first_name']?.toString() ?? '';
      final l = app['last_name']?.toString() ?? '';
      tenantName = '$f $l'.trim();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReportManagementScreen.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _typeColor(type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(type),
                    color: _typeColor(type), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: ReportManagementScreen.darkText)),
                    const SizedBox(height: 2),
                    Text(
                      asLandlord && tenantName != null && tenantName.isNotEmpty
                          ? '$tenantName · $listingTitle'
                          : listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: ReportManagementScreen.lightText),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _priorityChip(priority),
              const SizedBox(width: 6),
              _typeChip(type),
              const Spacer(),
              if (createdAt != null)
                Text(_formatDate(createdAt),
                    style: const TextStyle(
                        fontSize: 11,
                        color: ReportManagementScreen.lightText)),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(desc,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: ReportManagementScreen.darkText)),
          ],
          if (response != null && response.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBDEFB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Landlord response',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0))),
                  const SizedBox(height: 4),
                  Text(response,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
          if (asLandlord) ...[
            const SizedBox(height: 12),
            _landlordActions(r),
          ],
        ],
      ),
    );
  }

  Widget _landlordActions(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'open').toString();
    return Wrap(
      spacing: 8,
      children: [
        if (status != 'in_progress' && status != 'resolved')
          OutlinedButton.icon(
            onPressed: () => _setStatus(r, 'in_progress'),
            icon: const Icon(Icons.engineering, size: 16),
            label: const Text('Mark In-progress'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ReportManagementScreen.statusInProgress,
              side: const BorderSide(
                  color: ReportManagementScreen.statusInProgress),
            ),
          ),
        if (status != 'resolved')
          OutlinedButton.icon(
            onPressed: () => _setStatus(r, 'resolved'),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Resolve'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ReportManagementScreen.statusResolved,
              side: const BorderSide(
                  color: ReportManagementScreen.statusResolved),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _openResponseDialog(r),
          icon: const Icon(Icons.reply, size: 16),
          label: const Text('Respond'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ReportManagementScreen.primaryOrange,
            side:
                const BorderSide(color: ReportManagementScreen.primaryOrange),
          ),
        ),
      ],
    );
  }

  Future<void> _setStatus(Map<String, dynamic> r, String newStatus) async {
    final ok = await updateReportStatus(
        reportId: r['id'].toString(), newStatus: newStatus);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status.')),
      );
    }
  }

  Future<void> _openResponseDialog(Map<String, dynamic> r) async {
    final ctl =
        TextEditingController(text: r['landlord_response']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply to tenant'),
        content: TextField(
          controller: ctl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a quick response…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await respondToReport(
                reportId: r['id'].toString(),
                response: ctl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (saved == true) _refresh();
  }

  // ── Submit sheet (tenant) ─────────────────────────────────────────

  Future<void> _openSubmitSheet() async {
    if (_activeRental == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitReportSheet(rental: _activeRental!),
    );
    if (result == true) _refresh();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _sectionEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ReportManagementScreen.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final label = _normalizeStatus(status);
    final color = switch (status) {
      'open' => ReportManagementScreen.statusOpen,
      'in_progress' => ReportManagementScreen.statusInProgress,
      'resolved' => ReportManagementScreen.statusResolved,
      'cancelled' => ReportManagementScreen.statusCancelled,
      _ => ReportManagementScreen.statusOpen,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _priorityChip(String priority) {
    final color = switch (priority) {
      'high' => ReportManagementScreen.highPriority,
      'medium' => ReportManagementScreen.mediumPriority,
      'low' => ReportManagementScreen.lowPriority,
      _ => ReportManagementScreen.mediumPriority,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
          priority[0].toUpperCase() + priority.substring(1),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'maintenance' => const Color(0xFFFF7043),
        'cleaning' => const Color(0xFF7E57C2),
        'amenity' => const Color(0xFF26A69A),
        'noise' => const Color(0xFFEF5350),
        _ => const Color(0xFF607D8B),
      };

  IconData _typeIcon(String type) => switch (type) {
        'maintenance' => Icons.build_outlined,
        'cleaning' => Icons.cleaning_services_outlined,
        'amenity' => Icons.local_offer_outlined,
        'noise' => Icons.volume_up_outlined,
        _ => Icons.report_outlined,
      };

  String _formatDate(String iso) {
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
// SUBMIT REPORT BOTTOM SHEET (tenant)
// ─────────────────────────────────────────────

class _SubmitReportSheet extends StatefulWidget {
  final Map<String, dynamic> rental;
  const _SubmitReportSheet({required this.rental});

  @override
  State<_SubmitReportSheet> createState() => _SubmitReportSheetState();
}

class _SubmitReportSheetState extends State<_SubmitReportSheet> {
  String _type = 'maintenance';
  String _priority = 'medium';
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }
    final tenantId = Supabase.instance.client.auth.currentUser?.id;
    final landlordId =
        widget.rental['listings']?['landlord_id']?.toString();
    final contractId = widget.rental['id']?.toString();
    final listingId = widget.rental['listing_id']?.toString();
    if (tenantId == null ||
        landlordId == null ||
        contractId == null ||
        listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing rental context.')),
      );
      return;
    }
    setState(() => _saving = true);
    final id = await submitReport(
      contractId: contractId,
      listingId: listingId,
      tenantId: tenantId,
      landlordId: landlordId,
      type: _type,
      priority: _priority,
      title: _titleCtl.text.trim(),
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('New Report',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                widget.rental['listings']?['title']?.toString() ??
                    'Your rental',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(
                      value: 'cleaning', child: Text('Cleaning')),
                  DropdownMenuItem(
                      value: 'amenity', child: Text('Amenity')),
                  DropdownMenuItem(value: 'noise', child: Text('Noise')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setState(() => _type = v ?? 'maintenance'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) =>
                    setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        ReportManagementScreen.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Report',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
