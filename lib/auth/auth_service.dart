import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password — metadata stored in auth.users
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password, {
    required String fullName,
    required String phone,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
      },
    );
  }

  // Ensure a profiles row exists for the current user (call after login)
  Future<void> ensureProfile() async {
    final user = currentUser;
    if (user == null) return;

    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      final meta = user.userMetadata ?? {};
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': meta['full_name'] ?? '',
        'email': user.email ?? '',
        'phone': meta['phone'] ?? '',
        'role': 'tenant',
        'is_landlord': false,
      });
    }
  }

  // Fetch the current user's profile from the `profiles` table
  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  // Update profile fields (full_name, phone, etc.)
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) return;
    await _supabase.from('profiles').update(updates).eq('id', user.id);
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  // Upload avatar and return the public URL
  Future<String> uploadAvatar(String filePath) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final ext = filePath.split('.').last;
    final storagePath = 'avatars/${user.id}.$ext';

    // 1. Upload to storage
    await _supabase.storage.from('listing-images').uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    // 2. Get public URL with cache-busting timestamp
    final baseUrl =
        _supabase.storage.from('listing-images').getPublicUrl(storagePath);
    final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    // 3. Save to profiles table via upsert to ensure it works
    await _supabase.from('profiles').upsert({
      'id': user.id,
      'avatar_url': url,
    });

    // 4. Verify the save
    final check = await _supabase
        .from('profiles')
        .select('avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    if (check == null || check['avatar_url'] == null) {
      throw Exception('avatar_url was not saved. Ensure the column exists in the profiles table.');
    }

    return url;
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Send email verification (resend confirmation email)
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user with email');
    }
    await _supabase.auth.resend(
      type: OtpType.email,
      email: user.email!,
    );
  }

  // Send phone verification OTP
  Future<void> sendPhoneVerification(String phone) async {
    await _supabase.auth.signInWithOtp(phone: phone);
  }

  // Verify phone OTP code
  Future<void> verifyPhoneOtp(String phone, String token) async {
    await _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    // Update is_verified in the profiles table
    final user = currentUser;
    if (user != null) {
      await _supabase
          .from('profiles')
          .update({'is_verified': true})
          .eq('id', user.id);
    }
  }
}