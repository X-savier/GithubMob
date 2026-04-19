import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'profile_screen.dart';
import 'unit_details.dart';
import 'filter_widget.dart';
import 'property_data.dart';

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

  double? userLat;
  double? userLng;
  GoogleMapController? _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    if (mounted) {
      setState(() {
        userLat = pos?.latitude ?? 14.3270;
        userLng = pos?.longitude ?? 120.9540;
        computeDistances(allProperties, userLat!, userLng!);
        _isLoading = false;
      });
    }
  }

  void updateCategory(int category) {
    setState(() {
      selectedCategory = category;
    });
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
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xfff36c6c),
      ),
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
    }
    return props;
  }

  List<Property> get _propertiesWithinRadius {
    return _filteredProperties
        .where((p) => p.distanceKm != null && p.distanceKm! <= 5.0)
        .toList();
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
                builder: (context) => UnitDetailsScreen(
                  property: p,
                ),
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
        fillColor: const Color(0xfff36c6c).withOpacity(0.08),
        strokeColor: const Color(0xfff36c6c),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        backgroundColor: const Color(0xfff36c6c),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Search",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Favorites clicked'),
                  backgroundColor: Color(0xfff36c6c),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications clicked'),
                  backgroundColor: Color(0xfff36c6c),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xfff36c6c),
              ),
            )
          : SafeArea(
        child: Column(
          children: [
            // Search Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search location or property...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Filter and Map Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => FilterWidget(
                                onApplyFilters: applyFilters,
                              ),
                            );
                          },
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: const Text("Filter"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showMap = !_showMap;
                            });
                          },
                          icon: Icon(
                              _showMap ? Icons.list : Icons.map_outlined,
                              size: 18),
                          label: Text(_showMap ? "List" : "Map"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff36c6c),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Found count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    "Found ${_filteredProperties.length} Properties",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (userLat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xfff36c6c).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me,
                              size: 14, color: Color(0xfff36c6c)),
                          const SizedBox(width: 4),
                          Text(
                            '${_propertiesWithinRadius.length} within 5 km',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xfff36c6c),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Map or List
            Expanded(
              child: _showMap ? _buildMapView() : _buildListView(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xfff36c6c),
        unselectedItemColor: Colors.grey,
        selectedIconTheme:
            const IconThemeData(color: Color(0xfff36c6c), size: 28),
        unselectedIconTheme:
            const IconThemeData(color: Colors.grey, size: 24),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: "Message",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            Navigator.pop(context);
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Messages feature coming soon!'),
                backgroundColor: Color(0xfff36c6c),
              ),
            );
            setState(() {
              _selectedIndex = 1;
            });
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ProfileScreen()),
            ).then((_) {
              setState(() {
                _selectedIndex = 1;
              });
            });
          }
        },
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
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: 13, // Shows the full 5 km radius
          ),
          markers: _markers,
          circles: _radiusCircles,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
          },
        ),
        // Legend overlay
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Within 5 km',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Beyond 5 km',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final props = _filteredProperties;
    if (props.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'No properties match your search',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: props.length,
      itemBuilder: (context, index) {
        final property = props[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SearchPropertyCard(property: property),
        );
      },
    );
  }
}

////////////////////////////////////////////////////////
/// SEARCH CATEGORY SECTION
////////////////////////////////////////////////////////

class SearchCategorySection extends StatelessWidget {
  final int selectedCategory;
  final Function(int) onCategorySelected;

  const SearchCategorySection({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryButton(context, "All", 0),
          _buildCategoryButton(context, "Studio", 1),
          _buildCategoryButton(context, "1 Bedroom", 2),
          _buildCategoryButton(context, "2 Bedrooms", 3),
          _buildCategoryButton(context, "3+ Bedrooms", 4),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(
      BuildContext context, String text, int index) {
    bool isActive = selectedCategory == index;

    return GestureDetector(
      onTap: () => onCategorySelected(index),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xfff36c6c) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// SEARCH PROPERTY CARD
////////////////////////////////////////////////////////

class _SearchPropertyCard extends StatelessWidget {
  final Property property;

  const _SearchPropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnitDetailsScreen(
              property: property,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15)),
                  child: _buildImage(property.image, 180),
                ),
                if (property.label != null &&
                    property.label!.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xfff36c6c),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.label!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${property.title} added to favorites'),
                          backgroundColor: const Color(0xfff36c6c),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border,
                          size: 18, color: Color(0xfff36c6c)),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (property.distanceKm != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          "${property.distanceKm!.toStringAsFixed(1)} km",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    property.price,
                    style: const TextStyle(
                      color: Color(0xfff36c6c),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(
                          Icons.bed, property.beds.toString(), 'Bed'),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                          Icons.bathtub, property.baths, 'Bath'),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                          Icons.square_foot, property.area, ''),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label.isEmpty ? value : '$value $label',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageSource, double height) {
    final isUrl = imageSource.startsWith('http://') ||
        imageSource.startsWith('https://');

    if (isUrl) {
      return Image.network(
        imageSource,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _imagePlaceholder(height);
        },
      );
    }

    if (imageSource.isNotEmpty) {
      return Image.asset(
        imageSource,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _imagePlaceholder(height);
        },
      );
    }

    return _imagePlaceholder(height);
  }

  Widget _imagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment, size: 50, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text('No Photo',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}