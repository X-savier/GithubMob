import 'dart:convert';
import 'package:http/http.dart' as http;

const String _kPaymongoPublicKey =
    String.fromEnvironment('PAYMONGO_PUBLIC_KEY', defaultValue: '');
const String _kPaymongoApi = 'https://api.paymongo.com/v1';

bool isPaymongoConfigured() => _kPaymongoPublicKey.isNotEmpty;

String _publicAuthHeader() {
  if (_kPaymongoPublicKey.isEmpty) {
    throw StateError(
        'PAYMONGO_PUBLIC_KEY is not set. Pass via --dart-define=PAYMONGO_PUBLIC_KEY=pk_test_...');
  }
  return 'Basic ${base64Encode(utf8.encode('$_kPaymongoPublicKey:'))}';
}

String _firstError(Map<String, dynamic> body) {
  final errors = body['errors'];
  if (errors is List && errors.isNotEmpty) {
    final first = errors.first;
    if (first is Map) {
      return (first['detail'] ?? first['code'] ?? 'PayMongo request failed')
          .toString();
    }
  }
  return 'PayMongo request failed';
}

class PaymongoCard {
  final String number;
  final int expMonth;
  final int expYear;
  final String cvc;
  const PaymongoCard({
    required this.number,
    required this.expMonth,
    required this.expYear,
    required this.cvc,
  });
}

class PaymongoBilling {
  final String? name;
  final String? email;
  final String? phone;
  const PaymongoBilling({this.name, this.email, this.phone});

  Map<String, dynamic> toJson() => {
        if (name != null && name!.isNotEmpty) 'name': name,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
      };
}

Future<Map<String, dynamic>> createCardPaymentMethod({
  required PaymongoCard card,
  required PaymongoBilling billing,
}) async {
  final res = await http.post(
    Uri.parse('$_kPaymongoApi/payment_methods'),
    headers: {
      'Authorization': _publicAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'data': {
        'attributes': {
          'type': 'card',
          'details': {
            'card_number': card.number.replaceAll(RegExp(r'\s+'), ''),
            'exp_month': card.expMonth,
            'exp_year': card.expYear,
            'cvc': card.cvc,
          },
          'billing': billing.toJson(),
        },
      },
    }),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception(_firstError(body));
  }
  return body['data'] as Map<String, dynamic>;
}

Future<Map<String, dynamic>> createEwalletPaymentMethod({
  required String type,
  required PaymongoBilling billing,
}) async {
  final res = await http.post(
    Uri.parse('$_kPaymongoApi/payment_methods'),
    headers: {
      'Authorization': _publicAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'data': {
        'attributes': {
          'type': type,
          'billing': billing.toJson(),
        },
      },
    }),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception(_firstError(body));
  }
  return body['data'] as Map<String, dynamic>;
}

class PaymongoMethodMeta {
  final String label;
  final String short;
  const PaymongoMethodMeta(this.label, this.short);
}

const Map<String, PaymongoMethodMeta> kPaymongoMethodLabels = {
  'card': PaymongoMethodMeta('Card', 'Card'),
  'gcash': PaymongoMethodMeta('GCash', 'GCash'),
  'paymaya': PaymongoMethodMeta('Maya', 'Maya'),
  'grab_pay': PaymongoMethodMeta('GrabPay', 'GrabPay'),
  'bank_transfer': PaymongoMethodMeta('Bank Transfer', 'Bank'),
};
