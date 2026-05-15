import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'manage_listing.dart';
import 'verification_screen.dart';

class HouseEnlistmentScreen extends StatelessWidget {
  const HouseEnlistmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              _buildStepsSection(),
              _buildBenefitsSection(),
              _buildRequirementsSection(),
              const SizedBox(height: 24),
              _buildStartButton(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: const BoxDecoration(
        gradient: VxrTokens.brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Free to List',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Icon(
            Icons.home_work_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'List Your Property',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start earning by renting out your property on ViewXRent. '
            'Reach thousands of tenants looking for their next home.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How It Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: VxrTokens.text,
            ),
          ),
          const SizedBox(height: 16),
          _buildStep(
            number: '1',
            title: 'Fill in Property Details',
            description: 'Provide your property information, '
                'location, amenities, and pricing.',
            icon: Icons.edit_note_rounded,
          ),
          _buildStepConnector(),
          _buildStep(
            number: '2',
            title: 'Upload Photos',
            description: 'Add photos of your property to attract '
                'potential tenants.',
            icon: Icons.camera_alt_rounded,
          ),
          _buildStepConnector(),
          _buildStep(
            number: '3',
            title: 'Publish & Get Tenants',
            description: 'Your listing goes live and tenants '
                'can apply to rent your property.',
            icon: Icons.rocket_launch_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: VxrTokens.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VxrTokens.text,
                      ),
                    ),
                  ),
                  Icon(icon, size: 20, color: VxrTokens.accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 17),
      child: Container(
        width: 2,
        height: 20,
        color: VxrTokens.accent.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why List on ViewXRent?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: VxrTokens.text,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenefitTile(
            Icons.people_rounded,
            'Reach More Tenants',
            'Thousands of active renters searching daily',
          ),
          const SizedBox(height: 12),
          _buildBenefitTile(
            Icons.security_rounded,
            'Verified Applicants',
            'Tenant applications with ID and background info',
          ),
          const SizedBox(height: 12),
          _buildBenefitTile(
            Icons.dashboard_customize_rounded,
            'Easy Management',
            'Manage listings, applications, and tenants in one place',
          ),
          const SizedBox(height: 12),
          _buildBenefitTile(
            Icons.money_off_rounded,
            'No Listing Fees',
            'List your property completely free of charge',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VxrTokens.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: VxrTokens.accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: VxrTokens.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFE0C0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded,
                  color: Color(0xFFE07820), size: 22),
              SizedBox(width: 8),
              Text(
                'What You\'ll Need',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: VxrTokens.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCheckItem('Property title and description'),
          _buildCheckItem('Complete address and location'),
          _buildCheckItem('Rental price and payment terms'),
          _buildCheckItem('Photos of the property'),
          _buildCheckItem('Amenities and house rules'),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1A9E4A), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VxrPrimaryButton(
        label: 'Start Listing Your Property',
        icon: Icons.add_home_rounded,
        onPressed: () async {
          final canCreate = await ensureVerifiedToCreateListing(context);
          if (!canCreate || !context.mounted) return;
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateListingScreen()),
          );
          if (result == true && context.mounted) {
            Navigator.pop(context, true);
          }
        },
      ),
    );
  }
}
