import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class NotificationController extends ChangeNotifier {
  List<AppNotification> _items = const [];
  int _unread = 0;
  bool _loading = false;
  String? _userId;
  RealtimeChannel? _channel;

  List<AppNotification> get items => _items;
  int get unreadCount => _unread;
  bool get loading => _loading;

  Future<void> bind(String? userId) async {
    if (userId == _userId) return;
    await _detach();
    _userId = userId;
    if (userId == null) {
      _items = const [];
      _unread = 0;
      notifyListeners();
      return;
    }
    await _initialLoad();
    _channel = subscribeToNotifications(userId, _onInsert);
  }

  Future<void> _initialLoad() async {
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        fetchNotifications(userId: _userId, limit: 50),
        fetchUnreadCount(userId: _userId),
      ]);
      _items = results[0] as List<AppNotification>;
      _unread = results[1] as int;
    } catch (_) {/* ignore — show empty state */} finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => _initialLoad();

  void _onInsert(AppNotification n) {
    _items = [n, ..._items];
    if (!n.isRead) _unread += 1;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final prev = _items[idx];
    if (prev.isRead) return;
    _items = List.of(_items)..[idx] = prev.copyWith(isRead: true);
    _unread = (_unread - 1).clamp(0, 1 << 30);
    notifyListeners();
    try {
      await markAsReadRemote(id);
    } catch (_) {
      _items = List.of(_items)..[idx] = prev;
      _unread += 1;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_unread == 0) return;
    final prev = _items;
    _items = _items
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList(growable: false);
    final prevUnread = _unread;
    _unread = 0;
    notifyListeners();
    try {
      await markAllAsReadRemote(userId: _userId);
    } catch (_) {
      _items = prev;
      _unread = prevUnread;
      notifyListeners();
    }
  }

  Future<void> _detach() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.unsubscribe();
      } catch (_) {/* ignore */}
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}

// Aliased remote calls so the controller can stub them in tests if needed.
Future<void> markAsReadRemote(String id) => markAsRead(id);
Future<void> markAllAsReadRemote({String? userId}) =>
    markAllAsRead(userId: userId);
