import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _sb = Supabase.instance.client;
const String _kTable = 'notification';

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.referenceId,
    required this.referenceType,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        referenceId: referenceId,
        referenceType: referenceType,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory AppNotification.fromMap(Map<String, dynamic> r) => AppNotification(
        id: r['id'].toString(),
        userId: r['user_id'].toString(),
        type: r['type'].toString(),
        title: (r['title'] ?? '').toString(),
        body: r['body']?.toString(),
        referenceId: r['reference_id']?.toString(),
        referenceType: r['reference_type']?.toString(),
        isRead: r['is_read'] == true,
        createdAt: r['created_at'] is String
            ? DateTime.tryParse(r['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

Future<List<AppNotification>> fetchNotifications({
  String? userId,
  int limit = 30,
}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await _sb
      .from(_kTable)
      .select('*')
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(limit);
  return (rows as List)
      .map((r) => AppNotification.fromMap(Map<String, dynamic>.from(r)))
      .toList();
}

Future<int> fetchUnreadCount({String? userId}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) return 0;
  final res = await _sb
      .from(_kTable)
      .select('id')
      .eq('user_id', uid)
      .eq('is_read', false)
      .count(CountOption.exact);
  return res.count;
}

Future<void> markAsRead(String notificationId) async {
  await _sb
      .from(_kTable)
      .update({'is_read': true}).eq('id', notificationId);
}

Future<void> markAllAsRead({String? userId}) async {
  final uid = userId ?? _sb.auth.currentUser?.id;
  if (uid == null) return;
  await _sb
      .from(_kTable)
      .update({'is_read': true})
      .eq('user_id', uid)
      .eq('is_read', false);
}

RealtimeChannel subscribeToNotifications(
  String userId,
  void Function(AppNotification) onInsert,
) {
  final channel = _sb.channel('notification:$userId');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: _kTable,
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    ),
    callback: (payload) {
      try {
        onInsert(AppNotification.fromMap(
            Map<String, dynamic>.from(payload.newRecord)));
      } catch (_) {/* ignore malformed payloads */}
    },
  );
  channel.subscribe();
  return channel;
}
