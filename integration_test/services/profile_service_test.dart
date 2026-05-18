import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/services/profile_service.dart';

import '_helpers.dart';

void main() {
  setUpAll(() async => ensureInitialized());

  test('loadRoleSnapshot for landlord — hasListings true, contract may be either', () async {
    await signInAsLandlord();
    final snap = await loadRoleSnapshot();
    expect(snap.hasListings, isTrue);
    expect(snap.isLandlord, isTrue);
  });

  test('loadRoleSnapshot for tenantA — hasActiveContract true, hasListings false', () async {
    await signInAsTenantA();
    final snap = await loadRoleSnapshot();
    expect(snap.hasListings, isFalse);
    expect(snap.hasActiveContract, isTrue);
    expect(snap.isTenant, isTrue);
  });

  test('loadRoleSnapshot for tenantB — neither listing nor contract', () async {
    await signInAsTenantB();
    final snap = await loadRoleSnapshot();
    expect(snap.hasListings, isFalse);
    expect(snap.hasActiveContract, isFalse);
    expect(snap.isLandlord, isFalse);
    expect(snap.isTenant, isFalse);
  });

  test('getProfileRole resolves the seeded role string', () async {
    await signInAsLandlord();
    final role = await getProfileRole();
    expect(role, 'landlord');
  });
}
