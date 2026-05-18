import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'search_field.dart';
import 'profile_screen.dart';
import 'unit_details.dart';
import 'property_data.dart';
import 'conversations_screen.dart';
import 'favorites_screen.dart';
import 'package:provider/provider.dart';
import 'state/notification_controller.dart';
import 'widgets/notification_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedCategory = 0;
  double? userLat;
  double? userLng;
  String _userCity = '';
  bool _isLoading = true;
  Set<String> _bookmarkedIds = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await fetchProperties();
    } catch (e) {
      debugPrint('HomeScreen _loadData error: $e');
    }
    final pos = await getUserLocation();
    final ids = await fetchMyBookmarkedListingIds();
    if (mounted) {
      setState(() {
        userLat = pos?.latitude ?? 14.3270;
        userLng = pos?.longitude ?? 120.9540;
        computeDistances(allProperties, userLat!, userLng!);
        _userCity = detectUserCity(allProperties);
        _bookmarkedIds = ids;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProperties() async {
    try {
      await fetchProperties();
    } catch (e) {
      debugPrint('HomeScreen _refreshProperties error: $e');
    }
    final ids = await fetchMyBookmarkedListingIds();
    if (!mounted) return;
    setState(() {
      if (userLat != null && userLng != null) {
        computeDistances(allProperties, userLat!, userLng!);
        _userCity = detectUserCity(allProperties);
      }
      _bookmarkedIds = ids;
    });
  }

  Future<void> _onToggleBookmark(Property p) async {
    if (p.id == null || _currentUserId == null) return;
    final wasBookmarked = _bookmarkedIds.contains(p.id);
    // Optimistic update.
    setState(() {
      if (wasBookmarked) {
        _bookmarkedIds.remove(p.id);
      } else {
        _bookmarkedIds.add(p.id!);
      }
    });
    final newState = await toggleBookmark(
      listingId: p.id!,
      currentlyBookmarked: wasBookmarked,
    );
    if (!mounted) return;
    if (newState == wasBookmarked) {
      // Revert on failure.
      setState(() {
        if (wasBookmarked) {
          _bookmarkedIds.add(p.id!);
        } else {
          _bookmarkedIds.remove(p.id);
        }
      });
    }
  }

  void updateCategory(int category) {
    setState(() {
      selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: VxrAppBar(
        title: 'Find Your Perfect Home',
        subtitle: 'Discover rental properties near you',
        leading: const VxrLogoMark(onGradient: true, size: 14),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          Consumer<NotificationController>(
            builder: (context, ctrl, _) => VxrNotificationBell(
              unreadCount: ctrl.unreadCount,
              onTap: () => NotificationPanel.show(context),
            ),
          ),
        ],
        bottom: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchFieldScreen()),
          ),
          child: const AbsorbPointer(
            child: VxrSearchBar(onGradient: true),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(onReturnHome: _refreshProperties),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CategorySection(
                    selectedCategory: selectedCategory,
                    onCategorySelected: updateCategory,
                  ),
                  FeaturedSection(
                    selectedCategory: selectedCategory,
                    userCity: _userCity,
                    currentUserId: _currentUserId,
                    bookmarkedIds: _bookmarkedIds,
                    onToggleBookmark: _onToggleBookmark,
                  ),
                  if (selectedCategory == 0) ...[
                    const SizedBox(height: 16),
                    NeighboringCitiesSection(
                      userCity: _userCity,
                      currentUserId: _currentUserId,
                      bookmarkedIds: _bookmarkedIds,
                      onToggleBookmark: _onToggleBookmark,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

////////////////////////////////////////////////////////
/// CATEGORY CHIP RAIL
////////////////////////////////////////////////////////

class CategorySection extends StatelessWidget {
  final int selectedCategory;
  final Function(int) onCategorySelected;

  const CategorySection({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  static const _labels = ['All', '1 Bedroom', '2 Bedrooms', '3+ Beds'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Center(
          child: VxrChip(
            label: _labels[i],
            active: selectedCategory == i,
            onTap: () => onCategorySelected(i),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// FEATURED SECTION
////////////////////////////////////////////////////////

class FeaturedSection extends StatefulWidget {
  final int selectedCategory;
  final String userCity;
  final String? currentUserId;
  final Set<String> bookmarkedIds;
  final Future<void> Function(Property)? onToggleBookmark;

  const FeaturedSection({
    super.key,
    required this.selectedCategory,
    required this.userCity,
    this.currentUserId,
    this.bookmarkedIds = const {},
    this.onToggleBookmark,
  });

  @override
  State<FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<FeaturedSection> {
  bool _showingNearest = false;

  List<Property> get currentProperties {
    // First try properties in user's city
    final cityProps = propertiesInCity(widget.userCity);
    final filtered =
        propertiesByCategory(widget.selectedCategory, source: cityProps);
    if (filtered.isNotEmpty) {
      _showingNearest = false;
      return filtered;
    }
    // Fallback: show nearest properties with category filter
    _showingNearest = true;
    final nearest = nearestProperties();
    return propertiesByCategory(widget.selectedCategory, source: nearest);
  }

  String getCategoryTitle() {
    final cityLabel =
        widget.userCity.isNotEmpty ? widget.userCity : 'Your Area';
    final prefix = _showingNearest ? 'Nearest ' : '';
    final inCity = _showingNearest ? '' : ' in $cityLabel';

    switch (widget.selectedCategory) {
      case 1:
        return '${prefix}1 Bedroom Properties$inCity';
      case 2:
        return '${prefix}2 Bedroom Properties$inCity';
      case 3:
        return '${prefix}3+ Bedroom Properties$inCity';
      default:
        return '${prefix}Featured$inCity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    List<Property> properties = currentProperties;

    if (properties.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VxrSection(title: getCategoryTitle()),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.filter_alt_off, size: 56, color: t.textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No properties match your filters',
                    style: GoogleFonts.dmSans(fontSize: 13, color: t.textSub),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your filter criteria',
                    style: GoogleFonts.dmSans(fontSize: 11, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VxrSection(title: getCategoryTitle()),
          const SizedBox(height: 8),
          ...properties.map((property) {
            final isOwn = widget.currentUserId != null &&
                property.landlordId == widget.currentUserId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PropertyCard(
                image: property.image,
                title: property.title,
                location: property.location,
                price: property.price,
                beds: property.beds.toString(),
                baths: property.baths,
                area: property.area,
                label: property.label ?? "",
                distanceKm: property.distanceKm,
                showFavorite: !isOwn,
                isFavorited: property.id != null &&
                    widget.bookmarkedIds.contains(property.id),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UnitDetailsScreen(property: property),
                    ),
                  );
                },
                onFavoriteTap: (_) => widget.onToggleBookmark?.call(property),
              ),
            );
          }),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// NEIGHBORING CITIES SECTION (All tab only)
////////////////////////////////////////////////////////

class NeighboringCitiesSection extends StatelessWidget {
  final String userCity;
  final String? currentUserId;
  final Set<String> bookmarkedIds;
  final Future<void> Function(Property)? onToggleBookmark;

  const NeighboringCitiesSection({
    super.key,
    required this.userCity,
    this.currentUserId,
    this.bookmarkedIds = const {},
    this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final cities = nearbyCities(excludeCity: userCity, count: 2);
    if (cities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cities.length; i++) ...[
          _CityPropertyList(
            city: cities[i],
            currentUserId: currentUserId,
            bookmarkedIds: bookmarkedIds,
            onToggleBookmark: onToggleBookmark,
          ),
          if (i != cities.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _CityPropertyList extends StatelessWidget {
  final String city;
  final String? currentUserId;
  final Set<String> bookmarkedIds;
  final Future<void> Function(Property)? onToggleBookmark;

  const _CityPropertyList({
    required this.city,
    this.currentUserId,
    this.bookmarkedIds = const {},
    this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final props = propertiesInCity(city);
    if (props.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VxrSection(title: 'Properties in $city'),
          const SizedBox(height: 8),
          ...props.map((property) {
            final isOwn = currentUserId != null &&
                property.landlordId == currentUserId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PropertyCard(
                image: property.image,
                title: property.title,
                location: property.location,
                price: property.price,
                beds: property.beds.toString(),
                baths: property.baths,
                area: property.area,
                label: property.label ?? '',
                distanceKm: property.distanceKm,
                showFavorite: !isOwn,
                isFavorited: property.id != null &&
                    bookmarkedIds.contains(property.id),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UnitDetailsScreen(property: property),
                    ),
                  );
                },
                onFavoriteTap: (_) => onToggleBookmark?.call(property),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Property Card — Variation B horizontal card (image left, content right,
/// favorite far right). Thin adapter over [VxrPropertyCard] so existing
/// call sites keep working.
class PropertyCard extends StatelessWidget {
  final String image;
  final String title;
  final String location;
  final String price;
  final String beds;
  final String baths;
  final String area;
  final String label;
  final double? distanceKm;
  final VoidCallback onTap;
  final Function(String) onFavoriteTap;
  final bool showFavorite;
  final bool isFavorited;

  const PropertyCard({
    super.key,
    required this.image,
    required this.title,
    required this.location,
    required this.price,
    required this.beds,
    required this.baths,
    required this.area,
    required this.label,
    required this.onTap,
    required this.onFavoriteTap,
    this.distanceKm,
    this.showFavorite = true,
    this.isFavorited = false,
  });

  @override
  Widget build(BuildContext context) {
    return VxrPropertyCard(
      image: image,
      imageIsAsset: image.startsWith('assets/'),
      title: title,
      location: location,
      price: price,
      beds: int.tryParse(beds) ?? 0,
      baths: baths,
      area: area.isEmpty ? '—' : area,
      label: label.isEmpty ? null : label,
      favorited: isFavorited,
      onTap: onTap,
      onFavoriteTap: showFavorite ? () => onFavoriteTap(title) : null,
    );
  }
}

/// BOTTOM NAVIGATION
class CustomBottomNav extends StatefulWidget {
  final Future<void> Function()? onReturnHome;

  const CustomBottomNav({super.key, this.onReturnHome});

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  int _selectedIndex = 0;

  void _handleReturn() {
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
    widget.onReturnHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    return VxrBottomNav(
      activeIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);

        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchFieldScreen()),
          ).then((_) => _handleReturn());
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ConversationsScreen()),
          ).then((_) => _handleReturn());
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          ).then((_) => _handleReturn());
        }
      },
    );
  }
}
