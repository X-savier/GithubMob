import 'package:flutter/material.dart';
import 'package:vxr_flutter/auth/auth_service.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool isChecked = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final authService = AuthService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void signUp() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords don't match")),
      );
      return;
    }

    if (!isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please agree to the Terms of Service")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await authService.signUpWithEmailPassword(
        email,
        password,
        fullName: fullName,
        phone: phone,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Account created! Please check your email to verify.")),
        );
        Navigator.pop(context);
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
      contentPadding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  InputDecoration _passwordDecoration(
      String label, String hint, bool obscure, VoidCallback toggle) {
    return _inputDecoration(label, hint, Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.white70,
        ),
        onPressed: toggle,
      ),
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

                const SizedBox(height: 16),

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

                const SizedBox(height: 32),

                const Text(
                  "Create Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Sign up to get started",
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),

                const SizedBox(height: 30),

                /// FULL NAME
                TextField(
                  controller: _fullNameController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                      "Full Name", "Enter your full name", Icons.person_outline),
                ),

                const SizedBox(height: 16),

                /// EMAIL
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _inputDecoration(
                      "Email", "Enter your email", Icons.email_outlined),
                ),

                const SizedBox(height: 16),

                /// PHONE NUMBER
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _inputDecoration(
                      "Phone Number", "Enter your phone number", Icons.phone_outlined),
                ),

                const SizedBox(height: 16),

                /// PASSWORD
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _passwordDecoration(
                    "Password",
                    "Enter your password",
                    _obscurePassword,
                    () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 16),

                /// CONFIRM PASSWORD
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: _passwordDecoration(
                    "Confirm Password",
                    "Confirm your password",
                    _obscureConfirmPassword,
                    () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),

                const SizedBox(height: 12),

                /// TERMS CHECKBOX
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setState(() => isChecked = value!);
                        },
                        activeColor: Colors.white,
                        checkColor: Colors.deepOrange,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "I agree to the Terms of Service and Privacy Policy",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// CREATE BUTTON
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
                    onPressed: _isLoading ? null : signUp,
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
                            "Create Account",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                /// SIGN IN LINK
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(color: Colors.white70),
                        children: [
                          TextSpan(
                            text: "Sign In",
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