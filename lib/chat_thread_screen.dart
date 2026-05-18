import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/vxr_theme.dart';
import 'property_data.dart';

/// 1:1 chat thread between the current user and the other party.
/// Realtime via Supabase `.stream()` on the message table.
///
/// Branding: ViewxRent coral palette.
class ChatThreadScreen extends StatefulWidget {
  final String conversationId;
  final String otherName;
  final String otherAvatarUrl;
  final String? listingTitle;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    required this.otherAvatarUrl,
    this.listingTitle,
  });

  static const Color brand = VxrTokens.accent;
  static const Color coral = VxrTokens.gradMid;
  static const Color light = VxrTokens.gradEnd;
  static const Color ink = VxrTokens.text;
  static const Color muted = VxrTokens.textSub;
  static const Color bg = VxrTokens.bg;
  static const Color border = VxrTokens.border;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  String? _meId;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _meId = Supabase.instance.client.auth.currentUser?.id;
    // Fire-and-forget: mark anything older as read on entry.
    markConversationRead(widget.conversationId);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _sending = true);
    final ok = await sendAttachmentMessage(
      conversationId: widget.conversationId,
      bytes: bytes,
      fileName: picked.name,
      messageType: 'image',
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send image. Try again.')),
      );
    }
    setState(() => _sending = false);
  }

  Future<void> _pickAndSendFile() async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read file.')),
      );
      return;
    }
    setState(() => _sending = true);
    final ok = await sendAttachmentMessage(
      conversationId: widget.conversationId,
      bytes: bytes,
      fileName: f.name,
      messageType: 'file',
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send file. Try again.')),
      );
    }
    setState(() => _sending = false);
  }

  void _showAttachmentSheet() {
    if (_sending) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined,
                  color: ChatThreadScreen.brand),
              title: const Text('Send a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file,
                  color: ChatThreadScreen.brand),
              title: const Text('Send a file'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the attachment.')),
      );
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await sendMessage(
      conversationId: widget.conversationId,
      body: text,
    );
    if (!mounted) return;
    if (ok) {
      _inputCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send. Try again.')),
      );
    }
    setState(() => _sending = false);
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatThreadScreen.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: streamMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: ChatThreadScreen.brand),
                    );
                  }
                  final msgs = snapshot.data ?? const [];
                  if (msgs.length != _lastMessageCount) {
                    _lastMessageCount = msgs.length;
                    _scrollToBottom();
                    // New messages may have arrived from the other side —
                    // mark them as read.
                    markConversationRead(widget.conversationId);
                  }
                  if (msgs.isEmpty) return _emptyThread();
                  return _messagesList(msgs);
                },
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────
  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      decoration: const BoxDecoration(gradient: VxrTokens.brandGradient),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          _avatar(name: widget.otherName, url: widget.otherAvatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName.isEmpty ? 'Conversation' : widget.otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.listingTitle != null &&
                    widget.listingTitle!.isNotEmpty)
                  Text(
                    widget.listingTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar({required String name, required String url}) {
    final initial =
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final fallback = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16)),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  // ── Messages list ───────────────────────────────────────────────
  Widget _messagesList(List<Map<String, dynamic>> msgs) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final m = msgs[i];
        final mine = m['sender_id']?.toString() == _meId;
        final type = (m['type'] ?? 'text').toString();
        final ts = m['created_at']?.toString();
        final prev = i == 0 ? null : msgs[i - 1];
        final showHeader =
            prev == null || _shouldShowDayHeader(prev, m);
        final groupedTop = !showHeader &&
            prev['sender_id']?.toString() ==
                m['sender_id']?.toString() &&
            _withinMinute(prev, m);
        final showTimestamp =
            i == msgs.length - 1 || _shouldShowTime(m, msgs[i + 1]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) _dayHeader(ts),
            Padding(
              padding: EdgeInsets.only(top: groupedTop ? 2 : 6),
              child: _bubbleFor(
                m: m,
                mine: mine,
                type: type,
                ts: ts,
                showTimestamp: showTimestamp,
              ),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDayHeader(
      Map<String, dynamic> prev, Map<String, dynamic> cur) {
    final p = DateTime.tryParse(prev['created_at']?.toString() ?? '');
    final c = DateTime.tryParse(cur['created_at']?.toString() ?? '');
    if (p == null || c == null) return false;
    return p.toLocal().day != c.toLocal().day ||
        p.toLocal().month != c.toLocal().month ||
        p.toLocal().year != c.toLocal().year;
  }

  bool _withinMinute(
      Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final tb = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (ta == null || tb == null) return false;
    return tb.difference(ta).inMinutes.abs() < 2;
  }

  bool _shouldShowTime(
      Map<String, dynamic> cur, Map<String, dynamic> next) {
    if (cur['sender_id'] != next['sender_id']) return true;
    return !_withinMinute(cur, next);
  }

  Widget _dayHeader(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    final label = t == null ? '' : _formatDay(t);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: ChatThreadScreen.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ChatThreadScreen.muted)),
          ),
          const Expanded(
              child: Divider(color: ChatThreadScreen.border, height: 1)),
        ],
      ),
    );
  }

  Widget _bubbleFor({
    required Map<String, dynamic> m,
    required bool mine,
    required String type,
    required String? ts,
    required bool showTimestamp,
  }) {
    final time = ts == null ? '' : _formatTime(ts);
    final url = (m['url'] ?? '').toString();
    final fileName = (m['file_name'] ?? '').toString();
    final body = (m['content'] ?? '').toString();

    Widget content;
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    switch (type) {
      case 'image':
        padding = const EdgeInsets.all(4);
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: url.isEmpty ? null : () => _openUrl(url),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 240,
                maxHeight: 320,
              ),
              child: url.isEmpty
                  ? _attachmentPlaceholder(mine)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _attachmentPlaceholder(mine),
                      loadingBuilder: (ctx, child, prog) {
                        if (prog == null) return child;
                        return Container(
                          width: 200,
                          height: 200,
                          alignment: Alignment.center,
                          color: ChatThreadScreen.bg,
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ChatThreadScreen.brand,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
        break;
      case 'file':
        content = InkWell(
          onTap: url.isEmpty ? null : () => _openUrl(url),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 22,
                  color: mine ? Colors.white : ChatThreadScreen.brand),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName.isEmpty ? 'Attachment' : fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mine
                            ? Colors.white
                            : ChatThreadScreen.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to open',
                      style: TextStyle(
                        color: mine
                            ? Colors.white.withValues(alpha: 0.85)
                            : ChatThreadScreen.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        break;
      default:
        content = Text(
          body,
          style: TextStyle(
            color: mine ? Colors.white : ChatThreadScreen.ink,
            fontSize: 14,
            height: 1.35,
          ),
        );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: mine ? VxrTokens.brandGradient : null,
                color: mine ? null : VxrTokens.surface2,
                border: mine
                    ? null
                    : Border.all(color: ChatThreadScreen.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                boxShadow: mine
                    ? [
                        BoxShadow(
                          color: ChatThreadScreen.brand
                              .withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: content,
            ),
            if (showTimestamp && time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(time,
                    style: const TextStyle(
                        fontSize: 10,
                        color: ChatThreadScreen.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _attachmentPlaceholder(bool mine) {
    return Container(
      width: 200,
      height: 200,
      alignment: Alignment.center,
      color: ChatThreadScreen.bg,
      child: Icon(
        Icons.broken_image_outlined,
        size: 40,
        color: mine
            ? Colors.white.withValues(alpha: 0.8)
            : ChatThreadScreen.muted,
      ),
    );
  }

  // ── Empty thread ────────────────────────────────────────────────
  Widget _emptyThread() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_outlined,
                size: 56,
                color:
                    ChatThreadScreen.brand.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Say hi to ${widget.otherName.isEmpty ? 'them' : widget.otherName.split(' ').first}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ChatThreadScreen.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Messages are private between the two of you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: ChatThreadScreen.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Composer ────────────────────────────────────────────────────
  Widget _composer() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: ChatThreadScreen.border, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _attachButton(),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: ChatThreadScreen.bg,
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: ChatThreadScreen.border),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                    fontSize: 14, color: ChatThreadScreen.ink),
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(
                      color: ChatThreadScreen.muted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sendButton(),
        ],
      ),
    );
  }

  Widget _sendButton() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final enabled = hasText && !_sending;
    return Material(
      color: enabled
          ? ChatThreadScreen.brand
          : ChatThreadScreen.brand.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? _send : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: _sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _attachButton() {
    return Material(
      color: ChatThreadScreen.bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _sending ? null : _showAttachmentSheet,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.add_rounded,
            color: _sending
                ? ChatThreadScreen.muted
                : ChatThreadScreen.brand,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ── Format helpers ──────────────────────────────────────────────
  String _formatTime(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _formatDay(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const w = [
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ];
      return w[t.weekday - 1];
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}, ${t.year}';
  }
}
