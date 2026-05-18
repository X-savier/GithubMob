// ═══════════════════════════════════════════════════════════════════════════
// ViewxRent — Variation B "Dusk Edit" widgets
// ═══════════════════════════════════════════════════════════════════════════
// Drop in `lib/theme/vxr_widgets.dart` and import wherever you need
// the Variation B-styled chrome.
//
// Provides:
//   - VxrAppBar      — square-bottomed gradient header
//   - VxrSurfaceAppBar — square-bottomed solid surface header (Search screen)
//   - VxrSearchBar   — pill input with filter trailing icon
//   - VxrChip        — selectable pill chip
//   - VxrPropertyCard — horizontal image-left content-right card
//   - VxrPrimaryButton — gradient CTA with shadow
//   - VxrSecondaryButton — outlined coral button
//   - VxrInputField  — labeled filled input matching Variation B spec
//   - VxrBottomNav   — bottom nav with gradient active pip + label
//   - VxrSection     — section header w/ optional "see all"
//   - VxrLogoMark    — gradient-filled house logo with wordmark
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vxr_theme.dart';

// ─── APP BARS ─────────────────────────────────────────────────────────────────

/// Square-bottomed gradient header (replaces the rounded-bottom variant).
/// `bottom` slot lets you slide a SearchBar / chips into the header.
class VxrAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? bottom;
  final double bottomHeight;

  const VxrAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.bottomHeight = 60,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(120 + (subtitle != null ? 16 : 0) + (bottom != null ? bottomHeight : 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: VxrTokens.brandGradient),
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ?leading,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: leading != null ? 8 : 0),
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                    ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.75)),
            ),
          ],
          if (bottom != null) ...[
            const SizedBox(height: 12),
            bottom!,
          ],
        ],
      ),
    );
  }
}

/// Solid-surface square-bottomed header — used on Search screen in Var B
/// (the gradient is reserved for the Home / Profile heroes).
class VxrSurfaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final double bottomHeight;

  const VxrSurfaceAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.bottomHeight = 60,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(110 + (subtitle != null ? 16 : 0) + (bottom != null ? bottomHeight : 0));

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Container(
      color: t.surface,
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w800, color: t.text,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: GoogleFonts.dmSans(fontSize: 11, color: t.textSub)),
          ],
          if (bottom != null) ...[
            const SizedBox(height: 12),
            bottom!,
          ],
        ],
      ),
    );
  }
}

// ─── SEARCH BAR ───────────────────────────────────────────────────────────────

class VxrSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final bool onGradient; // true = transparent white-ish, false = surface
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;

  const VxrSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search location or property...',
    this.onGradient = false,
    this.onFilterTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    final fill = onGradient ? Colors.white.withOpacity(0.15) : Colors.white;
    final border = onGradient ? Colors.white.withOpacity(0.25) : t.border;
    final iconColor = onGradient ? Colors.white.withOpacity(0.7) : t.textMuted;
    final textColor = onGradient ? Colors.white : t.text;

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
        border: Border.all(color: border),
        boxShadow: onGradient ? null : VxrTokens.shadowSm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.dmSans(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: iconColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: onGradient ? Colors.white.withOpacity(0.15) : t.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tune, size: 16, color: onGradient ? Colors.white : t.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CHIP ─────────────────────────────────────────────────────────────────────

class VxrChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const VxrChip({super.key, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.accent : t.surface2,
          borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
          border: Border.all(color: active ? t.accent : t.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : t.text,
          ),
        ),
      ),
    );
  }
}

// ─── PROPERTY CARD — HORIZONTAL ───────────────────────────────────────────────

class VxrPropertyCard extends StatelessWidget {
  final String image;       // network or asset path
  final bool imageIsAsset;
  final String title;
  final String location;
  final String price;       // already formatted, e.g. "₱8,500/mo"
  final int beds;
  final String baths;
  final String area;        // "32 m²"
  final String? label;      // "Popular" / "New" / "Featured"
  final bool favorited;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const VxrPropertyCard({
    super.key,
    required this.image,
    required this.title,
    required this.location,
    required this.price,
    required this.beds,
    required this.baths,
    required this.area,
    this.label,
    this.imageIsAsset = false,
    this.favorited = false,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(VxrTokens.radius),
          border: Border.all(color: t.border),
          boxShadow: VxrTokens.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Image
            SizedBox(
              width: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageIsAsset
                        ? Image.asset(image, fit: BoxFit.cover, errorBuilder: _broken)
                        : Image.network(image, fit: BoxFit.cover, errorBuilder: _broken),
                  ),
                  if (label != null)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
                        ),
                        child: Text(
                          label!,
                          style: GoogleFonts.dmSans(
                            fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700, color: t.text, height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.location_on, size: 10, color: t.textSub),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 10, color: t.textSub),
                            ),
                          ),
                        ]),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          price,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w800, color: t.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          _statPill(t, Icons.bed, '$beds'),
                          const SizedBox(width: 4),
                          _statPill(t, Icons.bathtub_outlined, baths),
                          const SizedBox(width: 4),
                          _statPill(t, Icons.square_foot, area),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Favorite
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
              child: GestureDetector(
                onTap: onFavoriteTap,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: t.accentSoft, shape: BoxShape.circle,
                  ),
                  child: Icon(
                    favorited ? Icons.favorite : Icons.favorite_border,
                    size: 14, color: t.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(VxrTheme t, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: t.textSub),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: t.textSub)),
      ]),
    );
  }

  Widget _broken(BuildContext c, Object e, StackTrace? s) =>
      Container(color: const Color(0xFFE5E0DD));
}

// ─── BUTTONS ──────────────────────────────────────────────────────────────────

class VxrPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  const VxrPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        gradient: VxrTokens.brandGradient,
        borderRadius: BorderRadius.circular(VxrTokens.radius),
        boxShadow: VxrTokens.shadowCta,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(VxrTokens.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class VxrSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const VxrSecondaryButton({super.key, required this.label, this.onPressed, this.icon});
  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: t.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VxrTokens.radius)),
          side: BorderSide(color: t.accent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: t.accent),
              const SizedBox(width: 8),
            ],
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── INPUT ────────────────────────────────────────────────────────────────────

class VxrInputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  const VxrInputField({
    super.key,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w600, color: t.textSub, letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.dmSans(fontSize: 13, color: t.text),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ─── BOTTOM NAV ───────────────────────────────────────────────────────────────

class VxrBottomNavItem {
  final IconData icon;
  final IconData iconActive;
  final String label;
  const VxrBottomNavItem(this.icon, this.iconActive, this.label);
}

class VxrBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  static const items = [
    VxrBottomNavItem(Icons.home_outlined,    Icons.home,    'Home'),
    VxrBottomNavItem(Icons.search_outlined,  Icons.search,  'Search'),
    VxrBottomNavItem(Icons.message_outlined, Icons.message, 'Messages'),
    VxrBottomNavItem(Icons.person_outline,   Icons.person,  'Profile'),
  ];
  const VxrBottomNav({super.key, required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      padding: EdgeInsets.fromLTRB(0, 8, 0, MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: List.generate(items.length, (i) {
          final isActive = i == activeIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      gradient: isActive ? VxrTokens.brandGradient : null,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Icon(
                    isActive ? items[i].iconActive : items[i].icon,
                    color: isActive ? t.accent : t.textMuted, size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].label,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? t.accent : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── MISC ─────────────────────────────────────────────────────────────────────

class VxrSection extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const VxrSection({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: t.text,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: t.accent),
            ),
          ),
      ]),
    );
  }
}

class VxrLogoMark extends StatelessWidget {
  final double size;
  final bool onGradient;
  const VxrLogoMark({super.key, this.size = 16, this.onGradient = false});

  @override
  Widget build(BuildContext context) {
    final t = VxrTheme.of(context);
    final boxSize = size * 2.2;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: boxSize, height: boxSize,
        decoration: BoxDecoration(
          color: onGradient ? Colors.white.withOpacity(0.9) : null,
          gradient: onGradient ? null : VxrTokens.brandGradient,
          borderRadius: BorderRadius.circular(VxrTokens.radius * 0.6),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Icon(
          Icons.home_rounded,
          size: boxSize * 0.6,
          color: onGradient ? VxrTokens.gradStart : Colors.white,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        'ViewxRent',
        style: GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: FontWeight.w800,
          color: onGradient ? Colors.white : t.text,
          letterSpacing: -0.3,
        ),
      ),
    ]);
  }
}
