import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _sb = Supabase.instance.client;

class PaymentsResult<T> {
  final T? data;
  final String? error;
  const PaymentsResult({this.data, this.error});
  bool get ok => error == null;
}

/// Ask the paymongo-create-payment-intent Edge Function for a PayMongo
/// PaymentIntent. Pass [billingMonth] (YYYY-MM or YYYY-MM-DD) to charge a
/// single month's rent (recurring); omit it for the move-in payment.
Future<PaymentsResult<Map<String, dynamic>>> createPaymongoPaymentIntent(
  String? contractId, {
  String? billingMonth,
}) async {
  if (contractId == null || contractId.isEmpty) {
    return const PaymentsResult(error: 'Missing contractId');
  }
  try {
    final body = <String, dynamic>{'contract_id': contractId};
    if (billingMonth != null && billingMonth.isNotEmpty) {
      body['billing_month'] = billingMonth;
    }
    final res = await _sb.functions
        .invoke('paymongo-create-payment-intent', body: body);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return PaymentsResult(error: data['error'].toString());
    }
    return PaymentsResult(data: Map<String, dynamic>.from(data as Map));
  } catch (e) {
    return PaymentsResult(error: e.toString());
  }
}

/// Landlord-only: record a payment received outside the app (cash,
/// direct GCash, manual bank transfer). Server gates on
/// auth.uid() === contract.landlord_id and contract.status='paid'.
Future<PaymentsResult<Map<String, dynamic>>> recordOfflinePayment({
  required String contractId,
  required num amountPhp,
  required String methodType,
  String? billingMonth,
  DateTime? paidAt,
  String? note,
}) async {
  if (contractId.isEmpty) return const PaymentsResult(error: 'Missing contractId');
  if (amountPhp <= 0) return const PaymentsResult(error: 'amountPhp must be > 0');
  if (methodType.isEmpty) return const PaymentsResult(error: 'Missing methodType');
  try {
    final body = <String, dynamic>{
      'contract_id': contractId,
      'amount_php': amountPhp,
      'method_type': methodType,
      'billing_month': billingMonth,
      'paid_at': paidAt?.toIso8601String(),
      'note': note,
    };
    final res = await _sb.functions
        .invoke('landlord-record-offline-payment', body: body);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return PaymentsResult(error: data['error'].toString());
    }
    return PaymentsResult(data: Map<String, dynamic>.from(data as Map));
  } catch (e) {
    return PaymentsResult(error: e.toString());
  }
}

/// Landlord-only: generate a PayMongo Link for a tenant's monthly rent.
/// Returns a hosted checkout URL the tenant can pay from any device.
Future<PaymentsResult<Map<String, dynamic>>> createLandlordPaymentLink({
  required String contractId,
  required String billingMonth,
  String? note,
  DateTime? expiresAt,
}) async {
  if (contractId.isEmpty) return const PaymentsResult(error: 'Missing contractId');
  if (billingMonth.isEmpty) return const PaymentsResult(error: 'Missing billingMonth');
  try {
    final body = <String, dynamic>{
      'contract_id': contractId,
      'billing_month': billingMonth,
      'note': note,
      'expires_at': expiresAt?.toIso8601String(),
    };
    final res = await _sb.functions
        .invoke('paymongo-create-payment-link', body: body);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return PaymentsResult(error: data['error'].toString());
    }
    return PaymentsResult(data: Map<String, dynamic>.from(data as Map));
  } catch (e) {
    return PaymentsResult(error: e.toString());
  }
}

/// List the open/recent payment links a landlord has generated for a
/// given contract. Both tenant and landlord can SELECT via RLS.
Future<List<PaymentLinkRow>> fetchPaymentLinks(String contractId) async {
  if (contractId.isEmpty) return const [];
  try {
    final rows = await _sb
        .from('payment_links')
        .select(
            'id, billing_month, amount_cents, checkout_url, status, expires_at, created_at, note')
        .eq('contract_id', contractId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => PaymentLinkRow.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<PaymentsResult<Map<String, dynamic>>> attachPaymentMethod({
  required String paymentIntentId,
  required String paymentMethodId,
  required String returnUrl,
  String? paymentMethodRecordId,
}) async {
  try {
    final res =
        await _sb.functions.invoke('paymongo-attach-payment-method', body: {
      'payment_intent_id': paymentIntentId,
      'payment_method_id': paymentMethodId,
      'return_url': returnUrl,
      'payment_method_record_id': paymentMethodRecordId,
    });
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return PaymentsResult(error: data['error'].toString());
    }
    return PaymentsResult(data: Map<String, dynamic>.from(data as Map));
  } catch (e) {
    return PaymentsResult(error: e.toString());
  }
}

Future<PaymentsResult<void>> recordPaymongoPayment(
    String contractId, String paymentIntentId) async {
  try {
    final res = await _sb.functions.invoke('paymongo-record-payment', body: {
      'contract_id': contractId,
      'payment_intent_id': paymentIntentId,
    });
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return PaymentsResult(error: data['error'].toString());
    }
    return const PaymentsResult();
  } catch (e) {
    return PaymentsResult(error: e.toString());
  }
}

Future<PaymentsResult<Map<String, dynamic>>> recordMockPayment({
  required String contractId,
  required String paymentMethodRecordId,
}) async {
  try {
    final res =
        await _sb.functions.invoke('paymongo-record-mock-payment', body: {
      'contract_id': contractId,
      'payment_method_record_id': paymentMethodRecordId,
    });
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return PaymentsResult(error: data['error'].toString());
    }
    return PaymentsResult(data: Map<String, dynamic>.from(data as Map));
  } catch (e) {
    return PaymentsResult(error: e.toString());
  }
}

class PaymentTransactionRow {
  final String id;
  final int amountCents;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final String? paymongoPaymentIntentId;
  final String? contractId;
  final String? methodType;
  final String? brand;
  final String? last4;
  final String? failureReason;
  final String? listingTitle;
  final String? recordedBy;
  final String? note;
  final DateTime? billingMonth;

  const PaymentTransactionRow({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.paidAt,
    required this.paymongoPaymentIntentId,
    required this.contractId,
    required this.methodType,
    required this.brand,
    required this.last4,
    required this.failureReason,
    required this.listingTitle,
    required this.recordedBy,
    required this.note,
    required this.billingMonth,
  });

  factory PaymentTransactionRow.fromMap(Map<String, dynamic> r) {
    final created = r['created_at'];
    final billing = r['billing_month'];
    return PaymentTransactionRow(
      id: r['id'].toString(),
      amountCents: (r['amount_cents'] as num?)?.toInt() ?? 0,
      currency: (r['currency'] ?? 'php').toString(),
      status: (r['status'] ?? 'pending').toString(),
      paidAt: created is String ? DateTime.tryParse(created) : null,
      paymongoPaymentIntentId: r['paymongo_payment_intent_id']?.toString(),
      contractId: r['contract_id']?.toString(),
      methodType: r['method_type']?.toString(),
      brand: r['brand']?.toString(),
      last4: r['last4']?.toString(),
      failureReason: r['failure_reason']?.toString(),
      listingTitle: r['listing_title']?.toString(),
      recordedBy: r['recorded_by']?.toString(),
      note: r['note']?.toString(),
      billingMonth: billing is String ? DateTime.tryParse(billing) : null,
    );
  }
}

/// Landlord-generated PayMongo Link row from `payment_links`.
class PaymentLinkRow {
  final String id;
  final DateTime billingMonth;
  final int amountCents;
  final String checkoutUrl;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? note;

  const PaymentLinkRow({
    required this.id,
    required this.billingMonth,
    required this.amountCents,
    required this.checkoutUrl,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.note,
  });

  factory PaymentLinkRow.fromMap(Map<String, dynamic> r) {
    DateTime? parse(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;
    return PaymentLinkRow(
      id: r['id'].toString(),
      billingMonth: parse(r['billing_month']) ?? DateTime.now(),
      amountCents: (r['amount_cents'] as num?)?.toInt() ?? 0,
      checkoutUrl: (r['checkout_url'] ?? '').toString(),
      status: (r['status'] ?? 'pending').toString(),
      expiresAt: parse(r['expires_at']),
      createdAt: parse(r['created_at']),
      note: r['note']?.toString(),
    );
  }
}

/// Phase B view row: per-contract rent due rollup.
class ContractRentStatus {
  final String contractId;
  final DateTime? startDate;
  final num? monthlyRent;
  final DateTime? currentMonth;
  final DateTime? lastPaidMonth;
  final int monthsUnpaid;
  final DateTime? nextDueMonth;

  const ContractRentStatus({
    required this.contractId,
    required this.startDate,
    required this.monthlyRent,
    required this.currentMonth,
    required this.lastPaidMonth,
    required this.monthsUnpaid,
    required this.nextDueMonth,
  });

  factory ContractRentStatus.fromMap(Map<String, dynamic> r) {
    DateTime? parse(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;
    return ContractRentStatus(
      contractId: r['contract_id'].toString(),
      startDate: parse(r['start_date']),
      monthlyRent: r['monthly_rent'] as num?,
      currentMonth: parse(r['current_month']),
      lastPaidMonth: parse(r['last_paid_month']),
      monthsUnpaid: (r['months_unpaid'] as num?)?.toInt() ?? 0,
      nextDueMonth: parse(r['next_due_month']),
    );
  }
}

/// Per-month rent entry expanded from contract_rent_status + payment rows.
class RentMonth {
  final DateTime billingMonth;
  final int amountCents;
  final bool paid;
  final DateTime? paidAt;
  final String? paymongoPaymentIntentId;
  final String? method;

  const RentMonth({
    required this.billingMonth,
    required this.amountCents,
    required this.paid,
    required this.paidAt,
    required this.paymongoPaymentIntentId,
    required this.method,
  });
}

/// Read the contract_rent_status view for a single contract.
Future<ContractRentStatus?> fetchContractRentStatus(String contractId) async {
  if (contractId.isEmpty) return null;
  try {
    final row = await _sb
        .from('contract_rent_status')
        .select('*')
        .eq('contract_id', contractId)
        .maybeSingle();
    if (row == null) return null;
    return ContractRentStatus.fromMap(Map<String, dynamic>.from(row));
  } catch (_) {
    return null;
  }
}

/// Expand a contract_rent_status row into a per-month list from
/// start_date → current month, each tagged with paid/unpaid + the
/// relevant payment row. Mirrors the web `fetchRentMonths` walker.
Future<List<RentMonth>> fetchRentMonths(String contractId) async {
  if (contractId.isEmpty) return const [];
  final status = await fetchContractRentStatus(contractId);
  if (status?.startDate == null) return const [];

  List<dynamic> paid;
  try {
    paid = await _sb
        .from('payment')
        .select(
            'billing_month, amount_cents, paid_at, paymongo_payment_intent_id, method')
        .eq('contract_id', contractId)
        .eq('status', 'succeeded')
        .not('billing_month', 'is', null)
        .order('billing_month', ascending: true);
  } catch (_) {
    paid = const [];
  }

  final paidMap = <String, Map<String, dynamic>>{};
  for (final p in paid) {
    final bm = (p as Map)['billing_month']?.toString();
    if (bm == null) continue;
    paidMap[bm.substring(0, 10)] = Map<String, dynamic>.from(p);
  }

  final rentCents = (status!.monthlyRent ?? 0).toDouble().round() * 100;
  final months = <RentMonth>[];
  final start = DateTime(status.startDate!.year, status.startDate!.month, 1);
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, 1);
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    final key =
        '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-01';
    final hit = paidMap[key];
    months.add(RentMonth(
      billingMonth: cursor,
      amountCents:
          ((hit?['amount_cents'] as num?)?.toInt()) ?? rentCents,
      paid: hit != null,
      paidAt: hit?['paid_at'] is String
          ? DateTime.tryParse(hit!['paid_at'] as String)
          : null,
      paymongoPaymentIntentId:
          hit?['paymongo_payment_intent_id']?.toString(),
      method: hit?['method']?.toString(),
    ));
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  return months;
}

Future<List<PaymentTransactionRow>> fetchMyPaymentsWithContext({
  String? tenantId,
  String? status,
  String? methodType,
  DateTime? dateFrom,
  DateTime? dateTo,
}) async {
  final uid = tenantId ?? _sb.auth.currentUser?.id;
  if (uid == null) return const [];
  dynamic q = _sb
      .from('payment_transactions_with_context')
      .select('*')
      .eq('tenant_id', uid);
  if (status != null && status.isNotEmpty) q = q.eq('status', status);
  if (methodType != null && methodType.isNotEmpty) {
    q = q.eq('method_type', methodType);
  }
  if (dateFrom != null) q = q.gte('created_at', dateFrom.toIso8601String());
  if (dateTo != null) q = q.lte('created_at', dateTo.toIso8601String());
  final rows = await q.order('created_at', ascending: false);
  return (rows as List)
      .map((r) => PaymentTransactionRow.fromMap(Map<String, dynamic>.from(r)))
      .toList();
}

class NextDueContract {
  final String id;
  final String? listingId;
  final String? listingTitle;
  final String? landlordSignedAt;
  final String? listingType;
  final int monthlyRent;
  final int securityDeposit;
  final int advancePayment;
  const NextDueContract({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.landlordSignedAt,
    required this.listingType,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.advancePayment,
  });

  int get totalDueCents =>
      (monthlyRent + securityDeposit + advancePayment) * 100;
}

Future<NextDueContract?> fetchMyNextDueContract({String? tenantId}) async {
  final uid = tenantId ?? _sb.auth.currentUser?.id;
  if (uid == null) return null;
  final c = await _sb
      .from('contract')
      .select(
          'id, status, listing_id, application_id, landlord_signed_at, listing_type, listings(id, title)')
      .eq('tenant_id', uid)
      .eq('status', 'fully_signed')
      .order('landlord_signed_at', ascending: true)
      .limit(1)
      .maybeSingle();
  if (c == null) return null;
  final fin = await _sb
      .from('listing_financials')
      .select('monthly_rent, security_deposit, advance_payment')
      .eq('listing_id', c['listing_id'])
      .maybeSingle();
  final listing = (c['listings'] is Map) ? c['listings'] as Map : const {};
  return NextDueContract(
    id: c['id'].toString(),
    listingId: c['listing_id']?.toString(),
    listingTitle: listing['title']?.toString(),
    landlordSignedAt: c['landlord_signed_at']?.toString(),
    listingType: c['listing_type']?.toString(),
    monthlyRent: ((fin?['monthly_rent'] as num?) ?? 0).toInt(),
    securityDeposit: ((fin?['security_deposit'] as num?) ?? 0).toInt(),
    advancePayment: ((fin?['advance_payment'] as num?) ?? 0).toInt(),
  );
}

class InProgressContract {
  final String id;
  final String status;
  final String? listingId;
  final String? listingTitle;
  final String? coverPhotoUrl;
  final String? landlordSignedAt;
  final String? tenantSignedAt;
  final String? landlordName;
  final int monthlyRent;
  final int securityDeposit;
  final int advancePayment;
  const InProgressContract({
    required this.id,
    required this.status,
    required this.listingId,
    required this.listingTitle,
    required this.coverPhotoUrl,
    required this.landlordSignedAt,
    required this.tenantSignedAt,
    required this.landlordName,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.advancePayment,
  });
  int get totalDueCents =>
      (monthlyRent + securityDeposit + advancePayment) * 100;
}

Future<List<InProgressContract>> fetchMyInProgressContracts(
    {String? tenantId}) async {
  final uid = tenantId ?? _sb.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await _sb
      .from('contract')
      .select(
          'id, status, listing_id, application_id, tenant_signed_at, landlord_signed_at, listing_type, created_at, landlord_id, landlord_name, listings(id, title, cover_photo_url)')
      .eq('tenant_id', uid)
      .inFilter('status',
          ['awaiting_tenant', 'awaiting_landlord', 'fully_signed'])
      .order('created_at', ascending: false);
  if ((rows as List).isEmpty) return const [];

  final listingIds = rows
      .map((r) => r['listing_id'])
      .where((id) => id != null)
      .toSet()
      .toList();
  Map<String, Map<String, dynamic>> finMap = {};
  if (listingIds.isNotEmpty) {
    final fins = await _sb
        .from('listing_financials')
        .select('listing_id, monthly_rent, security_deposit, advance_payment')
        .inFilter('listing_id', listingIds);
    for (final f in (fins as List)) {
      finMap[f['listing_id'].toString()] = Map<String, dynamic>.from(f);
    }
  }

  return rows.map<InProgressContract>((c) {
    final listing = (c['listings'] is Map) ? c['listings'] as Map : const {};
    final f = finMap[c['listing_id']?.toString()];
    return InProgressContract(
      id: c['id'].toString(),
      status: c['status'].toString(),
      listingId: c['listing_id']?.toString(),
      listingTitle: listing['title']?.toString(),
      coverPhotoUrl: listing['cover_photo_url']?.toString(),
      landlordSignedAt: c['landlord_signed_at']?.toString(),
      tenantSignedAt: c['tenant_signed_at']?.toString(),
      landlordName: c['landlord_name']?.toString(),
      monthlyRent: ((f?['monthly_rent'] as num?) ?? 0).toInt(),
      securityDeposit: ((f?['security_deposit'] as num?) ?? 0).toInt(),
      advancePayment: ((f?['advance_payment'] as num?) ?? 0).toInt(),
    );
  }).toList();
}
