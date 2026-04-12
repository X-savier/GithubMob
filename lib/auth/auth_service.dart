import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {

  final SupabaseClient _supabase = Supabase.instance.client;

  // Sin in with email and passowrd
  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
    );    
    }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword(
      String email, String password) async{
        return await _supabase.auth.signUp(
          email: email,
          password: password,
        );
      }  

  //Sign out
  Future<void> signOut() async{
    await _supabase.auth.signOut();
  }

}