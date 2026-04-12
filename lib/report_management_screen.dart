import 'package:flutter/material.dart';

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  // Theme colors
  static const Color primaryOrange = Color(0xFFFF7043);
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color borderColor = Color(0xFFEEEEEE);

  // Status colors
  static const Color highPriority = Color(0xFFF44336);
  static const Color mediumPriority = Color(0xFFFF9800);
  static const Color lowPriority = Color(0xFF4CAF50);
  static const Color inProgress = Color(0xFF2196F3);
  static const Color resolved = Color(0xFF4CAF50);
  static const Color open = Color(0xFFFF9800);

  // Selected values for dropdowns
  String selectedType = 'All';
  String selectedStatus = 'All';
  String selectedPriority = 'All';

  // Dropdown options
  final List<String> typeOptions = [
    'All',
    'Maintenance',
    'Cleaning',
    'Amenity',
    'Noise',
    'Other'
  ];

  final List<String> statusOptions = [
    'All',
    'Open',
    'In-progress',
    'Resolved'
  ];

  final List<String> priorityOptions = [
    'All',
    'High',
    'Medium',
    'Low'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Report Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryOrange,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryOrange),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Section with Dropdowns
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        value: selectedType,
                        items: typeOptions,
                        hint: 'Type',
                        onChanged: (value) {
                          setState(() {
                            selectedType = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        value: selectedStatus,
                        items: statusOptions,
                        hint: 'Status',
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        value: selectedPriority,
                        items: priorityOptions,
                        hint: 'Priority',
                        onChanged: (value) {
                          setState(() {
                            selectedPriority = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // All Reports Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                Text(
                  'Showing 10 of 10 reports',
                  style: TextStyle(
                    fontSize: 14,
                    color: lightText,
                  ),
                ),
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildReportCard(
                  title: 'Air Conditioning not cooling properly',
                  priority: 'High',
                  priorityColor: highPriority,
                  status: 'In-progress',
                  statusColor: inProgress,
                  date: 'Feb 13, 2026 - 2:30 PM',
                  location: 'Las Piñas, Metro Manila',
                  description: 'The AC unit in the bedroom is running but not cooling effectively. The temperature is set to 68°F but the room stays at 75°F. Started noticing this issue yesterday evening.',
                ),
                const SizedBox(height: 16),
                _buildReportCard(
                  title: 'Leaking faucet in bathroom',
                  priority: 'Medium',
                  priorityColor: mediumPriority,
                  status: 'Open',
                  statusColor: open,
                  date: 'Feb 14, 2026 - 9:15 PM',
                  location: 'Las Piñas, Metro Manila',
                  description: 'The bathroom sink faucet has a slow drip that continues even when fully closed. It\'s been dripping for about 3 days now and seems to be getting worse.',
                ),
                const SizedBox(height: 16),
                _buildReportCard(
                  title: 'Wifi password request',
                  priority: 'Low',
                  priorityColor: lowPriority,
                  status: 'Resolved',
                  statusColor: resolved,
                  date: 'Feb 12, 2026 - 9:15 PM',
                  location: 'Las Piñas, Metro Manila',
                  description: 'Guest requested WiFi password for additional devices. Need to connect laptop and tablet for work purposes.',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Status Legend with "STATUS" header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
              color: Colors.white,
            ),
            child: Column(
              children: [
                const Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusLegend('Open', open),
                    const SizedBox(width: 24),
                    _buildStatusLegend('In-progress', inProgress),
                    const SizedBox(width: 24),
                    _buildStatusLegend('Resolved', resolved),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            color: lightText,
          ),
        ),
        icon: Icon(Icons.arrow_drop_down, color: primaryOrange),
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 14,
                color: darkText,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String priority,
    required Color priorityColor,
    required String status,
    required Color statusColor,
    required String date,
    required String location,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: priorityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: lightText),
              const SizedBox(width: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: lightText),
              const SizedBox(width: 4),
              Text(
                location,
                style: TextStyle(
                  fontSize: 12,
                  color: lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: darkText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: lightText,
          ),
        ),
      ],
    );
  }
}