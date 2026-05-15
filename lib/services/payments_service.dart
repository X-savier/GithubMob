import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _sb = Supabase.instance.client;

class PaymentsResult<T> {
  final T? data;
  final String? error;
  const PaymentsResult({this.data, this.error});
  bool get ok => error == null;
}

Future<PaymentsResult<Map<String, dynamic>>> createPaymongoPaymentIntent(
    String? contractId) async {
  if (contractId == null || contractId.isEmpty) {
    return const PaymentsResult(error: 'Missing contractId');
  }
  try {
    final res = await _sb.functions
        .invoke('paymongo-create-payment-intent', body: {
      'contract_id': contractId,
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
  });

  factory PaymentTransactionRow.fromMap(Map<String, dynamic> r) {
    final created = r['created_at'];
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
    );
  }
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
