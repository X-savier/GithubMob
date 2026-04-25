import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      _hasListings = results[1] as bool;
      final user = _authService.currentUser;
      if (profile != null) {
        _fullName = profile['full_name'] ?? '';
        _email = profile['email'] ?? user?.email ?? '';
        _phone = profile['phone'] ?? '';
        _avatarUrl = profile['avatar_url'];
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
                leading: const Icon(Icons.visibility, color: Color(0xfff36c6c)),
                title: const Text('View Profile Photo'),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xfff36c6c)),
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
                  child: const Icon(Icons.broken_image,
                      size: 60, color: Colors.grey),
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
              leading: const Icon(Icons.camera_alt, color: Color(0xfff36c6c)),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xfff36c6c)),
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
            backgroundColor: Color(0xfff36c6c),
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
      MaterialPageRoute(
        builder: (_) => const ProfileInformationScreen(),
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
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
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
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
                backgroundColor: const Color(0xfff36c6c),
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
            backgroundColor: Color(0xfff36c6c),
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
              backgroundColor: const Color(0xfff36c6c),
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
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        backgroundColor: const Color(0xfff36c6c),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xfff36c6c)),
            )
          : RefreshIndicator(
              color: const Color(0xfff36c6c),
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    _buildMenuSection(),
                    const SizedBox(height: 15),
                    _buildHelpSection(),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleLogout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff36c6c),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xfff36c6c),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? Image.network(
                            _avatarUrl!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xfff36c6c),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person,
                                  size: 50, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person,
                                size: 50, color: Colors.grey),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xfff36c6c),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _fullName.isNotEmpty ? _fullName : 'No Name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openProfileInformation,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xfff36c6c),
                side: const BorderSide(color: Color(0xfff36c6c)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'Profile Information',
            subtitle: 'Update your personal details',
            onTap: _openProfileInformation,
          ),
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageListingScreen(),
                  ),
                );
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
                  MaterialPageRoute(
                    builder: (_) => const ApplicantsScreen(),
                  ),
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
          ],
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.report_outlined,
            title: 'Report Management',
            subtitle: 'View tenants reports',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportManagementScreen(),
                ),
              );
            },
          ),
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
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.assignment_outlined,
            title: 'My Applications',
            subtitle: 'Track approvals & contracts',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyApplicationsScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.payment_outlined,
            title: 'Payment Method',
            subtitle: 'Manage payment option',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentScreen(),
                ),
              );
            },
          ),
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
      margin: const EdgeInsets.symmetric(horizontal: 15),
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
            child: const Text('Close',
                style: TextStyle(color: Color(0xfff36c6c))),
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
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xfff36c6c).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xfff36c6c), size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildSimpleMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.grey[700], size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }
}