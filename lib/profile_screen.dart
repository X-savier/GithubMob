import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'auth/auth_service.dart';
import 'manage_listing.dart';
import 'tenantmanagement_screen.dart';
import 'report_management_screen.dart';
import 'payment_screen.dart';
import 'enlistment_application.dart';
import 'in_stay_dashboard_screen.dart';
import 'landlord_contracts_screen.dart';
import 'login_screen.dart';
import 'my_applications_screen.dart';
import 'profile_information_screen.dart';
import 'house_enlistment_screen.dart';
import 'property_data.dart';
import 'verification_screen.dart';
import 'search_field.dart';
import 'conversations_screen.dart';
import 'favorites_screen.dart';
import 'services/profile_service.dart' as profile_api;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String? _avatarUrl;
  bool _hasListings = false;
  bool _hasRental = false;
  String? _role;
  bool _isVerified = false;
  // 'approved' | 'manual_review' | 'rejected' | null (never submitted).
  String? _verificationDecision;

  bool get _isAdmin => _role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _authService.fetchProfile(),
        hasUserListings(),
        getLatestVerification(),
        profile_api.hasActiveContract(),
        profile_api.getProfileRole(),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      _hasListings = results[1] as bool;
      final latestVerif = results[2] as Map<String, dynamic>?;
      _hasRental = results[3] as bool;
      _role = results[4] as String?;
      final user = _authService.currentUser;
      if (profile != null) {
        _fullName = profile['full_name'] ?? '';
        _email = profile['email'] ?? user?.email ?? '';
        _phone = profile['phone'] ?? '';
        _avatarUrl = profile['avatar_url'];
        _isVerified = profile['is_verified'] == true;
        // Source of truth for the badge is the latest `verifications` row
        // — the cached `profiles.verification_decision` can drift if the
        // row was deleted manually or if an admin only flipped `is_verified`
        // without clearing the cached decision.
        _verificationDecision = latestVerif?['decision']?.toString();
      } else if (user != null) {
        final meta = user.userMetadata ?? {};
        _fullName = meta['full_name'] ?? '';
        _email = user.email ?? '';
        _phone = meta['phone'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Avatar options (View / Change) ──
  Future<void> _pickAvatar() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.visibility, color: VxrTokens.accent),
                title: const Text('View Profile Photo'),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: VxrTokens.accent),
              title: const Text('Change Profile Photo'),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    if (action == 'view') {
      _viewProfilePhoto();
    } else if (action == 'change') {
      _changeProfilePhoto();
    }
  }

  void _viewProfilePhoto() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _avatarUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.broken_image,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: VxrTokens.accent),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: VxrTokens.accent),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 512);
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      final url = await _authService.uploadAvatar(picked.path);
      setState(() => _avatarUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: VxrTokens.accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Navigate to Profile Information screen ──
  Future<void> _openProfileInformation() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileInformationScreen()),
    );
    if (changed == true) {
      _loadProfile(); // Reload data if user saved changes
    }
  }

  // ── Change password dialog ──
  Future<void> _showChangePasswordDialog() async {
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: VxrTokens.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final newPass = newPassCtrl.text;
    final confirmPass = confirmCtrl.text;

    if (newPass.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (newPass != confirmPass) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.updatePassword(newPass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: VxrTokens.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Logout ──
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VxrTokens.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : RefreshIndicator(
              color: VxrTokens.accent,
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 16),
                    _buildMenuSection(),
                    const SizedBox(height: 14),
                    _buildHelpSection(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: VxrPrimaryButton(
                        label: 'Logout',
                        icon: Icons.logout,
                        onPressed: _handleLogout,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: VxrBottomNav(
        activeIndex: 3,
        onTap: (index) {
          if (index == 3) return;
          if (index == 0) {
            Navigator.popUntil(context, (r) => r.isFirst);
          } else if (index == 1) {
            Navigator.popUntil(context, (r) => r.isFirst);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchFieldScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ConversationsScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileHeader() {
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: VxrTokens.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 12,
        18,
        24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Profile',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: hasAvatar
                    ? Image.network(
                        _avatarUrl!,
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person,
                          size: 32,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person, size: 32, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _fullName.isNotEmpty ? _fullName : 'No Name',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (_email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _email,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _openProfileInformation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Text(
                'Edit Profile',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Verify Identity menu item with status badge ──
  bool get _isVerificationPending =>
      _verificationDecision == 'manual_review' ||
      _verificationDecision == 'pending';

  Future<void> _openVerification() async {
    if (_isVerified) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _isVerificationPending
            ? const VerificationPendingScreen()
            : const VerificationScreen(),
      ),
    );
    if (mounted) _loadProfile();
  }

  Widget _buildVerificationMenuItem() {
    // Tiered subtitle + colored chip on the right.
    final String subtitle;
    final String chipLabel;
    final Color chipColor;
    if (_isVerified) {
      subtitle = 'Identity verified';
      chipLabel = 'Verified';
      chipColor = VxrTokens.success;
    } else if (_isVerificationPending) {
      subtitle = 'Awaiting admin review';
      chipLabel = 'Pending';
      chipColor = VxrTokens.warning;
    } else if (_verificationDecision == 'rejected') {
      subtitle = 'Last submission rejected — try again';
      chipLabel = 'Failed';
      chipColor = VxrTokens.danger;
    } else {
      subtitle = 'Verify your ID to list or apply';
      chipLabel = 'Required';
      chipColor = VxrTokens.warning;
    }
    final disabled = _isVerified;
    return _MenuRow(
      icon: Icons.verified_user_outlined,
      title: 'Verify Identity',
      subtitle: subtitle,
      enabled: !disabled,
      onTap: _openVerification,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
        ),
        child: Text(
          chipLabel,
          style: GoogleFonts.dmSans(
            color: chipColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Open house enlistment screen ──
  Future<void> _openEnlistment() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const HouseEnlistmentScreen()),
    );
    if (result == true) {
      _loadProfile(); // Refresh to show landlord buttons
    }
  }

  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'Profile Information',
            subtitle: 'Update your personal details',
            onTap: _openProfileInformation,
          ),
          _buildDivider(),
          _buildVerificationMenuItem(),
          if (!_hasListings) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.add_home_rounded,
              title: 'Enlist Your Property',
              subtitle: 'Start listing your rental unit',
              onTap: _openEnlistment,
            ),
          ],
          if (_hasListings) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.list_alt_outlined,
              title: 'Manage Listings',
              subtitle: 'Manage your rental units',
              onTap: () async {
                debugPrint('ProfileScreen Manage Listings tapped');
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageListingScreen(),
                  ),
                );
                debugPrint('ProfileScreen Manage Listings returned');
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.assignment_outlined,
              title: 'Enlistment Applications',
              subtitle: 'View applicants',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApplicantsScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.people_outline,
              title: 'Tenant Management',
              subtitle: 'View Unit you rent',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantManagementScreen(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.description_outlined,
              title: 'Tenant Contracts',
              subtitle: 'View & sign approved contracts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LandlordContractsScreen(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.report_outlined,
              title: 'Report Management',
              subtitle: 'View tenant reports',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportManagementScreen(),
                  ),
                );
              },
            ),
          ],
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.favorite_border,
            title: 'Wishlists',
            subtitle: 'Saved listings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          if (_hasRental || _hasListings) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.home_outlined,
              title: 'My Rental',
              subtitle: 'Active stay & next payment',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InStayDashboardScreen(),
                  ),
                );
              },
            ),
          ],
          if (!_hasListings || _hasRental) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.assignment_outlined,
              title: 'My Applications',
              subtitle: 'Track approvals & contracts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MyApplicationsScreen()),
                );
              },
            ),
          ],
          if (_hasRental || _hasListings) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.payment_outlined,
              title: 'Payment Method',
              subtitle: 'Manage payment option',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentScreen()),
                );
              },
            ),
          ],
          if (_isAdmin) ...[
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin Dashboard',
              subtitle: 'Manage VXR platform',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin dashboard is web-only for now.'),
                  ),
                );
              },
            ),
          ],
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.security_outlined,
            title: 'Security',
            subtitle: 'Change your password',
            onTap: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: VxrTokens.surface,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        border: Border.all(color: VxrTokens.border),
        boxShadow: VxrTokens.shadowSm,
      ),
      child: Column(
        children: [
          _buildSimpleMenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              _showInfoDialog(
                'Help & Support',
                'For any issues or inquiries, please contact us at support@viewxrent.com.',
              );
            },
          ),
          _buildDivider(),
          _buildSimpleMenuItem(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {
              _showInfoDialog(
                'Terms of Service',
                'By using ViewXRent, you agree to our terms of service. '
                    'All rental listings must be accurate and legitimate. '
                    'Users are responsible for verifying property details before signing agreements.',
              );
            },
          ),
          _buildDivider(),
          _buildSimpleMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              _showInfoDialog(
                'Privacy Policy',
                'ViewXRent respects your privacy. We collect only the data necessary '
                    'to provide our services. Your personal information is securely stored '
                    'and never shared with third parties without your consent.',
              );
            },
          ),
          _buildDivider(),
          _buildSimpleMenuItem(
            icon: Icons.info_outline,
            title: 'About ViewXRent',
            onTap: () {
              _showInfoDialog(
                'About ViewXRent',
                'ViewXRent (VXR) is a rental property platform that connects '
                    'tenants with landlords. Find your perfect home easily.\n\nVersion 1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: VxrTokens.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _MenuRow(icon: icon, title: title, subtitle: subtitle, onTap: onTap);
  }

  Widget _buildSimpleMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return _MenuRow(icon: icon, title: title, onTap: onTap);
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 62, color: VxrTokens.border);
  }
}

/// A single menu row in the Variation B profile menu card — 36×36 accentSoft
/// icon tile, two-line text, trailing chevron.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? trailing;

  const _MenuRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    final iconColor = enabled ? t.accent : t.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled ? t.accentSoft : t.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: enabled ? t.text : t.textMuted,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: t.textSub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right, color: t.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
