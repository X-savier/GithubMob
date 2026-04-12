import 'package:flutter/material.dart';
import 'search_field.dart';
import 'profile_screen.dart';
import 'unit_details.dart';
import 'filter_widget.dart';

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
  Map<String, dynamic> currentFilters = {};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      bottomNavigationBar: const CustomBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              HeaderSection(onFilterTap: applyFilters),
              const SizedBox(height: 15),
              CategorySection(
                selectedCategory: selectedCategory,
                onCategorySelected: updateCategory,
              ),
              const SizedBox(height: 15),
              FeaturedSection(
                selectedCategory: selectedCategory,
                filters: currentFilters,
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
  final Function(Map<String, dynamic>) onFilterTap;

  const HeaderSection({super.key, required this.onFilterTap});

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
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => FilterWidget(
                  onApplyFilters: onFilterTap,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
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

////////////////////////////////////////////////////////
/// PROPERTY MODEL
////////////////////////////////////////////////////////

class Property {
  final String image;
  final String title;
  final String location;
  final String price;
  final int beds;
  final String baths;
  final String area;
  final String? label;

  Property({
    required this.image,
    required this.title,
    required this.location,
    required this.price,
    required this.beds,
    required this.baths,
    required this.area,
    this.label,
  });
}

////////////////////////////////////////////////////////
/// CATEGORY SECTION
////////////////////////////////////////////////////////

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
          _buildCategoryButton(context, "Studio", 1),
          _buildCategoryButton(context, "1 Bedroom", 2),
          _buildCategoryButton(context, "2 Bedrooms", 3),
          _buildCategoryButton(context, "3+ Bedrooms", 4),
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
  final Map<String, dynamic> filters;

  const FeaturedSection({
    super.key,
    required this.selectedCategory,
    required this.filters,
  });

  @override
  State<FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<FeaturedSection> {
  bool showAll = false;

  // STUDIO APARTMENTS
  final List<Property> studioProperties = [
    Property(
      image: "assets/images/property1.jpg",
      title: "Modern Studio Apartment",
      location: "Makati City, Metro Manila",
      price: "P2,000/month",
      beds: 1,
      baths: "1",
      area: "25m²",
      label: "Popular",
    ),
    Property(
      image: "assets/images/property3.jpg",
      title: "Cozy Studio Loft",
      location: "Makati City",
      price: "P3,000/month",
      beds: 1,
      baths: "1",
      area: "30m²",
    ),
    Property(
      image: "assets/images/property8.jpg",
      title: "Minimalist Studio",
      location: "BGC, Taguig",
      price: "P3,200/month",
      beds: 1,
      baths: "1",
      area: "28m²",
      label: "New",
    ),
  ];

  // 1 BEDROOM PROPERTIES
  final List<Property> oneBedroomProperties = [
    Property(
      image: "assets/images/property4.jpg",
      title: "1BR Modern Unit",
      location: "Pasig City",
      price: "P2,850/month",
      beds: 1,
      baths: "1",
      area: "35m²",
      label: "Popular",
    ),
    Property(
      image: "assets/images/property9.jpg",
      title: "1BR with Balcony",
      location: "Makati City",
      price: "P3,500/month",
      beds: 1,
      baths: "1",
      area: "40m²",
    ),
    Property(
      image: "assets/images/property10.jpg",
      title: "1BR Executive Suite",
      location: "Ortigas Center",
      price: "P4,000/month",
      beds: 1,
      baths: "1",
      area: "45m²",
    ),
  ];

  // 2 BEDROOM PROPERTIES
  final List<Property> twoBedroomProperties = [
    Property(
      image: "assets/images/property2.jpg",
      title: "Spacious 2BR Condo",
      location: "BGC, Taguig",
      price: "P4,500/month",
      beds: 2,
      baths: "2",
      area: "65m²",
      label: "Featured",
    ),
    Property(
      image: "assets/images/property5.jpg",
      title: "2BR Family Home",
      location: "Quezon City",
      price: "P3,500/month",
      beds: 2,
      baths: "2",
      area: "50m²",
    ),
    Property(
      image: "assets/images/property11.jpg",
      title: "2BR Garden Unit",
      location: "Pasay City",
      price: "P4,200/month",
      beds: 2,
      baths: "2",
      area: "55m²",
    ),
  ];

  // 3+ BEDROOM PROPERTIES
  final List<Property> threePlusBedroomProperties = [
    Property(
      image: "assets/images/property6.jpg",
      title: "3BR Townhouse",
      location: "Mandaluyong",
      price: "P5,500/month",
      beds: 3,
      baths: "2",
      area: "85m²",
      label: "Popular",
    ),
    Property(
      image: "assets/images/property7.jpg",
      title: "4BR Villa",
      location: "Alabang",
      price: "P8,000/month",
      beds: 4,
      baths: "3",
      area: "120m²",
      label: "Luxury",
    ),
    Property(
      image: "assets/images/property13.jpg",
      title: "3BR Duplex",
      location: "Quezon City",
      price: "P6,200/month",
      beds: 3,
      baths: "2",
      area: "90m²",
    ),
  ];

  List<Property> getAllProperties() {
    return [
      studioProperties[0],
      oneBedroomProperties[0],
      twoBedroomProperties[0],
      threePlusBedroomProperties[0],
    ];
  }

  bool passesFilters(Property property) {
    final filters = widget.filters;
    if (filters.isEmpty) return true;
    
    if (filters.containsKey('bedrooms') && filters['bedrooms'] > 0) {
      if (property.beds != filters['bedrooms']) return false;
    }
    
    if (filters.containsKey('bathrooms') && filters['bathrooms'] > 0) {
      int propBaths = int.tryParse(property.baths) ?? 0;
      if (propBaths != filters['bathrooms']) return false;
    }
    
    if (filters.containsKey('minArea') && filters.containsKey('maxArea')) {
      int propArea = int.tryParse(property.area.replaceAll('m²', '')) ?? 0;
      if (propArea < filters['minArea'] || propArea > filters['maxArea']) return false;
    }
    
    if (filters.containsKey('city') && filters['city'] != 'Any') {
      if (!property.location.contains(filters['city'])) return false;
    }
    
    if (filters.containsKey('propertyType') && filters['propertyType'] != 'Any') {
      if (!property.title.contains(filters['propertyType'])) return false;
    }
    
    return true;
  }

  List<Property> get currentProperties {
    List<Property> props;
    switch (widget.selectedCategory) {
      case 1:
        props = studioProperties;
        break;
      case 2:
        props = oneBedroomProperties;
        break;
      case 3:
        props = twoBedroomProperties;
        break;
      case 4:
        props = threePlusBedroomProperties;
        break;
      default:
        props = getAllProperties();
    }
    return props.where((p) => passesFilters(p)).toList();
  }

  List<Property> get displayedProperties {
    if (showAll) {
      return currentProperties;
    } else {
      return currentProperties.take(2).toList();
    }
  }

  String getCategoryTitle() {
    if (showAll) {
      switch (widget.selectedCategory) {
        case 1: return "All Studio Apartments";
        case 2: return "All 1 Bedroom Properties";
        case 3: return "All 2 Bedroom Properties";
        case 4: return "All 3+ Bedroom Properties";
        default: return "All Featured Properties";
      }
    } else {
      switch (widget.selectedCategory) {
        case 1: return "Studio Apartments";
        case 2: return "1 Bedroom Properties";
        case 3: return "2 Bedroom Properties";
        case 4: return "3+ Bedroom Properties";
        default: return "Featured Properties";
      }
    }
  }

  void toggleShowAll() {
    setState(() {
      showAll = !showAll;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Property> properties = displayedProperties;

    if (properties.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  getCategoryTitle(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (currentProperties.length > 2)
                  GestureDetector(
                    onTap: toggleShowAll,
                    child: Text(
                      showAll ? "Show Less" : "See All",
                      style: const TextStyle(
                        color: Color(0xfff36c6c),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
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
          Row(
            children: [
              Text(
                getCategoryTitle(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (currentProperties.length > 2)
                GestureDetector(
                  onTap: toggleShowAll,
                  child: Text(
                    showAll ? "Show Less" : "See All",
                    style: const TextStyle(
                      color: Color(0xfff36c6c),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UnitDetailsScreen(
                        image: property.image,
                        title: property.title,
                        location: property.location,
                        price: property.price.replaceAll('P', ''),
                        beds: property.beds.toString(),
                        baths: property.baths,
                        area: property.area,
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
          )).toList(),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(FeaturedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      setState(() {
        showAll = false;
      });
    }
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
                  child: Image.asset(
                    image,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
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
                  Row(
                    children: [
                      _buildInfoChip(Icons.bed, beds, 'Bed'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.bathtub, baths, 'Bath'),
                      const SizedBox(width: 8),
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