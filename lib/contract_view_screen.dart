import 'dart:convert';
import 'dart:ui' as ui;

// ignore: unnecessary_import
import 'package:flutter/gestures.dart';
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
  Map<String, dynamic>? _landlord;

  // Local signature canvas state. _sigRepaint ticks on every pointer move so
  // the CustomPaint repaints without a full ListView rebuild.
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final ValueNotifier<int> _sigRepaint = ValueNotifier<int>(0);
  final _printedNameCtrl = TextEditingController();
  // Used by _encodeSignatureAsPng to read the signing canvas's actual
  // pixel size at submit time, so the rendered PNG matches the user's
  // strokes regardless of screen width.
  final GlobalKey _sigCanvasKey = GlobalKey();

  bool get _isLandlord =>
      Supabase.instance.client.auth.currentUser?.id == widget.landlordId;

  String get _statusKey => (_contract?['status'] ?? 'awaiting_tenant').toString();
  String get _listingType => (_contract?['listing_type'] ?? 'lease').toString();

  // Concurrent-signing model: either party can sign at any time. The sign
  // card is gated by the actual signature column rather than the status
  // string, so a landlord opening a brand-new contract (still
  // 'awaiting_tenant') can sign before the tenant does.
  bool get _tenantSigned =>
      (_contract?['tenant_signature']?.toString().isNotEmpty ?? false);
  bool get _landlordSigned =>
      (_contract?['landlord_signature']?.toString().isNotEmpty ?? false);
  bool get _terminal =>
      _statusKey == 'fully_signed' ||
      _statusKey == 'paid' ||
      _statusKey == 'cancelled';

  bool get _canTenantSign => !_isLandlord && !_tenantSigned && !_terminal;
  bool get _canLandlordSign => _isLandlord && !_landlordSigned && !_terminal;
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
    _sigRepaint.dispose();
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

    // 4. Landlord profile — needed to render the Landlord row + contact on
    // the contract card. Non-fatal: if RLS or a missing row blocks the
    // read, the card just falls back to '—'.
    if (reason == null) {
      try {
        final lp = await supa
            .from('profiles')
            .select('full_name, phone, email')
            .eq('id', landlordId!)
            .maybeSingle();
        if (lp != null) _landlord = Map<String, dynamic>.from(lp);
      } catch (e) {
        debugPrint('Failed to load landlord profile: $e');
      }
    }

    // 5. Get-or-create the contract row.
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

    // 6. Self-healing (mirrors the web ContractView.jsx load-time fix-up):
    //   * If the listing's listing_type changed AFTER the contract was
    //     created (landlord flipped lease↔rent), realign the contract row
    //     so the tenant doesn't see stale terms.
    //   * If contract.monthly_rent is 0/null but listing_financials has a
    //     value, backfill so the payment screen doesn't show ₱0.
    if (reason == null && _contract != null) {
      final patch = <String, dynamic>{};
      final listingType = _listing?['listing_type']?.toString();
      if (listingType != null &&
          listingType.isNotEmpty &&
          _contract!['listing_type']?.toString() != listingType) {
        patch['listing_type'] = listingType;
        _contract!['listing_type'] = listingType;
      }
      num? numOf(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '');
      final cRent = numOf(_contract!['monthly_rent']) ?? 0;
      final lRent = numOf(_listing?['monthly_rent']) ?? 0;
      if (cRent == 0 && lRent > 0) {
        patch['monthly_rent'] = lRent;
        _contract!['monthly_rent'] = lRent;
      }
      // Backfill deposit / advance independently of monthly_rent — the
      // contract row often has monthly_rent populated but these two columns
      // at 0/null, which was making the payment screen show ₱0 for them.
      final lDep = numOf(_listing?['security_deposit']) ?? 0;
      final lAdv = numOf(_listing?['advance_payment']) ?? 0;
      if ((numOf(_contract!['security_deposit']) ?? 0) == 0 && lDep > 0) {
        patch['security_deposit'] = lDep;
        _contract!['security_deposit'] = lDep;
      }
      if ((numOf(_contract!['advance_rent']) ?? 0) == 0 && lAdv > 0) {
        patch['advance_rent'] = lAdv;
        _contract!['advance_rent'] = lAdv;
      }
      if (patch.isNotEmpty) {
        try {
          await updateContract(_contract!['id'].toString(), patch);
        } catch (_) {/* non-fatal */}
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
    _sigRepaint.value++;
  }

  // Stroke handlers wired into the RawGestureDetector below. We only call
  // setState on start/end so _strokes.isEmpty (read by the submit handler and
  // the "Sign here" hint) stays consistent; per-pointer-sample updates just
  // tick _sigRepaint so the CustomPaint redraws without rebuilding the page.
  void _onSigStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
      _strokes.add(_currentStroke);
    });
  }

  void _onSigUpdate(DragUpdateDetails d) {
    _currentStroke.add(d.localPosition);
    _sigRepaint.value++;
  }

  void _onSigEnd(DragEndDetails _) {
    _currentStroke = [];
  }

  /// Flatten the live strokes to a `data:image/png;base64,...` data URL
  /// that round-trips through the shared `*_signature` text column.
  ///
  /// The web (and post-fix mobile) renders this directly as an image.
  /// We render at the canvas's actual on-screen pixel size so the
  /// strokes — captured in that same local coord space — land in the
  /// right place inside the PNG.
  Future<String> _encodeSignatureAsPng() async {
    final ctx = _sigCanvasKey.currentContext;
    final renderBox = ctx?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(600, 200);
    final width = size.width <= 0 ? 600.0 : size.width;
    final height = size.height <= 0 ? 200.0 : size.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    // Solid white background so the PNG isn't transparent when displayed
    // over coloured surfaces (web <img> on a tinted card, etc).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );
    _SigPainter.drawStrokesOnCanvas(canvas, _strokes, Colors.black);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode signature PNG');
    }
    final bytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  /// Parse legacy stroke-JSON signatures (the original mobile format).
  /// Returns an empty list for PNG data URLs and any malformed input —
  /// callers should detect the PNG format separately and route to
  /// [Image.memory] instead of [_SigPainter].
  List<List<Offset>> _decodeSignature(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    if (raw.startsWith('data:image/')) return const [];
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
    final String signaturePayload;
    try {
      signaturePayload = await _encodeSignatureAsPng();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to render signature: $e')),
      );
      return;
    }
    final ok = _isLandlord
        ? await signContractAsLandlord(
            contractId: _contract!['id'].toString(),
            signaturePayload: signaturePayload,
            printedName: _printedNameCtrl.text.trim(),
          )
        : await signContractAsTenant(
            contractId: _contract!['id'].toString(),
            signaturePayload: signaturePayload,
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
    // Resolve via _ctxNum so the values charged on the payment screen come
    // from the same resolver as the values displayed on the contract card —
    // i.e. a contract row holding 0 falls back to the listing instead of
    // silently passing 0 through.
    final monthlyRent =
        (_ctxNum('monthly_rent', listingKey: 'monthly_rent') ?? 0).toDouble();
    final deposit =
        (_ctxNum('security_deposit', listingKey: 'security_deposit') ?? 0)
            .toDouble();
    final advance =
        (_ctxNum('advance_rent', listingKey: 'advance_payment') ?? 0)
            .toDouble();
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

  /// Landlord-only: bottom sheet that exposes every editable field on
  /// the contract row. Submitting calls `updateContract` and refetches
  /// so the rendered card reflects the new values immediately.
  Future<void> _openEditorSheet() async {
    if (_contract == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ContractEditorSheet(initial: _contract!),
    );
    if (result == null || result.isEmpty) return;
    final ok = await updateContract(_contract!['id'].toString(), result);
    if (!mounted) return;
    if (ok) {
      await _refreshContract();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract details updated.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update contract.')),
      );
    }
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
    if (_statusKey == 'paid') {
      label = 'Paid';
      color = _kSuccess;
    } else if (_statusKey == 'cancelled') {
      label = 'Cancelled';
      color = Colors.grey;
    } else if (_tenantSigned && _landlordSigned) {
      label = 'Fully signed — payment due';
      color = _kSuccess;
    } else if (_tenantSigned && !_landlordSigned) {
      label = 'Awaiting landlord signature';
      color = Colors.orange;
    } else if (!_tenantSigned && _landlordSigned) {
      label = 'Awaiting tenant signature';
      color = Colors.orange;
    } else {
      label = 'Awaiting signatures from both parties';
      color = Colors.orange;
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

  /// Read a value preferring the contract row (post-editor) before
  /// falling back to listing/application. Returns null for empty values.
  String? _ctxStr(String contractKey, {String? listingKey, String? applicationKey}) {
    final c = _contract?[contractKey]?.toString().trim();
    if (c != null && c.isNotEmpty) return c;
    if (listingKey != null) {
      final l = _listing?[listingKey]?.toString().trim();
      if (l != null && l.isNotEmpty) return l;
    }
    if (applicationKey != null) {
      final a = _application?[applicationKey]?.toString().trim();
      if (a != null && a.isNotEmpty) return a;
    }
    return null;
  }

  num? _ctxNum(String contractKey, {String? listingKey}) {
    num? coerce(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '');
    final c = coerce(_contract?[contractKey]);
    if (c != null && c > 0) return c;
    if (listingKey != null) {
      final l = coerce(_listing?[listingKey]);
      if (l != null) return l;
    }
    return null;
  }

  Widget _contractCard() {
    // Landlord — contract row first (filled by getOrCreateContract /
    // landlord edits), profiles fallback.
    final landlordName = _ctxStr('landlord_name') ??
        _landlord?['full_name']?.toString().trim() ??
        '';
    final landlordEmail = _landlord?['email']?.toString().trim() ?? '';
    final landlordPhone =
        _ctxStr('landlord_contact') ?? _landlord?['phone']?.toString().trim() ?? '';
    final landlordContact = [landlordEmail, landlordPhone]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    // Tenant — contract row first, application fallback.
    final tenantName = _ctxStr('tenant_name') ??
        '${_application?['first_name'] ?? ''} ${_application?['last_name'] ?? ''}'
            .trim();
    final tenantEmail = _application?['email']?.toString() ?? '—';
    final tenantPhone =
        _ctxStr('tenant_contact') ?? _application?['phone_number']?.toString() ?? '—';
    final tenantAddress = _application?['current_address']?.toString() ?? '—';

    // Property — contract row first, listings + listings_full fallback.
    final propertyTitle = _listing?['title']?.toString() ?? 'Property';
    final propertyAddress = _ctxStr('property_address') ??
        [
          _listing?['full_address'],
          _listing?['city'],
          _listing?['province'],
        ]
            .where((e) => e != null && e.toString().isNotEmpty)
            .join(', ');
    final propertyType = _ctxStr('property_type', listingKey: 'property_type') ?? '';
    final monthlyRent = _money(
        _ctxNum('monthly_rent', listingKey: 'monthly_rent') ?? _listing?['monthly_rent']);
    final deposit = _money(_ctxNum('security_deposit', listingKey: 'security_deposit') ??
        _listing?['security_deposit']);
    final advance = _money(
        _ctxNum('advance_rent', listingKey: 'advance_payment') ?? _listing?['advance_payment']);
    final term = _ctxStr('duration', listingKey: 'lease_term') ?? '—';

    final isLease = _listingType != 'rent';

    // Lease start / end / agreement dates. Contract row first
    // (contract.start_date / contract.end_date), listings availability
    // fallback. End date is only relevant for fixed-term leases.
    final cStartIso = _contract?['start_date']?.toString();
    final cEndIso = _contract?['end_date']?.toString();
    final availableFromIso = (cStartIso != null && cStartIso.isNotEmpty)
        ? cStartIso
        : _listing?['available_from']?.toString();
    final startDate = _formatLongDateFromIso(availableFromIso);
    String? endDate;
    if (isLease) {
      if (cEndIso != null && cEndIso.isNotEmpty) {
        endDate = _formatLongDateFromIso(cEndIso);
      } else if (availableFromIso != null && availableFromIso.isNotEmpty) {
        final start = DateTime.tryParse(availableFromIso);
        if (start != null) {
          endDate = _formatLongDate(_addLeaseTerm(start, term));
        }
      }
    }
    final agreementDate = _formatLongDateFromIso(
            _contract?['entered_on']?.toString() ??
                _contract?['created_at']?.toString()) ??
        _formatLongDate(DateTime.now());

    final title = contractTitleForType(_listingType);
    final terms = _resolveTerms();
    final uploadedContract = _resolveUploadedContract();

    // Landlord can edit before signatures lock the contract in. Once
    // either party has signed we hide the affordance so the values can't
    // drift away from the signed agreement.
    final canEdit = _isLandlord &&
        _statusKey == 'awaiting_tenant' &&
        (_contract?['tenant_signature'] == null) &&
        (_contract?['landlord_signature'] == null);

    // Optional landlord-set bits that are useful to surface when present.
    final paymentDueDate = _contract?['payment_due_date'];
    final gracePeriod = _contract?['grace_period_days'];
    final lateFee = _ctxNum('late_fee');
    final paymentMethod = _ctxStr('payment_method');
    final accountInfo = _ctxStr('account_info');
    final quietHours = _ctxStr('quiet_hours');

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
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              if (canEdit)
                IconButton(
                  onPressed: _openEditorSheet,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: _kPrimary,
                  tooltip: 'Edit contract details',
                ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Agreement Date: $agreementDate',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          _kvRow('Landlord', landlordName.isEmpty ? '—' : landlordName),
          _kvRow('Landlord Contact',
              landlordContact.isEmpty ? '—' : landlordContact),
          _kvRow('Tenant', tenantName.isEmpty ? '—' : tenantName),
          _kvRow('Tenant Contact', '$tenantEmail · $tenantPhone'),
          _kvRow('Tenant Current Address', tenantAddress),
          const Divider(height: 24),
          _kvRow('Property', propertyTitle),
          _kvRow('Property Address',
              propertyAddress.isEmpty ? '—' : propertyAddress),
          _kvRow('Property Type', propertyType.isEmpty ? '—' : propertyType),
          _kvRow(isLease ? 'Lease Start Date' : 'Rental Start Date',
              startDate ?? '—'),
          if (isLease)
            _kvRow('Lease End Date', endDate ?? '—'),
          _kvRow('Monthly Rent (PHP)', monthlyRent),
          _kvRow('Security Deposit (PHP)', deposit),
          _kvRow('Advance Rent (PHP)', advance),
          _kvRow(isLease ? 'Lease Term' : 'Initial Term',
              isLease ? term : 'Month-to-Month (auto-renews)'),
          if (paymentDueDate != null)
            _kvRow('Payment Due', 'Day ${paymentDueDate.toString()} of each month'),
          if (gracePeriod != null)
            _kvRow('Grace Period', '${gracePeriod.toString()} days'),
          if (lateFee != null)
            _kvRow('Late Fee (PHP)', _money(lateFee)),
          if (paymentMethod != null) _kvRow('Payment Method', paymentMethod),
          if (accountInfo != null) _kvRow('Account Info', accountInfo),
          if (quietHours != null) _kvRow('Quiet Hours', quietHours),
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
    final tenantRaw = _contract?['tenant_signature']?.toString();
    final landlordRaw = _contract?['landlord_signature']?.toString();
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
              rawSignature: tenantRaw,
              name: tenantName,
              at: tenantAt,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _signatureBlock(
              title: 'Landlord',
              rawSignature: landlordRaw,
              name: landlordName,
              at: landlordAt,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the actual ink display for an existing signature, handling
  /// both the new base64-PNG format and the legacy stroke-JSON format.
  /// Returns null when there's nothing renderable (caller shows
  /// "— not signed —").
  Widget? _signatureInk(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'signed') return null;
    if (raw.startsWith('data:image/')) {
      final commaIdx = raw.indexOf(',');
      if (commaIdx < 0) return null;
      try {
        final bytes = base64Decode(raw.substring(commaIdx + 1));
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return null;
      }
    }
    final strokes = _decodeSignature(raw);
    if (strokes.isEmpty) return null;
    return CustomPaint(
      painter: _SigPainter(
        strokes: strokes,
        color: Colors.black,
        strokeWidth: 4.5,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _signatureBlock({
    required String title,
    required String? rawSignature,
    required String name,
    required String? at,
  }) {
    final ink = _signatureInk(rawSignature);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ink ??
                const Center(
                  child: Text('— not signed —',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
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
          RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              _ImmediatePanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _ImmediatePanGestureRecognizer>(
                () => _ImmediatePanGestureRecognizer(debugOwner: this),
                (r) => r
                  ..onStart = _onSigStart
                  ..onUpdate = _onSigUpdate
                  ..onEnd = _onSigEnd,
              ),
            },
            child: Container(
              key: _sigCanvasKey,
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_strokes.isEmpty)
                      const IgnorePointer(
                        child: Align(
                          alignment: Alignment(0, 0.55),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sign here',
                                style: TextStyle(
                                  color: Color(0xFFB0B0B0),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              SizedBox(
                                width: 220,
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFD0D0D0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    CustomPaint(
                      painter: _SigPainter(
                        strokes: _strokes,
                        color: Colors.black,
                        repaint: _sigRepaint,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ],
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

  static const List<String> _kMonthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatLongDate(DateTime d) =>
      '${_kMonthNames[d.month - 1]} ${d.day}, ${d.year}';

  String? _formatLongDateFromIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    return d == null ? null : _formatLongDate(d);
  }

  // Mirrors manage_listing.dart's _addLeaseTerm: parses the leading number
  // out of "6 months", "1 year", etc. and adds that many months to the
  // start date. Defaults to 12 months when the term is unparseable.
  DateTime _addLeaseTerm(DateTime start, String term) {
    final match = RegExp(r'(\d+)').firstMatch(term);
    final months = int.tryParse(match?.group(1) ?? '') ?? 12;
    return DateTime(start.year, start.month + months, start.day);
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;
  _SigPainter({
    required this.strokes,
    required this.color,
    this.strokeWidth = 3.0,
    Listenable? repaint,
  }) : super(repaint: repaint);

  // Shared with _encodeSignatureAsPng so the exported PNG looks
  // identical to the live preview the user drew on.
  static void drawStrokesOnCanvas(
    Canvas canvas,
    List<List<Offset>> strokes,
    Color color, {
    double strokeWidth = 3.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(
              stroke.first, 1.5, paint..style = PaintingStyle.fill);
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
  void paint(Canvas canvas, Size size) {
    drawStrokesOnCanvas(canvas, strokes, color, strokeWidth: strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}

/// A [PanGestureRecognizer] that claims the gesture on the very first pointer
/// event instead of waiting for the standard touch slop. The signature pad
/// lives inside a vertically scrolling [ListView]; the default pan recognizer
/// loses early frames to the scroll recognizer, which (a) drops the first
/// ~18 px of every stroke and (b) sometimes scrolls the page instead of
/// drawing. Accepting immediately means the pad gets the gesture as soon as
/// the finger lands.
class _ImmediatePanGestureRecognizer extends PanGestureRecognizer {
  _ImmediatePanGestureRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
          PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) =>
      true;
}

/// Landlord-only bottom sheet for editing the contract's editor columns.
/// Pops with a `Map<String, dynamic>` patch the caller forwards to
/// `updateContract`, or pops with `null` on cancel.
class _ContractEditorSheet extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _ContractEditorSheet({required this.initial});

  @override
  State<_ContractEditorSheet> createState() => _ContractEditorSheetState();
}

class _ContractEditorSheetState extends State<_ContractEditorSheet> {
  late final _formKey = GlobalKey<FormState>();
  late final _landlordName = _ctl('landlord_name');
  late final _landlordContact = _ctl('landlord_contact');
  late final _tenantName = _ctl('tenant_name');
  late final _tenantContact = _ctl('tenant_contact');
  late final _propertyAddress = _ctl('property_address');
  late final _propertyType = _ctl('property_type');
  late final _duration = _ctl('duration');
  late final _monthlyRent = _ctl('monthly_rent');
  late final _securityDeposit = _ctl('security_deposit');
  late final _advanceRent = _ctl('advance_rent');
  late final _paymentDueDate = _ctl('payment_due_date');
  late final _gracePeriodDays = _ctl('grace_period_days');
  late final _lateFee = _ctl('late_fee');
  late final _minorRepairsThreshold = _ctl('minor_repairs_threshold');
  late final _quietHours = _ctl('quiet_hours');
  late final _overnightGuestThreshold = _ctl('overnight_guest_threshold');
  late final _governingCity = _ctl('governing_city');
  late final _paymentMethod = _ctl('payment_method');
  late final _accountInfo = _ctl('account_info');

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _enteredOn;

  TextEditingController _ctl(String key) =>
      TextEditingController(text: widget.initial[key]?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _startDate = _parseDate(widget.initial['start_date']);
    _endDate = _parseDate(widget.initial['end_date']);
    _enteredOn = _parseDate(widget.initial['entered_on']);
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final c in [
      _landlordName,
      _landlordContact,
      _tenantName,
      _tenantContact,
      _propertyAddress,
      _propertyType,
      _duration,
      _monthlyRent,
      _securityDeposit,
      _advanceRent,
      _paymentDueDate,
      _gracePeriodDays,
      _lateFee,
      _minorRepairsThreshold,
      _quietHours,
      _overnightGuestThreshold,
      _governingCity,
      _paymentMethod,
      _accountInfo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(
      DateTime? current, void Function(DateTime?) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    num? numOf(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return num.tryParse(t);
    }

    int? intOf(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }

    String? strOf(String s) {
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    final patch = <String, dynamic>{
      'landlord_name': strOf(_landlordName.text),
      'landlord_contact': strOf(_landlordContact.text),
      'tenant_name': strOf(_tenantName.text),
      'tenant_contact': strOf(_tenantContact.text),
      'property_address': strOf(_propertyAddress.text),
      'property_type': strOf(_propertyType.text),
      'duration': strOf(_duration.text),
      'monthly_rent': numOf(_monthlyRent.text),
      'security_deposit': numOf(_securityDeposit.text),
      'advance_rent': numOf(_advanceRent.text),
      'payment_due_date': intOf(_paymentDueDate.text),
      'grace_period_days': intOf(_gracePeriodDays.text),
      'late_fee': numOf(_lateFee.text),
      'minor_repairs_threshold': numOf(_minorRepairsThreshold.text),
      'quiet_hours': strOf(_quietHours.text),
      'overnight_guest_threshold': intOf(_overnightGuestThreshold.text),
      'governing_city': strOf(_governingCity.text),
      'payment_method': strOf(_paymentMethod.text),
      'account_info': strOf(_accountInfo.text),
      'entered_on': _enteredOn == null ? null : _fmtDate(_enteredOn!),
      'start_date': _startDate == null ? null : _fmtDate(_startDate!),
      'end_date': _endDate == null ? null : _fmtDate(_endDate!),
    };
    Navigator.pop(context, patch);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Edit contract details',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('Parties'),
                      _row(_landlordName, 'Landlord Name'),
                      _row(_landlordContact, 'Landlord Contact'),
                      _row(_tenantName, 'Tenant Name'),
                      _row(_tenantContact, 'Tenant Contact'),
                      _section('Property'),
                      _row(_propertyAddress, 'Property Address'),
                      _row(_propertyType, 'Property Type'),
                      _section('Dates'),
                      _dateRow('Entered On', _enteredOn,
                          (d) => _enteredOn = d),
                      _dateRow(
                          'Start Date', _startDate, (d) => _startDate = d),
                      _dateRow('End Date (fixed-term only)', _endDate,
                          (d) => _endDate = d),
                      _row(_duration, 'Duration (e.g. "6 months", "1 year")'),
                      _section('Financials (PHP)'),
                      _row(_monthlyRent, 'Monthly Rent', numeric: true),
                      _row(_securityDeposit, 'Security Deposit', numeric: true),
                      _row(_advanceRent, 'Advance Rent', numeric: true),
                      _row(_lateFee, 'Late Fee', numeric: true),
                      _row(_minorRepairsThreshold,
                          'Minor Repairs Threshold', numeric: true),
                      _section('Payment'),
                      _row(_paymentDueDate, 'Payment Due Day (1–31)',
                          numeric: true),
                      _row(_gracePeriodDays, 'Grace Period (days)',
                          numeric: true),
                      _row(_paymentMethod,
                          'Payment Method (e.g. GCash, Bank Transfer)'),
                      _row(_accountInfo, 'Account Info'),
                      _section('House Rules'),
                      _row(_quietHours, 'Quiet Hours (e.g. "10pm – 7am")'),
                      _row(_overnightGuestThreshold,
                          'Overnight Guest Threshold (nights)',
                          numeric: true),
                      _row(_governingCity, 'Governing City'),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VxrTokens.accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xff1f3a68))),
      );

  Widget _row(TextEditingController ctl, String label, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dateRow(
      String label, DateTime? value, void Function(DateTime?) onPicked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _pickDate(value, onPicked),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(value == null ? '—' : _fmtDate(value),
                    style: const TextStyle(fontSize: 14)),
              ),
              if (value != null)
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => onPicked(null)),
                  icon: const Icon(Icons.clear),
                ),
              const Icon(Icons.calendar_today_outlined, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
