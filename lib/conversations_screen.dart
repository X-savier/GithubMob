import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'chat_thread_screen.dart';
import 'property_data.dart';
import 'search_field.dart';
import 'profile_screen.dart';

/// Inbox of all the current user's conversations. Shared between
/// landlord and tenant — the row shows the *other* party.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _conversations = [];
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final rows = await fetchMyConversations();
    if (!mounted) return;
    setState(() {
      _conversations = rows;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _conversations;
    final q = _query.toLowerCase();
    return _conversations.where((c) {
      final p = (c['other_profile'] as Map?) ?? {};
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final preview = (c['last_message'] ?? '').toString().toLowerCase();
      final listing = (c['listing_title'] ?? '').toString().toLowerCase();
      return name.contains(q) || preview.contains(q) || listing.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: VxrAppBar(
        title: 'Messages',
        subtitle: 'Your conversations',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
        bottom: VxrSearchBar(
          controller: _searchController,
          hint: 'Search name, message, listing…',
          onGradient: true,
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : RefreshIndicator(
              color: VxrTokens.accent,
              onRefresh: _refresh,
              child: _filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [_emptyState()],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) =>
                          _conversationRow(_filtered[i]),
                    ),
            ),
      bottomNavigationBar: VxrBottomNav(
        activeIndex: 2,
        onTap: (index) {
          if (index == 2) return;
          if (index == 0) {
            Navigator.popUntil(context, (r) => r.isFirst);
          } else if (index == 1) {
            Navigator.popUntil(context, (r) => r.isFirst);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchFieldScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _emptyState() {
    final t = VxrTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 56, color: t.textMuted),
          const SizedBox(height: 12),
          Text(
            'No conversations yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _query.isEmpty
                ? 'Start a chat from a listing or your tenant management screen.'
                : 'No conversations match your search.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: t.textSub),
          ),
        ],
      ),
    );
  }

  Widget _conversationRow(Map<String, dynamic> c) {
    final t = VxrTheme.of(context);
    final other = (c['other_profile'] as Map?) ?? {};
    final name = (other['full_name']?.toString().trim().isNotEmpty ?? false)
        ? other['full_name'].toString()
        : 'User';
    final avatar = (other['avatar_url'] ?? '').toString();
    final preview = (c['last_message'] ?? '').toString();
    final listingTitle = (c['listing_title'] ?? '').toString();
    final unread = (c['unread_count'] ?? 0) as int;
    final ts = c['last_message_at']?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatThreadScreen(
                conversationId: c['id'].toString(),
                otherName: name,
                otherAvatarUrl: avatar,
                listingTitle: listingTitle.isEmpty ? null : listingTitle,
              ),
            ),
          );
          _refresh();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              _avatar(name: name, url: avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                        ),
                        if (ts != null)
                          Text(
                            _formatTimestamp(ts),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: unread > 0 ? t.accent : t.textMuted,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    if (listingTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 11,
                            color: t.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listingTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: t.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.isEmpty ? 'Say hello…' : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: unread > 0 ? t.text : t.textSub,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontStyle: preview.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(
                                VxrTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar({required String name, required String url}) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        gradient: VxrTokens.brandGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  String _formatTimestamp(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }
}
