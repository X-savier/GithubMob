import 'package:flutter/material.dart';
import 'package:vxr_flutter/auth/auth_service.dart';
import 'home_page.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await authService.signInWithEmailPassword(email, password);
      await authService.ensureProfile();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(
      String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white),
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF7043), Color(0xFFFF8A80)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 24),

                /// Logo Row
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/logo.jpg',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "ViewxRent",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 44),

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Sign in to continue",
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),

                const SizedBox(height: 36),

                /// EMAIL
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration:
                      _inputDecoration("Email", "Enter your email", Icons.email_outlined),
                ),

                const SizedBox(height: 18),

                /// PASSWORD
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _inputDecoration(
                          "Password", "Enter your password", Icons.lock_outline)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                /// SIGN IN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isLoading ? null : login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.deepOrange,
                            ),
                          )
                        : const Text(
                            "Sign In",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 28),

                /// OR Divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.5))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("OR",
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.white.withOpacity(0.5))),
                  ],
                ),

                const SizedBox(height: 24),

                /// Google Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text("Continue with Google",
                        style: TextStyle(fontSize: 15)),
                  ),
                ),

                const SizedBox(height: 36),

                /// SIGN UP LINK
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.white70),
                        children: [
                          TextSpan(
                            text: "Sign Up",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

