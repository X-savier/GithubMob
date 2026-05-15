import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'auth/auth_service.dart';
import 'verification_screen.dart';

const String _mapsApiKey = 'AIzaSyAyclCsU4xb9g0i2jCEPkaM4D5bACDwXbo';

class ProfileInformationScreen extends StatefulWidget {
  const ProfileInformationScreen({super.key});

  @override
  State<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState extends State<ProfileInformationScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  DateTime? _dateOfBirth;
  String _role = 'tenant';
  bool _isLandlord = false;
  bool _isVerified = false;
  // Tiered AI verification state. _verificationDecision is one of
  // 'approved' | 'manual_review' | 'rejected' | null (never submitted).
  String? _verificationDecision;
  String? _verificationRejectionReason;
  bool _isEmailVerified = false;
  bool _sendingEmailVerification = false;
  bool _sendingPhoneVerification = false;
  String? _avatarUrl;
  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _authService.fetchProfile();
      final user = _authService.currentUser;

      if (profile != null) {
        _nameCtrl.text = profile['full_name'] ?? '';
        _emailCtrl.text = profile['email'] ?? user?.email ?? '';
        _phoneCtrl.text = profile['phone'] ?? '';
        _addressCtrl.text = profile['address'] ?? '';
        _role = profile['role'] ?? 'tenant';
        _isLandlord = profile['is_landlord'] ?? false;
        _isVerified = profile['is_verified'] ?? false;
        _verificationDecision =
            profile['verification_decision']?.toString();
        _verificationRejectionReason =
            profile['verification_rejection_reason']?.toString();
        _avatarUrl = profile['avatar_url'];
        if (profile['date_of_birth'] != null) {
          _dateOfBirth = DateTime.tryParse(profile['date_of_birth']);
        }
      } else if (user != null) {
        final meta = user.userMetadata ?? {};
        _nameCtrl.text = meta['full_name'] ?? '';
        _emailCtrl.text = user.email ?? '';
        _phoneCtrl.text = meta['phone'] ?? '';
      }

      // Check email verification from Supabase auth
      if (user != null) {
        _isEmailVerified = user.emailConfirmedAt != null;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: VxrTokens.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  // ── Avatar picker (View / Change) ──
  Future<void> _showAvatarOptions() async {
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
            if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'remove'),
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
    } else if (action == 'remove') {
      _removeProfilePhoto();
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
              leading: const Icon(Icons.camera_alt, color: VxrTokens.accent),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: VxrTokens.accent),
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

    setState(() => _avatarUploading = true);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _avatarUploading = false);
  }

  Future<void> _removeProfilePhoto() async {
    setState(() => _avatarUploading = true);
    try {
      await _authService.updateProfile({'avatar_url': null});
      setState(() => _avatarUrl = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            backgroundColor: VxrTokens.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _avatarUploading = false);
  }

  // ── Map-based address picker ──
  Future<void> _pickAddressFromMap() async {
    LatLng? initialPos;

    // Try to get current device location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          initialPos = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}

    // Fallback to Dasmariñas center
    initialPos ??= const LatLng(14.3270, 120.9540);

    if (!mounted) return;

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapAddressPicker(initialPosition: initialPos!),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _addressCtrl.text = result;
      });
    }
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Allow formats like +63XXXXXXXXXX, 09XXXXXXXXX, etc.
    final phoneRegex = RegExp(r'^(\+?\d{1,3})?\d{10,12}$');
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _sendEmailVerification() async {
    setState(() => _sendingEmailVerification = true);
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Check your inbox.'),
            backgroundColor: VxrTokens.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _sendingEmailVerification = false);
  }

  Future<void> _sendPhoneVerification() async {
    final phone = _phoneCtrl.text.trim();
    if (_validatePhone(phone) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sendingPhoneVerification = true);
    try {
      await _authService.sendPhoneVerification(phone);
      if (mounted) {
        _showOtpDialog(phone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _sendingPhoneVerification = false);
  }

  Future<void> _showOtpDialog(String phone) async {
    final otpCtrl = TextEditingController();

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Phone'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the 6-digit code sent to $phone',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: VxrTokens.accent,
                    width: 2,
                  ),
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
            onPressed: () async {
              if (otpCtrl.text.length == 6) {
                try {
                  await _authService.verifyPhoneOtp(phone, otpCtrl.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Invalid code: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VxrTokens.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (verified == true && mounted) {
      setState(() => _isVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified successfully!'),
          backgroundColor: VxrTokens.accent,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_dateOfBirth != null) {
        updates['date_of_birth'] =
            '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';
      }

      await _authService.updateProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: VxrTokens.accent,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate data changed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: const Text('Profile Information'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile Image ──
                    _buildProfileImageSection(),
                    const SizedBox(height: 20),

                    // ── Account Status Card ──
                    _buildStatusCard(),
                    const SizedBox(height: 20),

                    // ── Personal Details Card ──
                    _buildSectionLabel('Personal Details'),
                    const SizedBox(height: 10),
                    _buildPersonalDetailsCard(),
                    const SizedBox(height: 20),

                    // ── Contact Information Card ──
                    _buildSectionLabel('Contact Information'),
                    const SizedBox(height: 10),
                    _buildContactCard(),
                    const SizedBox(height: 20),

                    // ── Address Card ──
                    _buildSectionLabel('Address'),
                    const SizedBox(height: 10),
                    _buildAddressCard(),
                    const SizedBox(height: 30),

                    // ── Save Button ──
                    VxrPrimaryButton(
                      label: 'Save Changes',
                      loading: _saving,
                      onPressed: _saveProfile,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _showAvatarOptions,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: VxrTokens.accent,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: _avatarUploading
                    ? Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VxrTokens.accent,
                          ),
                        ),
                      )
                    : _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? Image.network(
                            _avatarUrl!,
                            fit: BoxFit.cover,
                            width: 110,
                            height: 110,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: VxrTokens.accent,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person,
                                  size: 55, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person,
                                size: 55, color: Colors.grey),
                          ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: VxrTokens.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xff333333),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    // Tiered visual state: verified (green) > manual_review (yellow) >
    // rejected (coral) > unsubmitted (orange).
    final isManualReview =
        !_isVerified && _verificationDecision == 'manual_review';
    final isRejected =
        !_isVerified && _verificationDecision == 'rejected';

    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;
    String? ctaLabel;
    if (_isVerified) {
      icon = Icons.verified_user;
      color = Colors.green;
      title = 'Verified Account';
      subtitle = 'Your identity has been verified';
    } else if (isManualReview) {
      icon = Icons.hourglass_top_rounded;
      color = const Color(0xffe6a700);
      title = 'Pending admin review';
      subtitle =
          'Our AI flagged your submission for manual review. We will '
          'notify you once an admin makes a decision.';
    } else if (isRejected) {
      icon = Icons.error_outline;
      color = VxrTokens.accent;
      title = 'Verification failed';
      subtitle = _verificationRejectionReason ??
          'Your last submission could not be verified.';
      ctaLabel = 'Retry verification';
    } else {
      icon = Icons.shield_outlined;
      color = VxrTokens.warning;
      title = 'Unverified Account';
      subtitle =
          'Verify your identity to list properties or apply for rentals.';
      ctaLabel = 'Verify now';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Builder(builder: (_) {
                // Capability flag wins over role for the visual badge.
                final isLandlord = _isLandlord || _role == 'landlord';
                final isAdmin = _role == 'admin';
                final label = isLandlord
                    ? 'Landlord'
                    : isAdmin
                        ? 'Admin'
                        : 'Tenant';
                final c = isLandlord
                    ? VxrTokens.accent
                    : isAdmin
                        ? Colors.purple
                        : Colors.blue;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c,
                    ),
                  ),
                );
              }),
            ],
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openVerification,
                icon: const Icon(Icons.verified_user_outlined,
                    color: Colors.white, size: 18),
                label: Text(ctaLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VxrTokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openVerification() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
    );
    if (mounted) await _loadProfile();
  }

  Widget _buildPersonalDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Full Name
          TextFormField(
            controller: _nameCtrl,
            validator: _validateFullName,
            decoration: _inputDecoration(
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 16),

          // Date of Birth
          GestureDetector(
            onTap: _pickDateOfBirth,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: _inputDecoration(
                  label: 'Date of Birth',
                  icon: Icons.cake_outlined,
                  suffixIcon: Icons.calendar_today,
                ),
                controller: TextEditingController(
                  text: _dateOfBirth != null
                      ? '${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.year}'
                      : '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Email with verification
          TextFormField(
            controller: _emailCtrl,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              label: 'Email',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 8),
          _buildVerificationRow(
            isVerified: _isEmailVerified,
            label: 'Email',
            onVerify: _sendingEmailVerification ? null : _sendEmailVerification,
            isSending: _sendingEmailVerification,
          ),
          const SizedBox(height: 16),

          // Phone with verification
          TextFormField(
            controller: _phoneCtrl,
            validator: _validatePhone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\s()]')),
            ],
            decoration: _inputDecoration(
              label: 'Phone Number',
              icon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 8),
          _buildVerificationRow(
            isVerified: _isVerified,
            label: 'Phone',
            onVerify: _sendingPhoneVerification ? null : _sendPhoneVerification,
            isSending: _sendingPhoneVerification,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRow({
    required bool isVerified,
    required String label,
    required VoidCallback? onVerify,
    required bool isSending,
  }) {
    return Row(
      children: [
        Icon(
          isVerified ? Icons.check_circle : Icons.error_outline,
          size: 16,
          color: isVerified ? VxrTokens.success : VxrTokens.warning,
        ),
        const SizedBox(width: 6),
        Text(
          isVerified ? '$label verified' : '$label not verified',
          style: TextStyle(
            fontSize: 12,
            color: isVerified ? VxrTokens.success : VxrTokens.warning,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (!isVerified)
          SizedBox(
            height: 28,
            child: TextButton(
              onPressed: onVerify,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: VxrTokens.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: VxrTokens.accent, width: 1),
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VxrTokens.accent,
                      ),
                    )
                  : Text(
                      'Verify $label',
                      style: const TextStyle(fontSize: 11),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          TextFormField(
            controller: _addressCtrl,
            maxLines: null,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Full Address',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Icon(Icons.location_on_outlined,
                    color: VxrTokens.accent, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
              ),
              filled: true,
              fillColor: VxrTokens.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: VxrTokens.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickAddressFromMap,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const Text('Pick from Map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: VxrTokens.accent,
                side: const BorderSide(color: VxrTokens.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: VxrTokens.accent, size: 22),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: Colors.grey[500], size: 20)
          : null,
      filled: true,
      fillColor: VxrTokens.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        borderSide: const BorderSide(color: VxrTokens.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        borderSide: const BorderSide(color: VxrTokens.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        borderSide: const BorderSide(color: VxrTokens.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        borderSide: const BorderSide(color: VxrTokens.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        borderSide: const BorderSide(color: VxrTokens.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Map Address Picker — full-screen Google Map for picking address
// ══════════════════════════════════════════════════════════════
class _MapAddressPicker extends StatefulWidget {
  final LatLng initialPosition;

  const _MapAddressPicker({required this.initialPosition});

  @override
  State<_MapAddressPicker> createState() => _MapAddressPickerState();
}

class _MapAddressPickerState extends State<_MapAddressPicker> {
  late LatLng _selectedPosition;
  String _address = 'Move the map to pick a location';
  bool _loadingAddress = false;
  GoogleMapController? _mapController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _reverseGeocode(_selectedPosition);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onCameraIdle() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocode(_selectedPosition);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${pos.latitude},${pos.longitude}'
        '&key=$_mapsApiKey',
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          _address = data['results'][0]['formatted_address'] ?? 'Unknown';
        } else {
          _address = 'No address found for this location';
        }
      } else {
        _address = 'Could not determine address';
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      _address = 'Could not determine address';
    }
    if (mounted) setState(() => _loadingAddress = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: VxrTokens.accent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pick Address',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              _selectedPosition = position.target;
            },
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Center pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: VxrTokens.accent,
              ),
            ),
          ),
          // Address bar at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: VxrTokens.accent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _loadingAddress
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VxrTokens.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Getting address...',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ],
                              )
                            : Text(
                                _address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadingAddress
                          ? null
                          : () => Navigator.pop(context, _address),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VxrTokens.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Confirm Address',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
