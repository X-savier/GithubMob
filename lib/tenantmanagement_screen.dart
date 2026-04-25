import 'package:flutter/material.dart';

import 'payment_screen.dart';
import 'property_data.dart';
import 'report_management_screen.dart';

/// Landlord-facing tenant management. Lists every active tenant
/// (contract status='paid') across all the landlord's listings with
/// quick links to contact, view payments, or open the reports queue.
class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  static const Color primaryOrange = Color(0xFFFF7043);
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color borderColor = Color(0xFFEEEEEE);

  @override
  State<TenantManagementScreen> createState() =>
      _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _tenants = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await fetchActiveTenants();
    if (mounted) {
      setState(() {
        _tenants = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tenant Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: TenantManagementScreen.darkText,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: TenantManagementScreen.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: TenantManagementScreen.darkText),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Active Tenants',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: TenantManagementScreen.primaryOrange,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      _tenants.isEmpty
                          ? 'No active tenants yet.'
                          : '${_tenants.length} active tenant${_tenants.length == 1 ? '' : 's'} across your listings.',
                      style: const TextStyle(
                          fontSize: 13,
                          color: TenantManagementScreen.lightText),
                    ),
                  ),
                  if (_tenants.isEmpty) _emptyState() else
                    for (final t in _tenants) ...[
                      _tenantCard(t),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TenantManagementScreen.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No active tenants yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: TenantManagementScreen.darkText)),
          const SizedBox(height: 4),
          Text(
            'Tenants appear here once their contract is fully signed and paid.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _tenantCard(Map<String, dynamic> t) {
    final listing = (t['listings'] as Map?) ?? {};
    final app = (t['application'] as Map?) ?? {};
    final tenantName =
        '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}'.trim();
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TenantManagementScreen.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    TenantManagementScreen.primaryOrange.withValues(alpha: 0.15),
                child: Text(
                  tenantName.isEmpty
                      ? '?'
                      : tenantName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: TenantManagementScreen.primaryOrange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenantName.isEmpty ? 'Tenant' : tenantName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: TenantManagementScreen.darkText)),
                    const SizedBox(height: 2),
                    Text(propertyTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: TenantManagementScreen.lightText)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Active',
                    style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _kv('Move-in', movedIn)),
              Expanded(
                  child: _kv('Days in stay',
                      daysSinceMoveIn?.toString() ?? '—')),
            ],
          ),
          if (email.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (email.isNotEmpty)
                  Expanded(child: _kv('Email', email)),
                if (phone.isNotEmpty)
                  Expanded(child: _kv('Phone', phone)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: TenantManagementScreen.borderColor)),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _action(
                  icon: Icons.report_problem,
                  label: 'Reports',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportManagementScreen(),
                    ),
                  ),
                ),
                Container(
                    height: 22,
                    width: 1,
                    color: TenantManagementScreen.borderColor),
                _action(
                  icon: Icons.payments_outlined,
                  label: 'Payments',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        contractId: t['id']?.toString(),
                      ),
                    ),
                  ),
                ),
                Container(
                    height: 22,
                    width: 1,
                    color: TenantManagementScreen.borderColor),
                _action(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: TenantManagementScreen.primaryOrange),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: TenantManagementScreen.primaryOrange)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: TenantManagementScreen.lightText)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TenantManagementScreen.darkText)),
      ],
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
