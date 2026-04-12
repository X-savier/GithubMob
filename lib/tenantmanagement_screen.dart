import 'package:flutter/material.dart';
import 'payment_screen.dart';
import 'report_management_screen.dart';

class TenantManagementScreen extends StatelessWidget {
  const TenantManagementScreen({super.key});

  // Theme colors - EXACTLY as specified
  static const Color primaryOrange = Color(0xFFFF7043); // Main orange
  static const Color lightOrange = Color(0xFFFF8A80); // Light orange
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color borderColor = Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tenant Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tenant Management Header - IN PRIMARY ORANGE (0xFFFF7043)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Tenant Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryOrange,
              ),
            ),
          ),
          
          // Current Stay Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Stay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Guest name row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Guest name:',
                            style: TextStyle(
                              fontSize: 13,
                              color: lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Juan dela cruz',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Property:',
                            style: TextStyle(
                              fontSize: 13,
                              color: lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sunset Villa',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Check in/out row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check in/ Check out:',
                            style: TextStyle(
                              fontSize: 13,
                              color: lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Jan 28, 2026 - Feb 9, 2026',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Days Remaining:',
                            style: TextStyle(
                              fontSize: 13,
                              color: lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '12 Days',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Reporting | Chat | Payment row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.report_problem,
                      label: 'Reporting',
                      onTap: () {
                        // Navigate to Report Management Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportManagementScreen(),
                          ),
                        );
                      },
                    ),
                    Container(
                      height: 20,
                      width: 1,
                      color: borderColor,
                    ),
                    _buildActionButton(
                      icon: Icons.chat,
                      label: 'Chat',
                      onTap: () {
                        // Handle Chat
                      },
                    ),
                    Container(
                      height: 20,
                      width: 1,
                      color: borderColor,
                    ),
                    _buildActionButton(
                      icon: Icons.payment,
                      label: 'Payment',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PaymentScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Submit New Report Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit New Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Report Type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: 'Maintenance',
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Report Type',
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: lightText,
                      ),
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: primaryOrange),
                    items: const [
                      DropdownMenuItem(
                        value: 'Maintenance',
                        child: Text('Maintenance'),
                      ),
                      DropdownMenuItem(
                        value: 'Cleaning',
                        child: Text('Cleaning'),
                      ),
                      DropdownMenuItem(
                        value: 'Amenity Request',
                        child: Text('Amenity Request'),
                      ),
                      DropdownMenuItem(
                        value: 'Noise Complaint',
                        child: Text('Noise Complaint'),
                      ),
                      DropdownMenuItem(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {},
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Priority Type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: 'Medium',
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Priority Type',
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: lightText,
                      ),
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: primaryOrange),
                    items: const [
                      DropdownMenuItem(
                        value: 'Low',
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: 'Medium',
                        child: Text('Medium'),
                      ),
                      DropdownMenuItem(
                        value: 'High',
                        child: Text('High'),
                      ),
                    ],
                    onChanged: (value) {},
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Title
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(
                      fontSize: 14,
                      color: lightText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryOrange, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                TextFormField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(
                      fontSize: 14,
                      color: lightText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryOrange, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Submit Report Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: primaryOrange,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primaryOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}