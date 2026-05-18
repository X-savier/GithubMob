import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/services/payments_service.dart';
import 'package:vxr_flutter/services/payment_methods_service.dart';

import '_helpers.dart';

void main() {
  setUpAll(() async => ensureInitialized());

  group('payments_service — mock + sandbox paths', () {
    test('mock payment flips contract → paid and writes ledger', () async {
      await signInAsTenantA();

      // Tenant needs a saved mock method first.
      final add = await addPaymentMethod(
        type: 'gcash',
        label: 'Flutter Mock GCash',
        accountHint: '0917-test',
        billingName: 'Test Tenant A',
        setDefault: true,
        isMock: true,
      );
      expect(add.ok, isTrue, reason: add.error);
      final methodId = (add.data?['method']?['id'] ?? add.data?['id'])?.toString();
      expect(methodId, isNotNull);

      try {
        final intent = await createPaymongoPaymentIntent(testContractId);
        expect(intent.ok, isTrue, reason: intent.error);
        expect(intent.data?['paymentIntentId'], startsWith('pi_'));

        final recorded = await recordMockPayment(
          contractId: testContractId,
          paymentMethodRecordId: methodId!,
        );
        expect(recorded.ok, isTrue, reason: recorded.error);

        final history = await fetchMyPaymentsWithContext();
        final match = history.firstWhere(
          (r) => r.contractId == testContractId && r.status == 'succeeded',
          orElse: () => throw StateError('No succeeded ledger row for test contract'),
        );
        expect(match.amountCents, greaterThan(0));
      } finally {
        if (methodId != null) await deletePaymentMethod(methodId);
      }
    });

    test('tenantB (not party) cannot create a payment intent', () async {
      await signInAsTenantB();
      final res = await createPaymongoPaymentIntent(testContractId);
      expect(res.ok, isFalse,
          reason: 'tenant-b is not party to the contract — Edge Function must refuse');
    });

    test('landlord can record an offline payment; tenant cannot', () async {
      await signInAsLandlord();
      final ok = await recordOfflinePayment(
        contractId: testContractId,
        amountPhp: 10000,
        methodType: 'cash',
        billingMonth: '2026-08-01',
        note: 'Flutter test cash payment',
      );
      expect(ok.ok, isTrue, reason: ok.error);

      await signInAsTenantA();
      final blocked = await recordOfflinePayment(
        contractId: testContractId,
        amountPhp: 10000,
        methodType: 'cash',
      );
      expect(blocked.ok, isFalse);
    });

    test('landlord-issued payment link is readable by tenant via RLS', () async {
      await signInAsLandlord();
      final link = await createLandlordPaymentLink(
        contractId: testContractId,
        billingMonth: '2026-09-01',
        note: 'September rent (Flutter test)',
      );
      expect(link.ok, isTrue, reason: link.error);
      expect(link.data?['checkout_url'].toString(), startsWith('http'));

      await signInAsTenantA();
      final list = await fetchPaymentLinks(testContractId);
      expect(
        list.any((l) => l.billingMonth.year == 2026 && l.billingMonth.month == 9),
        isTrue,
      );
    });
  });

  group('rent rollup', () {
    test('fetchContractRentStatus returns the seeded contract', () async {
      await signInAsTenantA();
      final status = await fetchContractRentStatus(testContractId);
      expect(status?.contractId, testContractId);
    });

    test('fetchRentMonths returns a contiguous monthly list', () async {
      await signInAsTenantA();
      final months = await fetchRentMonths(testContractId);
      expect(months, isNotEmpty);
      // Consecutive months — no gaps.
      for (var i = 1; i < months.length; i++) {
        final prev = months[i - 1].billingMonth;
        final cur = months[i].billingMonth;
        final expected = DateTime(prev.year, prev.month + 1, 1);
        expect(cur, expected, reason: 'month $i out of sequence');
      }
    });
  });
}
