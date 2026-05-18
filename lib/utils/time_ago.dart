String timeAgo(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${when.year}-${_pad(when.month)}-${_pad(when.day)}';
}

String _pad(int n) => n.toString().padLeft(2, '0');
