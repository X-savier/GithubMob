import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _sb = Supabase.instance.client;

class UserRoleSnapshot {
  final String? role;
  final bool hasListings;
  final bool hasActiveContract;
  final bool isAdmin;
  const UserRoleSnapshot({
    required this.role,
    required this.hasListings,
    required this.hasActiveContract,
    required this.isAdmin,
  });

  bool get isLandlord => hasListings;
  bool get isTenant => hasActiveContract && !hasListings;
  bool get isDual => hasListings && hasActiveContract;
}

Future<String?> getProfileRole({String? userId}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) return null;
  final row = await _sb
      .from('profiles')
      .select('role')
      .eq('id', uid)
      .maybeSingle();
  return row?['role']?.toString();
}

Future<bool> hasUserListings({String? userId}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) return false;
  final row = await _sb
      .from('listings')
      .select('id')
      .eq('landlord_id', uid)
      .limit(1)
      .maybeSingle();
  return row != null;
}

Future<bool> hasActiveContract({String? userId}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) return false;
  final row = await _sb
      .from('contract')
      .select('id')
      .eq('tenant_id', uid)
      .inFilter('status',
          ['awaiting_tenant', 'awaiting_landlord', 'fully_signed', 'paid', 'active'])
      .limit(1)
      .maybeSingle();
  return row != null;
}

Future<UserRoleSnapshot> loadRoleSnapshot({String? userId}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) {
    return const UserRoleSnapshot(
        role: null, hasListings: false, hasActiveContract: false, isAdmin: false);
  }
  final results = await Future.wait([
    getProfileRole(userId: uid),
    hasUserListings(userId: uid),
    hasActiveContract(userId: uid),
  ]);
  final role = results[0] as String?;
  final listings = results[1] as bool;
  final contract = results[2] as bool;
  return UserRoleSnapshot(
    role: role,
    hasListings: listings,
    hasActiveContract: contract,
    isAdmin: role == 'admin',
  );
}
