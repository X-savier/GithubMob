import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'unit_details.dart';
import 'filter_widget.dart';

class SearchFieldScreen extends StatefulWidget {
  const SearchFieldScreen({super.key});

  @override
  State<SearchFieldScreen> createState() => _SearchFieldScreenState();
}

class _SearchFieldScreenState extends State<SearchFieldScreen> {
  int _selectedIndex = 1;
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Search",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black87),
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
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
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
      body: SafeArea(
        child: SingleChildScrollView(
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
                        decoration: InputDecoration(
                          hintText: "Search location and property",
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onSubmitted: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Searching for: $value'),
                              backgroundColor: const Color(0xfff36c6c),
                            ),
                          );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Map view coming soon!'),
                                  backgroundColor: Color(0xfff36c6c),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text("Map"),
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

              // Category Section
              SearchCategorySection(
                selectedCategory: selectedCategory,
                onCategorySelected: updateCategory,
              ),

              const SizedBox(height: 16),

              // Found Properties Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      _getFoundPropertiesText(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Property List
              SearchPropertyList(
                selectedCategory: selectedCategory,
                filters: currentFilters,
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
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
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
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

  String _getFoundPropertiesText() {
    int count = getFilteredPropertiesForCategory(selectedCategory).length;
    switch (selectedCategory) {
      case 1:
        return "Found $count Studio Apartments";
      case 2:
        return "Found $count 1 Bedroom Properties";
      case 3:
        return "Found $count 2 Bedroom Properties";
      case 4:
        return "Found $count 3+ Bedroom Properties";
      default:
        return "Found $count Properties";
    }
  }
}

////////////////////////////////////////////////////////
/// PROPERTY MODEL
////////////////////////////////////////////////////////

class SearchProperty {
  final String image;
  final String title;
  final String location;
  final String price;
  final int beds;
  final String baths;
  final String area;
  final String? label;

  SearchProperty({
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
/// SEARCH PROPERTY DATA
////////////////////////////////////////////////////////

// STUDIO APARTMENTS
final List<SearchProperty> studioProperties = [
  SearchProperty(
    image: "assets/images/property1.jpg",
    title: "Modern Studio Apartment",
    location: "Makati City, Metro Manila",
    price: "P2,000/month",
    beds: 1,
    baths: "1",
    area: "25m²",
    label: "Popular",
  ),
  SearchProperty(
    image: "assets/images/property3.jpg",
    title: "Cozy Studio Loft",
    location: "Makati City",
    price: "P3,000/month",
    beds: 1,
    baths: "1",
    area: "30m²",
  ),
  SearchProperty(
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
final List<SearchProperty> oneBedroomProperties = [
  SearchProperty(
    image: "assets/images/property4.jpg",
    title: "1BR Modern Unit",
    location: "Pasig City",
    price: "P2,850/month",
    beds: 1,
    baths: "1",
    area: "35m²",
    label: "Popular",
  ),
  SearchProperty(
    image: "assets/images/property9.jpg",
    title: "1BR with Balcony",
    location: "Makati City",
    price: "P3,500/month",
    beds: 1,
    baths: "1",
    area: "40m²",
  ),
  SearchProperty(
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
final List<SearchProperty> twoBedroomProperties = [
  SearchProperty(
    image: "assets/images/property2.jpg",
    title: "Spacious 2BR Condo",
    location: "BGC, Taguig",
    price: "P4,500/month",
    beds: 2,
    baths: "2",
    area: "65m²",
    label: "Featured",
  ),
  SearchProperty(
    image: "assets/images/property5.jpg",
    title: "2BR Family Home",
    location: "Quezon City",
    price: "P3,500/month",
    beds: 2,
    baths: "2",
    area: "50m²",
  ),
  SearchProperty(
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
final List<SearchProperty> threePlusBedroomProperties = [
  SearchProperty(
    image: "assets/images/property6.jpg",
    title: "3BR Townhouse",
    location: "Mandaluyong",
    price: "P5,500/month",
    beds: 3,
    baths: "2",
    area: "85m²",
    label: "Popular",
  ),
  SearchProperty(
    image: "assets/images/property7.jpg",
    title: "4BR Villa",
    location: "Alabang",
    price: "P8,000/month",
    beds: 4,
    baths: "3",
    area: "120m²",
    label: "Luxury",
  ),
  SearchProperty(
    image: "assets/images/property13.jpg",
    title: "3BR Duplex",
    location: "Quezon City",
    price: "P6,200/month",
    beds: 3,
    baths: "2",
    area: "90m²",
  ),
];

List<SearchProperty> getAllProperties() {
  return [
    studioProperties[0],
    oneBedroomProperties[0],
    twoBedroomProperties[0],
    threePlusBedroomProperties[0],
  ];
}

bool passesSearchFilters(SearchProperty property, Map<String, dynamic> filters) {
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
  
  return true;
}

List<SearchProperty> getFilteredPropertiesForCategory(int category) {
  List<SearchProperty> props;
  switch (category) {
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
  return props;
}

////////////////////////////////////////////////////////
/// SEARCH PROPERTY LIST
////////////////////////////////////////////////////////

class SearchPropertyList extends StatelessWidget {
  final int selectedCategory;
  final Map<String, dynamic> filters;

  const SearchPropertyList({
    super.key,
    required this.selectedCategory,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    List<SearchProperty> allProps = getFilteredPropertiesForCategory(selectedCategory);
    List<SearchProperty> filteredProps = allProps.where((p) => passesSearchFilters(p, filters)).toList();

    if (filteredProps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
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
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: filteredProps.map((property) {
          return Column(
            children: [
              SearchPropertyCard(property: property),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class SearchPropertyCard extends StatelessWidget {
  final SearchProperty property;

  const SearchPropertyCard({
    super.key,
    required this.property,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                    property.image,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
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
                if (property.label != null && property.label!.isNotEmpty)
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
                        property.label!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
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
                          content: Text('${property.title} added to favorites'),
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
                    property.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                      _buildInfoChip(Icons.bed, property.beds.toString(), 'Bed'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.bathtub, property.baths, 'Bath'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.square_foot, property.area, ''),
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
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}