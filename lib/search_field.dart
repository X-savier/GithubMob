import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'conversations_screen.dart';
import 'profile_screen.dart';
import 'unit_details.dart';
import 'filter_widget.dart';
import 'property_data.dart';
import 'favorites_screen.dart';

class SearchFieldScreen extends StatefulWidget {
  const SearchFieldScreen({super.key});

  @override
  State<SearchFieldScreen> createState() => _SearchFieldScreenState();
}

class _SearchFieldScreenState extends State<SearchFieldScreen> {
  int _selectedIndex = 1;
  int selectedCategory = 0;
  Map<String, dynamic> currentFilters = {};
  bool _showMap = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const _chipLabels = ['All', '1 Bed', '2 Bed', '3+ Bed'];

  double? userLat;
  double? userLng;
  GoogleMapController? _mapController;
  bool _isLoading = true;
  Set<String> _bookmarkedIds = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _onToggleBookmark(Property p) async {
    if (p.id == null || _currentUserId == null) return;
    final wasBookmarked = _bookmarkedIds.contains(p.id);
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
      setState(() {
        if (wasBookmarked) {
          _bookmarkedIds.add(p.id!);
        } else {
          _bookmarkedIds.remove(p.id);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (allProperties.isEmpty) {
        await fetchProperties();
      }
    } catch (e) {
      debugPrint('SearchField _loadData error: $e');
    }
    final pos = await getUserLocation();
    final ids = await fetchMyBookmarkedListingIds();
    if (mounted) {
      setState(() {
        userLat = pos?.latitude ?? 14.3270;
        userLng = pos?.longitude ?? 120.9540;
        computeDistances(allProperties, userLat!, userLng!);
        _bookmarkedIds = ids;
        _isLoading = false;
      });
    }
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterWidget(onApplyFilters: applyFilters),
    );
  }

  void applyFilters(Map<String, dynamic> filters) {
    setState(() {
      currentFilters = filters;
    });
    String message = 'Filters applied: ';
    if (filters['bedrooms'] > 0) message += '${filters['bedrooms']} bed, ';
    if (filters['bathrooms'] > 0) message += '${filters['bathrooms']} bath, ';
    message += '${filters['minArea']}-${filters['maxArea']}m²';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<Property> get _filteredProperties {
    List<Property> props = propertiesByCategory(selectedCategory);
    props = props.where((p) => passesFilters(p, currentFilters)).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      props = props
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.location.toLowerCase().contains(q))
          .toList();
    }
    final sortBy = currentFilters['sortBy'];
    if (sortBy != null && sortBy != 'Any') {
      sortProperties(props, sortBy);
    } else {
      props.sort((a, b) {
        final aDist = a.distanceKm ?? double.infinity;
        final bDist = b.distanceKm ?? double.infinity;
        return aDist.compareTo(bDist);
      });
    }
    return props;
  }

  Set<Marker> get _markers {
    final props = _filteredProperties;
    return props.map((p) {
      final isWithinRadius = p.distanceKm != null && p.distanceKm! <= 5.0;
      return Marker(
        markerId: MarkerId(p.title),
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isWithinRadius
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: p.title,
          snippet:
              '${p.price} • ${p.distanceKm?.toStringAsFixed(1) ?? "?"} km away',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitDetailsScreen(property: p),
              ),
            );
          },
        ),
      );
    }).toSet();
  }

  Set<Circle> get _radiusCircles {
    if (userLat == null || userLng == null) return {};
    return {
      Circle(
        circleId: const CircleId('user_5km_radius'),
        center: LatLng(userLat!, userLng!),
        radius: 5000, // 5 km in meters
        fillColor: VxrTokens.accent.withOpacity(0.08),
        strokeColor: VxrTokens.accent,
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: VxrSurfaceAppBar(
        title: 'Search Properties',
        subtitle: 'Find your perfect rental home',
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_border, color: t.text),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              ).then((_) => _loadData());
            },
          ),
        ],
        bottom: VxrSearchBar(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          onFilterTap: _openFilters,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VxrTokens.accent))
          : Column(
              children: [
                // Chip rail
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                    itemCount: _chipLabels.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Center(
                      child: VxrChip(
                        label: _chipLabels[i],
                        active: selectedCategory == i,
                        onTap: () => setState(() => selectedCategory = i),
                      ),
                    ),
                  ),
                ),

                // Results header + List/Map toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_filteredProperties.length} Properties Found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.text,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: t.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _segment('List', !_showMap,
                                () => setState(() => _showMap = false)),
                            _segment('Map', _showMap,
                                () => setState(() => _showMap = true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(child: _showMap ? _buildMapView() : _buildListView()),
              ],
            ),
      bottomNavigationBar: VxrBottomNav(
        activeIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.pop(context);
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ConversationsScreen()),
            ).then((_) => setState(() => _selectedIndex = 1));
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ).then((_) => setState(() => _selectedIndex = 1));
          }
        },
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    final t = VxrTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : t.textSub,
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    final center = (userLat != null && userLng != null)
        ? LatLng(userLat!, userLng!)
        : const LatLng(14.3270, 120.9540);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 13),
          markers: _markers,
          circles: _radiusCircles,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          onMapCreated: (controller) => _mapController = controller,
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VxrTokens.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: VxrTokens.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendRow(Colors.red, 'Within 5 km'),
                const SizedBox(height: 4),
                _legendRow(Colors.orange, 'Beyond 5 km'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendRow(Color dot, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.dmSans(fontSize: 11)),
      ],
    );
  }

  Widget _buildListView() {
    final t = VxrTheme.of(context);
    final props = _filteredProperties;
    if (props.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 56, color: t.textMuted),
            const SizedBox(height: 10),
            Text(
              'No properties match your search',
              style: GoogleFonts.dmSans(fontSize: 13, color: t.textSub),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      itemCount: props.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final property = props[index];
        final isOwn =
            _currentUserId != null && property.landlordId == _currentUserId;
        return VxrPropertyCard(
          image: property.image,
          imageIsAsset: property.image.startsWith('assets/'),
          title: property.title,
          location: property.location,
          price: property.price,
          beds: property.beds,
          baths: property.baths,
          area: property.area.isEmpty ? '—' : property.area,
          label: (property.label != null && property.label!.isNotEmpty)
              ? property.label
              : null,
          favorited: property.id != null &&
              _bookmarkedIds.contains(property.id),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitDetailsScreen(property: property),
              ),
            );
          },
          onFavoriteTap: isOwn ? null : () => _onToggleBookmark(property),
        );
      },
    );
  }
}
