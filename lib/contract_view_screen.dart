import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contract_templates.dart';
import 'contract_payment_screen.dart';
import 'property_data.dart';

/// Contract viewing + signing screen used by both tenant and landlord.
///
/// Flow:
///   1. Tenant lands here from unit_details after their application is
///      approved. Sees the pre-filled lease/rent template, signs, taps
///      "Submit Signature". Status advances to awaiting_landlord.
///   2. Landlord lands here from application_view after the tenant has
///      signed. Sees the same template + the tenant's signature, signs,
///      taps "Submit Signature". Status advances to fully_signed.
///   3. Once fully_signed, both parties see the "Proceed to Payment"
///      action which opens [PaymentScreen] with the contract context.
class ContractViewScreen extends StatefulWidget {
  final String applicationId;
  final String listingId;
  final String landlordId;

  const ContractViewScreen({
    super.key,
    required this.applicationId,
    required this.listingId,
    required this.landlordId,
  });

  @override
  State<ContractViewScreen> createState() => _ContractViewScreenState();
}

class _ContractViewScreenState extends State<ContractViewScreen> {
  static const _kPrimary = VxrTokens.accent;
  static const _kSuccess = VxrTokens.success;

  bool _loading = true;
  bool _saving = false;
  String? _errorReason;
  Map<String, dynamic>? _contract;
  Map<String, dynamic>? _listing;
  Map<String, dynamic>? _application;

  // Local signature canvas state
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final _printedNameCtrl = TextEditingController();

  bool get _isLandlord =>
      Supabase.instance.client.auth.currentUser?.id == widget.landlordId;

  String get _statusKey => (_contract?['status'] ?? 'awaiting_tenant').toString();
  String get _listingType => (_contract?['listing_type'] ?? 'lease').toString();

  bool get _canTenantSign =>
      !_isLandlord && _statusKey == 'awaiting_tenant';
  bool get _canLandlordSign =>
      _isLandlord && _statusKey == 'awaiting_landlord';
  bool get _canPay =>
      !_isLandlord && (_statusKey == 'fully_signed' || _statusKey == 'paid');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _printedNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final supa = Supabase.instance.client;
    String? reason;

    // 1. Listing — needed for landlord_id and price fields. Pricing,
    // location, and lease_term live on normalized child tables, so use
    // fetchListingDetails (joins them) and add listing_type +
    // landlord_id from the listings core.
    try {
      final details = await fetchListingDetails(widget.listingId);
      final core = await supa
          .from('listings')
          .select('id, title, listing_type, landlord_id, '
              'contract_template_url, contract_template_name, terms_override')
          .eq('id', widget.listingId)
          .maybeSingle();
      if (details == null && core == null) {
        reason = 'Listing ${widget.listingId} not found or not visible.';
      } else {
        _listing = <String, dynamic>{
          if (details != null) ...details,
          if (core != null) ...Map<String, dynamic>.from(core),
        };
      }
    } catch (e) {
      reason = 'Failed to load listing: $e';
    }

    // 2. Application — needed for tenant_id and tenant info.
    if (reason == null) {
      try {
        final appRow = await supa
            .from('application')
            .select('id, tenant_id, listing_id, first_name, last_name, '
                'email, phone_number, current_address')
            .eq('id', widget.applicationId)
            .maybeSingle();
        if (appRow == null) {
          reason = 'Application ${widget.applicationId} not found or not visible.';
        } else {
          _application = Map<String, dynamic>.from(appRow);
        }
      } catch (e) {
        reason = 'Failed to load application: $e';
      }
    }

    // 3. Resolve real tenant_id + landlord_id from the rows themselves —
    // do not trust whatever the caller passed (Property.landlordId can
    // be null/empty depending on which list view spawned this screen).
    String? tenantId;
    String? landlordId;
    if (reason == null) {
      tenantId = _application?['tenant_id']?.toString();
      landlordId = _listing?['landlord_id']?.toString();
      if (tenantId == null || tenantId.isEmpty) {
        reason = 'Application has no tenant_id.';
      } else if (landlordId == null || landlordId.isEmpty) {
        reason = 'Listing has no landlord_id.';
      }
    }

    // 4. Get-or-create the contract row.
    if (reason == null) {
      try {
        _contract = await getOrCreateContract(
          applicationId: widget.applicationId,
          listingId: widget.listingId,
          tenantId: tenantId!,
          landlordId: landlordId!,
        );
        if (_contract == null) {
          reason = 'Could not get/create the contract row. Most likely the '
              '`contract` table does not exist yet — run '
              'supabase/migrations/application_module.sql in the Supabase '
              'SQL editor, or check RLS policies.';
        }
      } catch (e) {
        reason = 'Contract upsert failed: $e';
      }
    }

    if (reason != null) {
      debugPrint('[ContractViewScreen] $reason');
    }

    if (mounted) {
      setState(() {
        _errorReason = reason;
        _loading = false;
      });
    }
  }

  Future<void> _refreshContract() async {
    final fresh = await Supabase.instance.client
        .from('contract')
        .select()
        .eq('id', _contract!['id'])
        .maybeSingle();
    if (fresh != null && mounted) {
      setState(() => _contract = Map<String, dynamic>.from(fresh));
    }
  }

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  String _encodeSignature() {
    return jsonEncode(_strokes
        .map((s) =>
            s.map((o) => {'x': o.dx, 'y': o.dy}).toList())
        .toList());
  }

  List<List<Offset>> _decodeSignature(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw) as List;
      return parsed
          .map<List<Offset>>((s) => (s as List)
              .map<Offset>(
                  (p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
              .toList())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _submitSignature() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }
    if (_printedNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type your printed name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = _isLandlord
        ? await signContractAsLandlord(
            contractId: _contract!['id'].toString(),
            signaturePayload: _encodeSignature(),
            printedName: _printedNameCtrl.text.trim(),
          )
        : await signContractAsTenant(
            contractId: _contract!['id'].toString(),
            signaturePayload: _encodeSignature(),
            printedName: _printedNameCtrl.text.trim(),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _strokes.clear();
      _currentStroke = [];
      _printedNameCtrl.clear();
      await _refreshContract();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature recorded.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save signature.')),
      );
    }
  }

  void _proceedToPayment() {
    if (_contract == null || _listing == null) return;
    final monthlyRent =
        (_listing!['monthly_rent'] as num?)?.toDouble() ?? 0.0;
    final deposit =
        (_listing!['security_deposit'] as num?)?.toDouble() ?? 0.0;
    final advance =
        (_listing!['advance_payment'] as num?)?.toDouble() ?? 0.0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractPaymentScreen(
          contractId: _contract!['id'].toString(),
          amountPhp: (monthlyRent + deposit + advance).round(),
          listingTitle: _listing?['title']?.toString(),
          monthlyRent: monthlyRent.round(),
          securityDeposit: deposit.round(),
          advancePayment: advance.round(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: Text(_listingType == 'rent'
            ? 'Rental Agreement'
            : 'Lease Agreement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contract == null
              ? _buildUnavailable()
              : _buildBody(),
    );
    return scaffold;
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Contract unavailable',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorReason ?? 'Unknown error.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorReason = null;
                  _contract = null;
                });
                _bootstrap();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statusBanner(),
        const SizedBox(height: 12),
        _contractCard(),
        const SizedBox(height: 16),
        _existingSignaturesCard(),
        const SizedBox(height: 16),
        if (_canTenantSign || _canLandlordSign) _signatureCard(),
        if (_canPay)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: VxrPrimaryButton(
              label: _statusKey == 'paid'
                  ? 'View Payment Details'
                  : 'Proceed to Payment',
              icon: Icons.payments_outlined,
              onPressed: _proceedToPayment,
            ),
          ),
      ],
    );
  }

  Widget _statusBanner() {
    String label;
    Color color;
    switch (_statusKey) {
      case 'awaiting_tenant':
        label = 'Awaiting tenant signature';
        color = Colors.orange;
        break;
      case 'awaiting_landlord':
        label = 'Awaiting landlord signature';
        color = Colors.orange;
        break;
      case 'fully_signed':
        label = 'Fully signed — payment due';
        color = _kSuccess;
        break;
      case 'paid':
        label = 'Paid';
        color = _kSuccess;
        break;
      default:
        label = _statusKey;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _contractCard() {
    final tenantName =
        '${_application?['first_name'] ?? ''} ${_application?['last_name'] ?? ''}'
            .trim();
    final tenantEmail = _application?['email']?.toString() ?? '—';
    final tenantPhone = _application?['phone_number']?.toString() ?? '—';
    final tenantAddress = _application?['current_address']?.toString() ?? '—';

    final propertyTitle = _listing?['title']?.toString() ?? 'Property';
    final propertyAddress = [
      _listing?['full_address'],
      _listing?['city'],
      _listing?['province'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    final monthlyRent = _money(_listing?['monthly_rent']);
    final deposit = _money(_listing?['security_deposit']);
    final advance = _money(_listing?['advance_payment']);
    final term = _listing?['lease_term']?.toString() ?? '—';

    final isLease = _listingType != 'rent';
    final title = contractTitleForType(_listingType);
    final terms = _resolveTerms();
    final uploadedContract = _resolveUploadedContract();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _kvRow('Landlord', '—'), // landlord display name comes later
          _kvRow('Tenant', tenantName.isEmpty ? '—' : tenantName),
          _kvRow('Tenant Contact', '$tenantEmail · $tenantPhone'),
          _kvRow('Tenant Current Address', tenantAddress),
          const Divider(height: 24),
          _kvRow('Property', propertyTitle),
          _kvRow('Property Address',
              propertyAddress.isEmpty ? '—' : propertyAddress),
          _kvRow('Monthly Rent (PHP)', monthlyRent),
          _kvRow('Security Deposit (PHP)', deposit),
          _kvRow('Advance Rent (PHP)', advance),
          _kvRow(isLease ? 'Lease Term' : 'Initial Term',
              isLease ? term : 'Month-to-Month (auto-renews)'),
          if (uploadedContract != null) ...[
            const SizedBox(height: 14),
            _uploadedContractBanner(uploadedContract),
          ],
          const SizedBox(height: 14),
          const Text('TERMS AND CONDITIONS',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xff1f3a68))),
          const SizedBox(height: 8),
          ...terms.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(t, style: const TextStyle(fontSize: 13, height: 1.45)),
              )),
        ],
      ),
    );
  }

  /// Resolve the terms shown on the contract: the landlord's
  /// per-listing override (if any) wins; otherwise we fall back to
  /// the per-type defaults.
  List<String> _resolveTerms() {
    final raw = _listing?['terms_override'];
    if (raw is List) {
      final coerced = raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (coerced.isNotEmpty) return coerced;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final coerced = decoded
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          if (coerced.isNotEmpty) return coerced;
        }
      } catch (_) {/* fall through */}
    }
    return defaultTermsForType(_listingType);
  }

  /// Public URL + filename for a landlord-uploaded contract file,
  /// or null if the listing is using the in-app default template.
  ({String url, String name})? _resolveUploadedContract() {
    final path = _listing?['contract_template_url']?.toString();
    if (path == null || path.isEmpty) return null;
    final name = _listing?['contract_template_name']?.toString() ??
        path.split('/').last;
    final publicUrl = Supabase.instance.client.storage
        .from('listing-contracts')
        .getPublicUrl(path);
    return (url: publicUrl, name: name);
  }

  Widget _uploadedContractBanner(({String url, String name}) info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE0C0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined,
              color: Color(0xFFE07820), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Landlord-provided contract',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE07820),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.name,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'The terms below summarize the agreement; refer to the '
                  'attached file for the binding text.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse(info.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Open'),
            style: TextButton.styleFrom(foregroundColor: _kPrimary),
          ),
        ],
      ),
    );
  }

  Widget _existingSignaturesCard() {
    final tenantStrokes = _decodeSignature(
        _contract?['tenant_signature']?.toString());
    final landlordStrokes = _decodeSignature(
        _contract?['landlord_signature']?.toString());
    final tenantName =
        _contract?['tenant_signed_name']?.toString() ?? '';
    final landlordName =
        _contract?['landlord_signed_name']?.toString() ?? '';
    final tenantAt = _contract?['tenant_signed_at']?.toString();
    final landlordAt = _contract?['landlord_signed_at']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _signatureBlock(
              title: 'Tenant',
              strokes: tenantStrokes,
              name: tenantName,
              at: tenantAt,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _signatureBlock(
              title: 'Landlord',
              strokes: landlordStrokes,
              name: landlordName,
              at: landlordAt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signatureBlock({
    required String title,
    required List<List<Offset>> strokes,
    required String name,
    required String? at,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: strokes.isEmpty
                ? const Center(
                    child: Text('— not signed —',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)))
                : CustomPaint(
                    painter: _SigPainter(strokes: strokes, color: Colors.black),
                    child: const SizedBox.expand(),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(name.isEmpty ? '—' : name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        if (at != null && at.isNotEmpty)
          Text(_formatDate(at),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _signatureCard() {
    final asWho = _isLandlord ? 'Landlord' : 'Tenant';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign as $asWho',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          GestureDetector(
            onPanStart: (d) {
              setState(() {
                _currentStroke = [d.localPosition];
                _strokes.add(_currentStroke);
              });
            },
            onPanUpdate: (d) {
              setState(() => _currentStroke.add(d.localPosition));
            },
            onPanEnd: (_) {
              _currentStroke = [];
            },
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: _SigPainter(strokes: _strokes, color: Colors.black),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearSignature,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear'),
            ),
          ),
          TextField(
            controller: _printedNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Printed Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          VxrPrimaryButton(
            label: 'Sign Contract',
            icon: Icons.draw_outlined,
            loading: _saving,
            onPressed: _submitSignature,
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff1f3a68))),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _money(dynamic raw) {
    final n = (raw is num) ? raw : num.tryParse(raw?.toString() ?? '');
    if (n == null) return '—';
    return 'PHP ${n.toStringAsFixed(2)}';
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  _SigPainter({required this.strokes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(
              stroke.first, 1.25, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = ui.Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        final p0 = stroke[i - 1];
        final p1 = stroke[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}
