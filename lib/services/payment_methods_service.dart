import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _sb = Supabase.instance.client;

class SavedPaymentMethod {
  final String id;
  final String type;
  final String? label;
  final String? accountHint;
  final String? billingName;
  final bool isDefault;
  final bool isMock;
  final DateTime? createdAt;

  const SavedPaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    required this.accountHint,
    required this.billingName,
    required this.isDefault,
    required this.isMock,
    required this.createdAt,
  });

  factory SavedPaymentMethod.fromMap(Map<String, dynamic> r) =>
      SavedPaymentMethod(
        id: r['id'].toString(),
        type: r['type'].toString(),
        label: r['label']?.toString(),
        accountHint: r['account_hint']?.toString(),
        billingName: r['billing_name']?.toString(),
        isDefault: r['is_default'] == true,
        isMock: r['is_mock'] == true,
        createdAt: r['created_at'] is String
            ? DateTime.tryParse(r['created_at'] as String)
            : null,
      );
}

class MethodResult<T> {
  final T? data;
  final String? error;
  const MethodResult({this.data, this.error});
  bool get ok => error == null;
}

Future<List<SavedPaymentMethod>> listMyPaymentMethods() async {
  final rows = await _sb
      .from('payment_methods')
      .select(
          'id, type, label, account_hint, billing_name, is_default, is_mock, created_at')
      .order('is_default', ascending: false)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((r) => SavedPaymentMethod.fromMap(Map<String, dynamic>.from(r)))
      .toList();
}

Future<MethodResult<Map<String, dynamic>>> addPaymentMethod({
  required String type,
  String? label,
  String? accountHint,
  String? billingName,
  bool setDefault = false,
  bool isMock = false,
}) =>
    _invoke('paymongo-add-method', {
      'type': type,
      'label': label,
      'account_hint': accountHint,
      'billing_name': billingName,
      'set_default': setDefault,
      'is_mock': isMock,
    });

Future<MethodResult<Map<String, dynamic>>> deletePaymentMethod(
        String methodId) =>
    _invoke('paymongo-delete-method', {'method_id': methodId});

Future<MethodResult<Map<String, dynamic>>> setDefaultPaymentMethod(
        String methodId) =>
    _invoke('paymongo-set-default-method', {'method_id': methodId});

Future<MethodResult<Map<String, dynamic>>> _invoke(
    String name, Map<String, dynamic> body) async {
  try {
    final res = await _sb.functions.invoke(name, body: body);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      return MethodResult(error: data['error'].toString());
    }
    return MethodResult(
        data: data is Map ? Map<String, dynamic>.from(data) : null);
  } catch (e) {
    return MethodResult(error: e.toString());
  }
}
