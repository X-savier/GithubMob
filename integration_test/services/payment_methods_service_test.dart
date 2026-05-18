import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/services/payment_methods_service.dart';

import '_helpers.dart';

void main() {
  setUpAll(() async => ensureInitialized());

  final List<String> createdIds = [];

  tearDownAll(() async {
    await signInAsTenantA();
    for (final id in createdIds) {
      await deletePaymentMethod(id);
    }
  });

  test('addPaymentMethod returns a new id; listMyPaymentMethods sees it', () async {
    await signInAsTenantA();
    final add = await addPaymentMethod(
      type: 'gcash',
      label: 'Flutter test GCash',
      accountHint: '0917-flutter',
      billingName: 'Test Tenant A',
      setDefault: true,
      isMock: true,
    );
    expect(add.ok, isTrue, reason: add.error);
    final id = (add.data?['method']?['id'] ?? add.data?['id']).toString();
    createdIds.add(id);

    final list = await listMyPaymentMethods();
    expect(list.any((m) => m.id == id), isTrue);
  });

  test('setDefaultPaymentMethod enforces exactly one default per user', () async {
    await signInAsTenantA();
    final add = await addPaymentMethod(
      type: 'paymaya',
      label: 'Flutter test Maya',
      accountHint: '0918-flutter',
      setDefault: false,
      isMock: true,
    );
    expect(add.ok, isTrue, reason: add.error);
    final id = (add.data?['method']?['id'] ?? add.data?['id']).toString();
    createdIds.add(id);

    final res = await setDefaultPaymentMethod(id);
    expect(res.ok, isTrue, reason: res.error);

    final list = await listMyPaymentMethods();
    final defaults = list.where((m) => m.isDefault).toList();
    expect(defaults.length, 1);
    expect(defaults.single.id, id);
  });

  test('RLS hides tenantA methods from tenantB', () async {
    await signInAsTenantB();
    final list = await listMyPaymentMethods();
    expect(list.where((m) => createdIds.contains(m.id)), isEmpty);
  });
}
