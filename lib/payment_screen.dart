import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  // Theme colors based on the design
  static const Color primaryOrange = Color(0xFFFF9800); // Orange color for buttons and accents
  static const Color lightOrange = Color(0xFFFFF3E0); // Light orange background
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color borderColor = Color(0xFFEEEEEE);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color pendingOrange = Color(0xFFFF9800);
  static const Color completedGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Payment',
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
          // Upcoming Payment Reminder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightOrange,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryOrange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: primaryOrange, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Upcoming Payment Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your next monthly rent payment of \$2,400.00 is due on March 1, 2026 (24 days remaining).',
                  style: TextStyle(
                    fontSize: 14,
                    color: lightText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryOrange,
                          side: BorderSide(color: primaryOrange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Payment will be charged to your Gcash',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Total Paid and Pending Payments Row
          Row(
            children: [
              Expanded(
                child: Container(
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
                        'Total Paid',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₱4,100',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: successGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All completed payments',
                        style: TextStyle(
                          fontSize: 12,
                          color: lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
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
                        'Pending Payments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₱0',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: pendingOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Awaiting processing',
                        style: TextStyle(
                          fontSize: 12,
                          color: lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment Method
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lightOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.phone_android, color: primaryOrange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            '+63',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '123456789',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Primary payment method',
                        style: TextStyle(
                          fontSize: 12,
                          color: lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit, color: primaryOrange, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Transaction History
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
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete payment record for this booking',
                  style: TextStyle(
                    fontSize: 14,
                    color: lightText,
                  ),
                ),
                const SizedBox(height: 16),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      _buildTableHeader('Data', flex: 1),
                      _buildTableHeader('Description', flex: 2),
                      _buildTableHeader('Payment Method', flex: 2),
                      _buildTableHeader('Amount', flex: 1),
                      _buildTableHeader('Status', flex: 1),
                    ],
                  ),
                ),

                // Transaction Rows
                _buildTransactionRow(
                  date: 'Jan 28, 2026',
                  description: 'Apartment Payment - Sunset Villa Unit 204',
                  method: 'G1 | 63+ 9393094453',
                  amount: '₱2,400.00',
                  status: 'Completed',
                  statusColor: completedGreen,
                ),
                _buildTransactionRow(
                  date: 'Jan 28, 2026',
                  description: 'Security Deposit',
                  method: 'G1 | 63+ 9393094453',
                  amount: '₱500.00',
                  status: 'Completed',
                  statusColor: completedGreen,
                ),
                _buildTransactionRow(
                  date: 'Jan 28, 2026',
                  description: 'Booking Deposit (50%)',
                  method: 'G1 | 63+ 9393094453',
                  amount: '₱1,200.00',
                  status: 'Completed',
                  statusColor: completedGreen,
                  showBorder: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Next Payment Due
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Due Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Feb 2, 2026',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                            'Amount Due',
                            style: TextStyle(
                              fontSize: 14,
                              color: lightText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱4,100.00',
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lightOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.phone_android, color: primaryOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 12,
                            color: lightText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '+63 123456789',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                    ),
                    child: const Text(
                      'Pay ₱ 4,100.00 Now',
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

  Widget _buildTableHeader(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: lightText,
        ),
      ),
    );
  }

  Widget _buildTransactionRow({
    required String date,
    required String description,
    required String method,
    required String amount,
    required String status,
    required Color statusColor,
    bool showBorder = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: showBorder ? Border(bottom: BorderSide(color: borderColor)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              date,
              style: const TextStyle(fontSize: 11, color: darkText),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              description,
              style: const TextStyle(fontSize: 11, color: darkText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              method,
              style: const TextStyle(fontSize: 11, color: darkText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: darkText,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}