import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vxr_flutter/auth/auth_service.dart';

import '_helpers.dart';

void main() {
  late AuthService auth;

  setUpAll(() async {
    await ensureInitialized();
    auth = AuthService();
  });

  test('signIn returns a session for the seeded tenantA', () async {
    final res = await auth.signInWithEmailPassword(testTenantAEmail, testTenantAPassword);
    expect(res.session, isNotNull);
    expect(res.user?.email?.toLowerCase(), testTenantAEmail.toLowerCase());
  });

  test('ensureProfile is idempotent — runs without error for an existing profile', () async {
    await auth.signInWithEmailPassword(testTenantAEmail, testTenantAPassword);
    await auth.ensureProfile();
    final profile = await auth.fetchProfile();
    expect(profile, isNotNull);
    expect(profile!['id'], auth.currentUser?.id);
  });

  test('updateProfile round-trips a phone change', () async {
    await auth.signInWithEmailPassword(testTenantAEmail, testTenantAPassword);
    final newPhone = '+639170000${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';
    await auth.updateProfile({'phone': newPhone});
    final profile = await auth.fetchProfile();
    expect(profile?['phone'], newPhone);
  });

  test('signOut clears the session', () async {
    await auth.signInWithEmailPassword(testTenantAEmail, testTenantAPassword);
    await auth.signOut();
    expect(Supabase.instance.client.auth.currentSession, isNull);
  });
}
