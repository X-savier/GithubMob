// ═══════════════════════════════════════════════════════════════════════════
// ViewxRent — Variation B "Dusk Edit" theme tokens
// ═══════════════════════════════════════════════════════════════════════════
// Drop this file in `lib/theme/vxr_theme.dart` and import it from main.dart.
// Wraps Flutter's ThemeData but exposes raw Variation B tokens via
// `VxrTheme.of(context)` for places where ThemeData semantics don't fit
// (gradients, soft accent fills, custom shadows, etc.)
//
//   import 'theme/vxr_theme.dart';
//
//   MaterialApp(
//     theme: VxrTheme.lightThemeData(),
//     ...
//   )
//
//   // Inside any widget:
//   final t = VxrTheme.of(context);
//   Container(color: t.surface, ...)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── RAW TOKENS ──────────────────────────────────────────────────────────────
class VxrTokens {
  // Brand gradient (used for primary CTAs, hero headers, logo mark)
  static const Color gradStart  = Color(0xFFFF7043);
  static const Color gradMid    = Color(0xFFFF5252);
  static const Color gradEnd    = Color(0xFFFF8A80);

  // Single accent (use anywhere a flat coral is needed)
  static const Color accent     = Color(0xFFFF7043);
  static const Color accentSoft = Color(0xFFFDEAE4); // tinted background

  // Light neutrals — Variation B's "warm" palette
  static const Color bg         = Color(0xFFF7F5F3); // app scaffold
  static const Color surface    = Color(0xFFFFFFFF); // cards / sheets
  static const Color surface2   = Color(0xFFF2F0EE); // input fills, chips
  static const Color border     = Color(0xFFEBEBEB); // hairlines

  // Text
  static const Color text       = Color(0xFF1A1310); // headlines, body
  static const Color textSub    = Color(0xFF7A6E68); // secondary
  static const Color textMuted  = Color(0xFFB0A8A2); // tertiary / icons

  // Semantic
  static const Color success    = Color(0xFF22C55E);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color danger     = Color(0xFFEF4444);

  // Geometry
  static const double radius      = 16.0;  // cards, buttons
  static const double radiusPill  = 50.0;  // chips, search bar
  static const double radiusSheet = 28.0;  // bottom sheets, top-rounded surfaces

  // Brand gradient as a reusable LinearGradient
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradStart, gradMid, gradEnd],
    stops: [0.0, 0.5, 1.0],
  );

  // Shadows
  static List<BoxShadow> shadowSm = const [
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1)),
  ];
  static List<BoxShadow> shadowMd = const [
    BoxShadow(color: Color(0x1AFF7043), blurRadius: 16, offset: Offset(0, 2)),
  ];
  static List<BoxShadow> shadowCta = const [
    BoxShadow(color: Color(0x44FF7043), blurRadius: 20, offset: Offset(0, 4)),
  ];
}

// ─── INHERITED THEME EXTENSION ───────────────────────────────────────────────
// Use `VxrTheme.of(context)` to read any token from any widget. ThemeData
// alone doesn't cover gradients / soft accents / paired shadows cleanly,
// so we pass it via InheritedWidget instead.

class VxrTheme extends InheritedWidget {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color textSub;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final LinearGradient grad;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowCta;

  const VxrTheme({
    super.key,
    required super.child,
    this.bg         = VxrTokens.bg,
    this.surface    = VxrTokens.surface,
    this.surface2   = VxrTokens.surface2,
    this.border     = VxrTokens.border,
    this.text       = VxrTokens.text,
    this.textSub    = VxrTokens.textSub,
    this.textMuted  = VxrTokens.textMuted,
    this.accent     = VxrTokens.accent,
    this.accentSoft = VxrTokens.accentSoft,
    this.grad       = VxrTokens.brandGradient,
    this.shadowSm   = const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))],
    this.shadowMd   = const [BoxShadow(color: Color(0x1AFF7043), blurRadius: 16, offset: Offset(0, 2))],
    this.shadowCta  = const [BoxShadow(color: Color(0x44FF7043), blurRadius: 20, offset: Offset(0, 4))],
  });

  static VxrTheme of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<VxrTheme>();
    return inherited ?? const VxrTheme(child: SizedBox.shrink());
  }

  @override
  bool updateShouldNotify(VxrTheme old) => false;

  // ─── ThemeData factory (for MaterialApp) ───────────────────────────────────
  static ThemeData lightThemeData() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: VxrTokens.text,
      displayColor: VxrTokens.text,
    );
    final headingTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: VxrTokens.bg,
      colorScheme: const ColorScheme.light(
        primary: VxrTokens.accent,
        onPrimary: Colors.white,
        secondary: VxrTokens.gradEnd,
        onSecondary: Colors.white,
        error: VxrTokens.danger,
        surface: VxrTokens.surface,
        onSurface: VxrTokens.text,
      ),

      // Type — DM Sans for body, Plus Jakarta Sans for display/headlines
      textTheme: textTheme.copyWith(
        displayLarge:    headingTheme.displayLarge?.copyWith(  fontWeight: FontWeight.w800, color: VxrTokens.text),
        displayMedium:   headingTheme.displayMedium?.copyWith( fontWeight: FontWeight.w800, color: VxrTokens.text),
        displaySmall:    headingTheme.displaySmall?.copyWith(  fontWeight: FontWeight.w800, color: VxrTokens.text),
        headlineLarge:   headingTheme.headlineLarge?.copyWith( fontWeight: FontWeight.w800, color: VxrTokens.text),
        headlineMedium:  headingTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: VxrTokens.text),
        headlineSmall:   headingTheme.headlineSmall?.copyWith( fontWeight: FontWeight.w700, color: VxrTokens.text),
        titleLarge:      headingTheme.titleLarge?.copyWith(    fontWeight: FontWeight.w700, color: VxrTokens.text),
        titleMedium:     headingTheme.titleMedium?.copyWith(   fontWeight: FontWeight.w700, color: VxrTokens.text),
        titleSmall:      headingTheme.titleSmall?.copyWith(    fontWeight: FontWeight.w600, color: VxrTokens.text),
        bodyLarge:       textTheme.bodyLarge?.copyWith(  color: VxrTokens.text),
        bodyMedium:      textTheme.bodyMedium?.copyWith( color: VxrTokens.textSub),
        bodySmall:       textTheme.bodySmall?.copyWith(  color: VxrTokens.textSub),
        labelLarge:      textTheme.labelLarge?.copyWith( color: VxrTokens.text,    fontWeight: FontWeight.w700),
        labelMedium:     textTheme.labelMedium?.copyWith(color: VxrTokens.textSub, fontWeight: FontWeight.w500),
        labelSmall:      textTheme.labelSmall?.copyWith( color: VxrTokens.textMuted),
      ),

      // AppBar — square-bottomed (no rounded corners — that's the Variation B move)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Cards — surface with soft shadow + hairline border
      cardTheme: CardThemeData(
        color: VxrTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VxrTokens.radius),
          side: const BorderSide(color: VxrTokens.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // Filled inputs (form fields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VxrTokens.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: VxrTokens.textSub, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        hintStyle:  const TextStyle(color: VxrTokens.textMuted, fontSize: 13),
        prefixIconColor: VxrTokens.textMuted,
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
      ),

      // ElevatedButton (gradient is applied per-button via VxrPrimaryButton;
      // this is the fallback flat-coral button)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VxrTokens.accent,
          foregroundColor: Colors.white,
          // Use Size(0, 50) instead of Size.fromHeight(50). The latter
          // expands to Size(double.infinity, 50), which forces every
          // ElevatedButton to demand infinite width and breaks layout
          // when placed inside a Row/Wrap or other non-full-width parent.
          // Full-width treatments should wrap the button in
          // SizedBox(width: double.infinity, ...) or Expanded explicitly.
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VxrTokens.radius)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),

      // OutlinedButton (the secondary "Create Account" / "360° Tour" treatment)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VxrTokens.accent,
          // Same fix as elevatedButtonTheme above — height-only minimum.
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VxrTokens.radius)),
          side: const BorderSide(color: VxrTokens.accent, width: 1.5),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // BottomNav — flat white with brand-coral active state (no rounded top)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: VxrTokens.surface,
        selectedItemColor: VxrTokens.accent,
        unselectedItemColor: VxrTokens.textMuted,
        selectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: VxrTokens.surface2,
        selectedColor: VxrTokens.accent,
        labelStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: VxrTokens.text),
        secondaryLabelStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VxrTokens.radiusPill)),
        side: const BorderSide(color: VxrTokens.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),

      dividerTheme: const DividerThemeData(color: VxrTokens.border, thickness: 1, space: 1),

      // Snackbar uses the brand coral (per design system spec)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFF36C6C),
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
