import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contract_view_screen.dart';
import 'property_data.dart';

/// Landlord-facing inbox of every contract they're a party to. Shows
/// status badges and lets the landlord jump straight to sign or review
/// without drilling through Listings → Applicants → Approved app.
class LandlordContractsScreen extends StatefulWidget {
  const LandlordContractsScreen({super.key});

  @override
  State<LandlordContractsScreen> createState() =>
      _LandlordContractsScreenState();
}

class _LandlordContractsScreenState extends State<LandlordContractsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await fetchLandlordContracts();
    if (mounted) {
      setState(() {
        _rows = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Tenant Contracts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _row(_rows[i]),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No contracts yet',
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Approve a tenant application and the contract will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final listing = (r['listings'] as Map?) ?? {};
    final application = (r['application'] as Map?) ?? {};
    final title = listing['title']?.toString() ?? 'Listing';
    final tenantName =
        '${application['first_name'] ?? ''} ${application['last_name'] ?? ''}'
            .trim();
    final status = (r['status'] ?? 'awaiting_tenant').toString();
    final listingId = (listing['id'] ?? r['listing_id'])?.toString();
    final applicationId = r['application_id']?.toString();

    final (badgeColor, badgeText) = switch (status) {
      'awaiting_tenant' => (Colors.orange, 'Awaiting tenant'),
      'awaiting_landlord' => (const Color(0xFFE85D5D), 'Sign now'),
      'fully_signed' => (const Color(0xFF1976D2), 'Awaiting payment'),
      'paid' => (const Color(0xFF4CAF50), 'Paid'),
      _ => (Colors.grey, status),
    };

    final canOpen = applicationId != null && listingId != null;
    final landlordId =
        Supabase.instance.client.auth.currentUser?.id ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: canOpen
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContractViewScreen(
                      applicationId: applicationId,
                      listingId: listingId,
                      landlordId: landlordId,
                    ),
                  ),
                );
                _refresh();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_outlined, color: badgeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      tenantName.isEmpty ? 'Tenant' : 'Tenant: $tenantName',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
