import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/notification_controller.dart';
import '../theme/vxr_theme.dart';
import '../utils/time_ago.dart';

import '../conversations_screen.dart';
import '../enlistment_application.dart';
import '../landlord_contracts_screen.dart';
import '../my_applications_screen.dart';
import '../payment_screen.dart';
import '../report_management_screen.dart';
import '../verification_screen.dart';
import '../manage_listing.dart';

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VxrTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VxrTokens.radiusSheet),
        ),
      ),
      builder: (_) => const NotificationPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<NotificationController>();
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _Handle(),
            _PanelHeader(
              unread: ctrl.unreadCount,
              onMarkAll: ctrl.unreadCount > 0 ? ctrl.markAllAsRead : null,
            ),
            const Divider(height: 1, color: VxrTokens.border),
            Expanded(
              child: ctrl.loading && ctrl.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ctrl.items.isEmpty
                      ? _EmptyState()
                      : RefreshIndicator(
                          onRefresh: ctrl.refresh,
                          color: VxrTokens.accent,
                          child: ListView.separated(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            itemCount: ctrl.items.length,
                            separatorBuilder: (_, _) => const Divider(
                                height: 1, color: VxrTokens.border),
                            itemBuilder: (context, i) {
                              final n = ctrl.items[i];
                              return _NotificationRow(
                                n: n,
                                onTap: () => _handleTap(context, ctrl, n),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    NotificationController ctrl,
    AppNotification n,
  ) async {
    if (!n.isRead) {
      ctrl.markAsRead(n.id);
    }
    Navigator.of(context).pop();
    final route = _routeFor(n);
    if (route != null) {
      Navigator.of(context).push(route);
    }
  }

  Route<dynamic>? _routeFor(AppNotification n) {
    // Notifications open the relevant inbox/list; deep-linking to a specific
    // detail requires fetching context (conversation participants, landlord
    // id, etc.) which is out of scope here.
    switch (n.referenceType ?? n.type) {
      case 'message':
        return MaterialPageRoute(
          builder: (_) => const ConversationsScreen(),
        );
      case 'application':
        return MaterialPageRoute(
          builder: (_) => const MyApplicationsScreen(),
        );
      case 'contract':
        return MaterialPageRoute(
          builder: (_) => const LandlordContractsScreen(),
        );
      case 'payment':
        return MaterialPageRoute(
          builder: (_) => const PaymentScreen(),
        );
      case 'report':
        return MaterialPageRoute(
          builder: (_) => const ReportManagementScreen(),
        );
      case 'verification':
        return MaterialPageRoute(
          builder: (_) => const VerificationScreen(),
        );
      case 'listing':
        return MaterialPageRoute(
          builder: (_) => const ManageListingScreen(),
        );
    }
    return null;
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: VxrTokens.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final int unread;
  final VoidCallback? onMarkAll;
  const _PanelHeader({required this.unread, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: VxrTokens.text,
            ),
          ),
          const SizedBox(width: 10),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: VxrTokens.accentSoft,
                borderRadius:
                    BorderRadius.circular(VxrTokens.radiusPill),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VxrTokens.accent,
                ),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: onMarkAll,
            style: TextButton.styleFrom(
              foregroundColor: VxrTokens.accent,
              disabledForegroundColor: VxrTokens.textMuted,
            ),
            child: Text(
              'Mark all as read',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: VxrTokens.surface2,
              borderRadius: BorderRadius.circular(VxrTokens.radius),
            ),
            child: const Icon(Icons.notifications_off_outlined,
                size: 32, color: VxrTokens.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            "You're all caught up",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: VxrTokens.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New notifications will appear here',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: VxrTokens.textSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap;
  const _NotificationRow({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !n.isRead;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: unread ? VxrTokens.accentSoft.withValues(alpha: 0.55) : null,
          border: Border(
            left: BorderSide(
              color: unread ? VxrTokens.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: n.referenceType ?? n.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w600,
                            color: VxrTokens.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(n.createdAt),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: VxrTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if ((n.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: VxrTokens.textSub,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final String type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(type);
    final color = _colorFor(type);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(iconData, color: color, size: 18),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'application':
        return Icons.assignment_outlined;
      case 'contract':
        return Icons.description_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'report':
        return Icons.build_outlined;
      case 'verification':
        return Icons.verified_user_outlined;
      case 'listing':
        return Icons.home_work_outlined;
    }
    return Icons.notifications_none;
  }

  Color _colorFor(String t) {
    switch (t) {
      case 'message':
        return const Color(0xFF3B82F6);
      case 'application':
        return VxrTokens.accent;
      case 'contract':
        return const Color(0xFF8B5CF6);
      case 'payment':
        return VxrTokens.success;
      case 'report':
        return VxrTokens.warning;
      case 'verification':
        return const Color(0xFF06B6D4);
      case 'listing':
        return VxrTokens.accent;
    }
    return VxrTokens.textSub;
  }
}
