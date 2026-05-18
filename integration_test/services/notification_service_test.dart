import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/services/notification_service.dart';

import '_helpers.dart';

void main() {
  setUpAll(() async => ensureInitialized());

  test('fetchNotifications returns a list (possibly empty) for tenantA', () async {
    await signInAsTenantA();
    final list = await fetchNotifications(limit: 10);
    expect(list, isA<List<AppNotification>>());
  });

  test('fetchUnreadCount returns a non-negative integer', () async {
    await signInAsTenantA();
    final count = await fetchUnreadCount();
    expect(count, greaterThanOrEqualTo(0));
  });

  test('markAllAsRead drives unread count to zero', () async {
    await signInAsTenantA();
    await markAllAsRead();
    final count = await fetchUnreadCount();
    expect(count, 0);
  });
}
