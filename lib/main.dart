import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state/notification_controller.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xc2R0Z3Z4eXJ2a29ybm5pZmVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyMzM5MDksImV4cCI6MjA5MTgwOTkwOX0.nKTYsvBh9I_64Aa25RluKye79eSIQwBpS8ExWuIiKRc",
    url: "https://mqsdtgvxyrvkornnifen.supabase.co",
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final NotificationController _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = NotificationController();
    final auth = Supabase.instance.client.auth;
    _notifications.bind(auth.currentUser?.id);
    auth.onAuthStateChange.listen((event) {
      _notifications.bind(event.session?.user.id);
    });
  }

  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationController>.value(
      value: _notifications,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: VxrTheme.lightThemeData(),
        builder: (context, child) => VxrTheme(child: child!),
        home: const LandingPage(),
      ),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      body: Column(
        children: [
          /// ── TOP GRADIENT SECTION ───────────────────────────────
          Expanded(
            flex: 58,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 36, 24, 36),
              decoration: const BoxDecoration(gradient: VxrTokens.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VxrLogoMark(onGradient: true, size: 18),
                  const Spacer(),
                  Text(
                    "Find Rental Homes\nMade Easy",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Discover your perfect home from thousands of rental listings.",
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.80),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// ── BOTTOM WHITE SECTION ───────────────────────────────
          Expanded(
            flex: 42,
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                  color: VxrTokens.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(VxrTokens.radiusSheet),
                    topRight: Radius.circular(VxrTokens.radiusSheet),
                  ),
                ),
                child: Column(
                  children: [
                    VxrPrimaryButton(
                      label: "Get Started",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    VxrSecondaryButton(
                      label: "Create Account",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "WHY CHOOSE US",
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: t.textMuted,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        FeatureIcon(icon: Icons.search, label: "Easy Search"),
                        FeatureIcon(
                          icon: Icons.verified_outlined,
                          label: "Verified Listings",
                        ),
                        FeatureIcon(
                          icon: Icons.lock_outline,
                          label: "Secure Payments",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const FeatureIcon({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: t.accent, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: t.textSub),
        ),
      ],
    );
  }
}
