import 'package:flutter/material.dart';

import 'contract_view_screen.dart';
import 'property_data.dart';

/// Tenant-facing inbox of all rental applications they've ever submitted,
/// with their current status. Tap an approved row to jump straight to the
/// contract; pending/rejected rows are non-actionable.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await fetchMyApplicationsWithListing();
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
        title: const Text('My Applications'),
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
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No applications yet',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final listing = (r['listings'] as Map?) ?? {};
    final title = listing['title']?.toString() ?? 'Listing';
    final rent = listing['monthly_rent'];
    final landlordId = listing['landlord_id']?.toString() ?? '';
    final listingId = listing['id']?.toString() ?? r['listing_id']?.toString();
    final status = (r['status'] ?? 'pending').toString();
    final submittedAt = r['submitted_at']?.toString();

    final (badgeColor, badgeText) = switch (status) {
      'approved' => (const Color(0xFF4CAF50), 'Approved'),
      'rejected' => (const Color(0xFFE03C3C), 'Rejected'),
      _ => (const Color(0xFFFF9800), 'Pending'),
    };

    final canOpenContract = status == 'approved' &&
        listingId != null &&
        landlordId.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: canOpenContract
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContractViewScreen(
                      applicationId: r['id'].toString(),
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
                child: Icon(Icons.home_work_outlined, color: badgeColor),
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
                      '${rent != null ? '₱$rent / mo' : ''}'
                      '${submittedAt != null ? ' · ${_formatDate(submittedAt)}' : ''}',
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
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
