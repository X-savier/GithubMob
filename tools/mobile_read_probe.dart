/// Pure-Dart probe used by the cross-platform contract runner to perform
/// a read from a "mobile-shaped" perspective without needing the Flutter
/// engine. Mirrors lib/services/*.dart query shapes, using the pure-dart
/// `supabase` package (no supabase_flutter).
///
/// Invoked as:  dart run tools/mobile_read_probe.dart <command> <jsonArgs>
///
/// Reads SUPABASE_URL / SUPABASE_ANON_KEY from the environment. Signs in
/// as tenantA (the only role the contract runner currently asks of it);
/// extend the auth section if new commands need a different role.
///
/// Stdout: a single JSON value on success. Stderr: human-readable error,
/// nonzero exit on failure. Designed so the Vitest runner can JSON.parse
/// stdout directly.

import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main(List<String> argv) async {
  if (argv.length < 1) {
    stderr.writeln('usage: mobile_read_probe <command> [jsonArgs]');
    exit(2);
  }
  final command = argv[0];
  final args = argv.length >= 2
      ? (jsonDecode(argv[1]) as Map<String, dynamic>)
      : <String, dynamic>{};

  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_ANON_KEY'];
  if (url == null || key == null) {
    stderr.writeln('SUPABASE_URL / SUPABASE_ANON_KEY required');
    exit(2);
  }

  final sb = SupabaseClient(url, key);
  await sb.auth.signInWithPassword(
    email: Platform.environment['TEST_TENANT_A_EMAIL']!,
    password: Platform.environment['TEST_TENANT_A_PASSWORD']!,
  );

  try {
    final result = await _dispatch(sb, command, args);
    stdout.write(jsonEncode(result));
  } catch (e, st) {
    stderr.writeln('probe failed: $e\n$st');
    exit(1);
  }
}

/// Add new commands here as the contract runner grows. Each command's
/// shape mirrors the corresponding lib/services/*.dart return shape, so
/// the runner can compare mobile output to web output field-by-field.
Future<dynamic> _dispatch(SupabaseClient sb, String cmd, Map<String, dynamic> args) async {
  switch (cmd) {
    case 'fetchMyPaymentsWithContext':
      final tenantId = args['tenantId'] as String? ?? sb.auth.currentUser?.id;
      final rows = await sb
          .from('payment_transactions_with_context')
          .select('*')
          .eq('tenant_id', tenantId!)
          .order('created_at', ascending: false);
      return (rows as List).map((r) => {
        'id': r['id'].toString(),
        'amountCents': r['amount_cents'],
        'currency': r['currency'],
        'status': r['status'],
        'paymongoPaymentIntentId': r['paymongo_payment_intent_id'],
        'contractId': r['contract_id'],
        'methodType': r['method_type'],
      }).toList();

    case 'fetchPaymentLinks':
      final rows = await sb
          .from('payment_links')
          .select('id, billing_month, amount_cents, checkout_url, status')
          .eq('contract_id', args['contractId'])
          .order('created_at', ascending: false);
      return rows;

    case 'fetchContractById':
      return await sb.from('contract').select('*').eq('id', args['contractId']).maybeSingle();

    default:
      throw 'unknown command: $cmd';
  }
}
