import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';

import 'manage_listing.dart';
import 'property_data.dart';

/// Shown to the landlord immediately after a contract is closed.
/// Offers three options:
///   1. Relist as-is   → sets listing.status = 'active'
///   2. Edit and relist → opens HouseEnlistmentScreen in edit mode
///   3. Keep archived   → pops to previous screen
class RelistPromptScreen extends StatefulWidget {
  final String listingId;

  const RelistPromptScreen({super.key, required this.listingId});

  static const Color brand = VxrTokens.accent;
  static const Color coral = VxrTokens.gradMid;
  static const Color light = VxrTokens.gradEnd;
  static const Color ink = VxrTokens.text;
  static const Color muted = VxrTokens.textSub;
  static const Color bg = VxrTokens.bg;
  static const Color border = VxrTokens.border;

  @override
  State<RelistPromptScreen> createState() => _RelistPromptScreenState();
}

class _RelistPromptScreenState extends State<RelistPromptScreen> {
  bool _busy = false;

  Future<void> _relistAsIs() async {
    setState(() => _busy = true);
    await relistListing(widget.listingId);
    if (!mounted) return;
    setState(() => _busy = false);
    _showSuccessAndPop('Listing is now active and visible to tenants.');
  }

  void _editAndRelist() {
    // Navigate to manage-listing screen where the landlord can edit the listing
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageListingScreen(),
      ),
    );
  }

  void _keepArchived() {
    // Pop back to wherever we came from (TenantManagementScreen or similar)
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/home');
  }

  void _showSuccessAndPop(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: VxrTokens.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RelistPromptScreen.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: VxrTokens.brandGradient,
                  borderRadius: BorderRadius.circular(VxrTokens.radiusSheet),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'Contract Closed',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: RelistPromptScreen.ink),
              ),
              const SizedBox(height: 12),
              const Text(
                'The tenancy has ended and the contract is closed. What would you like to do with this listing?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: RelistPromptScreen.muted,
                    height: 1.5),
              ),
              const SizedBox(height: 40),
              // Option cards
              _optionCard(
                icon: Icons.rocket_launch_outlined,
                iconColor: RelistPromptScreen.brand,
                title: 'Relist As-Is',
                subtitle: 'Make the listing active immediately with no changes.',
                onTap: _busy ? null : _relistAsIs,
                loading: _busy,
              ),
              const SizedBox(height: 12),
              _optionCard(
                icon: Icons.edit_outlined,
                iconColor: RelistPromptScreen.coral,
                title: 'Edit and Relist',
                subtitle: 'Update the listing details before publishing again.',
                onTap: _busy ? null : _editAndRelist,
              ),
              const SizedBox(height: 12),
              _optionCard(
                icon: Icons.archive_outlined,
                iconColor: RelistPromptScreen.muted,
                title: 'Keep Archived',
                subtitle: 'Leave the listing archived for now.',
                onTap: _busy ? null : _keepArchived,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VxrTokens.surface,
            borderRadius: BorderRadius.circular(VxrTokens.radius),
            border: Border.all(color: RelistPromptScreen.border),
            boxShadow: VxrTokens.shadowSm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: iconColor),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: RelistPromptScreen.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: RelistPromptScreen.muted,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: RelistPromptScreen.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
