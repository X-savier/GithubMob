import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'property_data.dart';
import 'unit_details.dart';

/// List of the signed-in user's bookmarked listings. Pull-to-refresh
/// supported. Tap a card → unit details. Heart toggles persist.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loading = true;
  List<Property> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await fetchMyBookmarks();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _unbookmark(Property p) async {
    if (p.id == null) return;
    final ok = await removeBookmark(p.id!);
    if (!mounted) return;
    if (ok) {
      setState(() => _items.removeWhere((x) => x.id == p.id));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove bookmark')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: VxrAppBar(
        title: 'My Favorites',
        subtitle: 'Listings you saved',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : _items.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: VxrTokens.accent,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = _items[index];
                  return VxrPropertyCard(
                    image: p.image,
                    imageIsAsset: p.image.startsWith('assets/'),
                    title: p.title,
                    location: p.location,
                    price: p.price,
                    beds: p.beds,
                    baths: p.baths,
                    area: p.area.isEmpty ? '—' : p.area,
                    label: (p.label != null && p.label!.isNotEmpty)
                        ? p.label
                        : null,
                    favorited: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UnitDetailsScreen(property: p),
                        ),
                      ).then((_) => _load());
                    },
                    onFavoriteTap: () => _unbookmark(p),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final t = VxrTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 56, color: t.textMuted),
          const SizedBox(height: 12),
          Text(
            'No favorites yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the heart on a listing to save it here.',
            style: GoogleFonts.dmSans(fontSize: 12, color: t.textSub),
          ),
        ],
      ),
    );
  }
}

/// One-shot toggle helper used by individual cards. Returns the new
/// bookmarked state on success, or [currentlyBookmarked] unchanged
/// on failure. Hides the snackbar/alerting policy from callers.
Future<bool> toggleBookmark({
  required String listingId,
  required bool currentlyBookmarked,
}) async {
  if (Supabase.instance.client.auth.currentUser == null)
    return currentlyBookmarked;
  final ok = currentlyBookmarked
      ? await removeBookmark(listingId)
      : await addBookmark(listingId);
  return ok ? !currentlyBookmarked : currentlyBookmarked;
}
