import 'package:flutter/material.dart';

class FilterWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;

  const FilterWidget({
    super.key,
    required this.onApplyFilters,
  });

  @override
  State<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  // Dropdown selections
  String selectedSortBy = 'Any';
  String selectedPropertyType = 'Any';
  String selectedFurnishing = 'Any';
  String selectedPetPolicy = 'Any';
  String selectedSmokingPolicy = 'Any';
  
  // Counter values
  int bedrooms = 0;
  int bathrooms = 0;
  double minArea = 0;
  double maxArea = 200;

  final List<String> sortByOptions = ['Any', 'Price: Low to High', 'Price: High to Low', 'Nearest'];
  final List<String> propertyTypeOptions = ['Any', 'Apartment', 'House', 'Condo', 'Studio', 'Room', 'Townhouse'];
  final List<String> furnishingOptions = ['Any', 'Fully Furnished', 'Semi-Furnished', 'Unfurnished'];
  final List<String> petPolicyOptions = ['Any', 'Pets Allowed', 'No Pets'];
  final List<String> smokingPolicyOptions = ['Any', 'Smoking Allowed', 'No Smoking'];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedSortBy = 'Any';
                          selectedPropertyType = 'Any';
                          selectedFurnishing = 'Any';
                          selectedPetPolicy = 'Any';
                          selectedSmokingPolicy = 'Any';
                          bedrooms = 0;
                          bathrooms = 0;
                          minArea = 0;
                          maxArea = 200;
                        });
                      },
                      child: const Text(
                        'Reset All',
                        style: TextStyle(
                          color: Color(0xfff36c6c),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildFilterDropdown('Sort By', sortByOptions, selectedSortBy, (value) {
                      setState(() => selectedSortBy = value!);
                    }),
                    _buildFilterDropdown('Property Type', propertyTypeOptions, selectedPropertyType, (value) {
                      setState(() => selectedPropertyType = value!);
                    }),
                    
                    // Bedrooms Counter
                    _buildCounterFilter(
                      label: 'Bedrooms',
                      icon: Icons.bed,
                      value: bedrooms,
                      onIncrement: () => setState(() => bedrooms++),
                      onDecrement: () => setState(() {
                        if (bedrooms > 0) bedrooms--;
                      }),
                    ),
                    
                    // Bathrooms Counter
                    _buildCounterFilter(
                      label: 'Bathrooms',
                      icon: Icons.bathtub,
                      value: bathrooms,
                      onIncrement: () => setState(() => bathrooms++),
                      onDecrement: () => setState(() {
                        if (bathrooms > 0) bathrooms--;
                      }),
                    ),
                    
                    // Area Range
                    _buildAreaFilter(),
                    
                    _buildFilterDropdown('Furnishing', furnishingOptions, selectedFurnishing, (value) {
                      setState(() => selectedFurnishing = value!);
                    }),
                    _buildFilterDropdown('Pet Policy', petPolicyOptions, selectedPetPolicy, (value) {
                      setState(() => selectedPetPolicy = value!);
                    }),
                    _buildFilterDropdown('Smoking Policy', smokingPolicyOptions, selectedSmokingPolicy, (value) {
                      setState(() => selectedSmokingPolicy = value!);
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Apply Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () {
                    final filters = {
                      'sortBy': selectedSortBy,
                      'propertyType': selectedPropertyType,
                      'bedrooms': bedrooms,
                      'bathrooms': bathrooms,
                      'minArea': minArea,
                      'maxArea': maxArea,
                      'furnishing': selectedFurnishing,
                      'petPolicy': selectedPetPolicy,
                      'smokingPolicy': selectedSmokingPolicy,
                    };
                    widget.onApplyFilters(filters);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff36c6c),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    String label,
    List<String> options,
    String selectedValue,
    Function(String?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
        ),
        child: DropdownButtonFormField<String>(
          initialValue: selectedValue,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildCounterFilter({
    required String label,
    required IconData icon,
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove, size: 18),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    value == 0 ? 'Any' : value.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add, size: 18),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaFilter() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.square_foot, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              const Text(
                'Area (m²)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: minArea.toInt().toString(),
                  decoration: InputDecoration(
                    labelText: 'Min',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      minArea = double.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('to'),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: maxArea.toInt().toString(),
                  decoration: InputDecoration(
                    labelText: 'Max',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      maxArea = double.tryParse(value) ?? 200;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}