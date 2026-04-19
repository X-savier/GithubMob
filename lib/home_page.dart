import 'package:flutter/material.dart';
import 'search_field.dart';
import 'profile_screen.dart';
import 'unit_details.dart';
import 'property_data.dart';

void main() {
  runApp(const ViewXRentApp());
}

class ViewXRentApp extends StatelessWidget {
  const ViewXRentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await fetchProperties();
    } catch (e) {
      debugPrint('HomeScreen _loadData error: $e');
    }
    final pos = await getUserLocation();
    if (mounted) {
      setState(() {
        userLat = pos?.latitude ?? 14.3270;
        userLng = pos?.longitude ?? 120.9540;
        computeDistances(allProperties, userLat!, userLng!);
        _userCity = detectUserCity(allProperties);
        _isLoading = false;
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
      backgroundColor: const Color(0xfff5f5f5),
      bottomNavigationBar: const CustomBottomNav(),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xfff36c6c),
                ),
              )
            : SingleChildScrollView(
          child: Column(
            children: [
              const HeaderSection(),
              const SizedBox(height: 15),
              CategorySection(
                selectedCategory: selectedCategory,
                onCategorySelected: updateCategory,
              ),
              const SizedBox(height: 15),
              FeaturedSection(
                selectedCategory: selectedCategory,
                userCity: _userCity,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// HEADER SECTION
////////////////////////////////////////////////////////

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xfff36c6c),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Text(
                          "V",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xfff36c6c),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "ViewXRent",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Favorites clicked'),
                      backgroundColor: Color(0xfff36c6c),
                    ),
                  );
                },
                child: const Icon(Icons.favorite_border, color: Colors.white),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications clicked'),
                      backgroundColor: Color(0xfff36c6c),
                    ),
                  );
                },
                child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Find Your Perfect Home",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Discover rental properties near you",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 15),

          /// SEARCH BAR
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchFieldScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Search location or property...",
                      style: TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.tune, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class CategorySection extends StatelessWidget {
  final int selectedCategory;
  final Function(int) onCategorySelected;

  const CategorySection({
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
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          _buildCategoryButton(context, "All", 0),
          _buildCategoryButton(context, "1 Bedroom", 1),
          _buildCategoryButton(context, "2 Bedrooms", 2),
          _buildCategoryButton(context, "3+ Bedrooms", 3),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, String text, int index) {
    bool isActive = selectedCategory == index;
    
    return GestureDetector(
      onTap: () {
        onCategorySelected(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Showing: $text'),
            backgroundColor: const Color(0xfff36c6c),
            duration: const Duration(milliseconds: 500),
          ),
        );
      },
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
/// FEATURED SECTION
////////////////////////////////////////////////////////

class FeaturedSection extends StatefulWidget {
  final int selectedCategory;
  final String userCity;

  const FeaturedSection({
    super.key,
    required this.selectedCategory,
    required this.userCity,
  });

  @override
  State<FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<FeaturedSection> {
  bool _showingNearest = false;

  List<Property> get currentProperties {
    // First try properties in user's city
    final cityProps = propertiesInCity(widget.userCity);
    final filtered = propertiesByCategory(widget.selectedCategory, source: cityProps);
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
    final cityLabel = widget.userCity.isNotEmpty ? widget.userCity : 'Your Area';
    final prefix = _showingNearest ? 'Nearest ' : '';
    final inCity = _showingNearest ? '' : ' in $cityLabel';

    switch (widget.selectedCategory) {
      case 1: return '${prefix}Studio Apartments$inCity';
      case 2: return '${prefix}1 Bedroom Properties$inCity';
      case 3: return '${prefix}2 Bedroom Properties$inCity';
      case 4: return '${prefix}3+ Bedroom Properties$inCity';
      default: return '${prefix}Featured Properties$inCity';
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Property> properties = currentProperties;

    if (properties.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getCategoryTitle(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.filter_alt_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'No properties match your filters',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filter criteria',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getCategoryTitle(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 15),

          ...properties.map((property) => Column(
            children: [
              PropertyCard(
                image: property.image,
                title: property.title,
                location: property.location,
                price: property.price,
                beds: property.beds.toString(),
                baths: property.baths,
                area: property.area,
                label: property.label ?? "",
                distanceKm: property.distanceKm,
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
                onFavoriteTap: (title) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title added to favorites'),
                      backgroundColor: const Color(0xfff36c6c),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),
            ],
          )),
        ],
      ),
    );
  }

}

/// Property Card Widget
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
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                    top: Radius.circular(15),
                  ),
                  child: _buildPropertyImage(image, 160),
                ),
                if (label.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff36c6c),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      onFavoriteTap(title);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        size: 18,
                        color: Color(0xfff36c6c),
                      ),
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
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          "${distanceKm!.toStringAsFixed(1)} km",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    price,
                    style: const TextStyle(
                      color: Color(0xfff36c6c),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(Icons.bed, beds, 'Bed'),
                      _buildInfoChip(Icons.bathtub, baths, 'Bath'),
                      _buildInfoChip(Icons.square_foot, area, ''),
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

  Widget _buildInfoChip(IconData icon, String value, String label) {
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
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyImage(String imageSource, double height) {
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
          Text('No Photo', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}

/// BOTTOM NAVIGATION
class CustomBottomNav extends StatefulWidget {
  const CustomBottomNav({super.key});

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xfff36c6c),
      unselectedItemColor: Colors.grey,
      selectedIconTheme: const IconThemeData(color: Color(0xfff36c6c), size: 28),
      unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 24),
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
        
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchFieldScreen()),
          ).then((_) {
            setState(() {
              _selectedIndex = 0;
            });
          });
        } else if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Messages feature coming soon!'),
              backgroundColor: Color(0xfff36c6c),
            ),
          );
          setState(() {
            _selectedIndex = 0;
          });
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          ).then((_) {
            setState(() {
              _selectedIndex = 0;
            });
          });
        }
      },
    );
  }
}