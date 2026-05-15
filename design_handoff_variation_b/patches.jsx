// Patch guide data — every screen in lib/, with the Variation B changes to apply.
// Each entry has {file, changes: [{label, before, after, note?}]}

const PATCHES = [
  {
    file: 'lib/main.dart',
    summary: 'Wire up the new theme + VxrTheme inherited widget',
    changes: [
      {
        label: 'Import + wrap MaterialApp',
        before: `import 'package:flutter/material.dart';
// ...

return const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: LandingPage(),
);`,
        after: `import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
// ...

return MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: VxrTheme.lightThemeData(),
  builder: (context, child) => VxrTheme(child: child!),
  home: const LandingPage(),
);`,
        note: 'The builder wraps every route with the InheritedWidget so VxrTheme.of(context) works anywhere.',
      },
      {
        label: 'Update LandingPage hero gradient',
        before: `gradient: LinearGradient(
  colors: [Color(0xFFFF7043), Color(0xFFFF8A80)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),`,
        after: `gradient: VxrTokens.brandGradient,`,
      },
      {
        label: 'Replace the Get Started / Sign Up buttons',
        before: `ElevatedButton(
  onPressed: () { /* nav */ },
  child: const Text('Get Started'),
)`,
        after: `VxrPrimaryButton(label: 'Get Started', onPressed: () { /* nav */ })
// secondary becomes:
VxrSecondaryButton(label: 'Create Account', onPressed: () { /* nav */ })`,
      },
    ],
  },
  {
    file: 'lib/login_screen.dart',
    summary: 'Var B: white card slides up from bottom of gradient',
    changes: [
      {
        label: 'Scaffold body — split into gradient hero + surface card',
        before: `Scaffold(
  body: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFF8A80)]),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // logo + title
        TextField(decoration: _inputDecoration('Email', ...)),
        TextField(decoration: _inputDecoration('Password', ...)),
        ElevatedButton(onPressed: login, child: Text('Sign In')),
      ]),
    ),
  ),
)`,
        after: `Scaffold(
  body: Container(
    decoration: const BoxDecoration(gradient: VxrTokens.brandGradient),
    child: Column(children: [
      // ── Hero (gradient) ────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const VxrLogoMark(onGradient: true, size: 16),
          const SizedBox(height: 28),
          Text('Welcome Back',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Sign in to continue',
            style: GoogleFonts.dmSans(
              fontSize: 13, color: Colors.white.withOpacity(0.75))),
        ]),
      ),
      // ── White card slides up ────────
      Expanded(
        child: Container(
          decoration: const BoxDecoration(
            color: VxrTokens.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(VxrTokens.radiusSheet),
              topRight: Radius.circular(VxrTokens.radiusSheet),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: SingleChildScrollView(child: Column(children: [
            VxrInputField(
              label: 'Email Address', hint: 'Enter your email',
              prefixIcon: Icons.mail_outline, controller: _emailController),
            const SizedBox(height: 14),
            VxrInputField(
              label: 'Password', hint: 'Enter your password',
              prefixIcon: Icons.lock_outline, obscureText: _obscurePassword,
              controller: _passwordController),
            const SizedBox(height: 16),
            VxrPrimaryButton(label: 'Sign In', onPressed: login, loading: _isLoading),
          ])),
        ),
      ),
    ]),
  ),
)`,
        note: 'Drop the old `_inputDecoration()` helper — VxrInputField replaces it.',
      },
    ],
  },
  {
    file: 'lib/signup_screen.dart',
    summary: 'Same hero+card pattern as login_screen.dart',
    changes: [
      {
        label: 'Apply the same Var B layout as login',
        before: `// Same gradient-bg + glass inputs as the old login`,
        after: `// Mirror login_screen.dart: gradient hero (logo + 'Create Account' headline)
// then a white sheet with VxrInputField for full name / email / phone / password
// and a VxrPrimaryButton('Sign Up'). VxrSecondaryButton for 'Continue with Google'.`,
      },
    ],
  },
  {
    file: 'lib/home_page.dart',
    summary: 'Square-bottom gradient header + horizontal property cards',
    changes: [
      {
        label: 'Replace AppBar with VxrAppBar',
        before: `AppBar(
  backgroundColor: Color(0xFFF36C6C),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
  ),
  title: Text('Find Your Perfect Home'),
)`,
        after: `// In Scaffold:
appBar: VxrAppBar(
  title: 'Find Your Perfect Home',
  subtitle: 'Discover rental properties near you',
  leading: const VxrLogoMark(onGradient: true, size: 14),
  actions: [
    IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white),
      onPressed: () => Navigator.push(...)),
    IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white),
      onPressed: () { /* notifications */ }),
  ],
  bottom: const VxrSearchBar(onGradient: true),
),`,
        note: 'No rounded bottom — Variation B headers are square-bottomed.',
      },
      {
        label: 'Category chips',
        before: `Container(
  decoration: BoxDecoration(
    color: selected ? Colors.orange : Colors.grey[200],
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(label),
)`,
        after: `VxrChip(
  label: label,
  active: selectedCategory == i,
  onTap: () => setState(() => selectedCategory = i),
)`,
      },
      {
        label: 'Property card → horizontal',
        before: `// Old: vertical card, image on top, content below
Card(
  child: Column(children: [
    Image.network(p.image, height: 150, fit: BoxFit.cover),
    Padding(child: Column(children: [
      Text(p.title), Text(p.location), Text('₱\${p.price}'),
      Row(children: [Icon(Icons.bed), Text('\${p.beds}'), ...])
    ])),
  ]),
)`,
        after: `// New: horizontal card, image LEFT, content RIGHT, favorite far right
VxrPropertyCard(
  image: p.image,
  imageIsAsset: p.image.startsWith('assets/'),
  title: p.title,
  location: p.location,
  price: '₱\${p.price.toStringAsFixed(0)}/mo',
  beds: p.beds,
  baths: p.baths,
  area: p.area,
  label: p.label,
  favorited: _bookmarkedIds.contains(p.id),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => UnitDetailsScreen(property: p))),
  onFavoriteTap: () => _toggleBookmark(p.id),
)`,
      },
      {
        label: 'BottomNavigationBar → VxrBottomNav',
        before: `bottomNavigationBar: BottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  items: [...]
)`,
        after: `bottomNavigationBar: VxrBottomNav(
  activeIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
)`,
      },
    ],
  },
  {
    file: 'lib/search_field.dart',
    summary: 'SURFACE header (not gradient) — the Var B distinguishing move',
    changes: [
      {
        label: 'Use VxrSurfaceAppBar instead of VxrAppBar',
        before: `AppBar(
  backgroundColor: Color(0xFFF36C6C),
  title: TextField(decoration: InputDecoration(hintText: 'Search')),
)`,
        after: `appBar: VxrSurfaceAppBar(
  title: 'Search Properties',
  subtitle: 'Find your perfect rental home',
  bottom: VxrSearchBar(
    controller: _searchController,
    onChanged: _onSearchChanged,
    onFilterTap: _openFilters,
  ),
),`,
        note: 'This is what makes Variation B feel different from A: Search uses a light surface header, not the coral gradient. The text + search bar both adapt to the light bg.',
      },
      {
        label: 'List/Map toggle pill',
        before: `// custom toggle styling`,
        after: `Container(
  decoration: BoxDecoration(
    color: VxrTheme.of(context).surface2,
    borderRadius: BorderRadius.circular(10),
  ),
  padding: const EdgeInsets.all(2),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    _segment('List', !_showMap), _segment('Map', _showMap),
  ]),
)`,
      },
    ],
  },
  {
    file: 'lib/unit_details.dart',
    summary: 'Hero image + tabs + sticky 360° / Apply CTA',
    changes: [
      {
        label: 'CTA bar at bottom — Var B treatment',
        before: `Container(
  padding: const EdgeInsets.all(16),
  child: ElevatedButton(child: Text('Apply Now'), ...),
)`,
        after: `Container(
  decoration: BoxDecoration(
    color: VxrTheme.of(context).surface,
    border: Border(top: BorderSide(color: VxrTheme.of(context).border)),
  ),
  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
  child: Row(children: [
    Expanded(
      child: VxrSecondaryButton(
        label: '360° Tour',
        icon: Icons.view_in_ar,
        onPressed: _openPanorama,
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      flex: 2,
      child: VxrPrimaryButton(
        label: 'Apply Now',
        onPressed: () => _openApplication(),
      ),
    ),
  ]),
),`,
      },
      {
        label: 'Tab bar styling',
        before: `TabBar(tabs: [Tab(text: 'Details'), ...], indicatorColor: Colors.orange)`,
        after: `TabBar(
  tabs: const [Tab(text: 'Details'), Tab(text: 'Amenities'), Tab(text: 'Location')],
  labelColor: VxrTokens.accent,
  unselectedLabelColor: VxrTokens.textMuted,
  indicatorColor: VxrTokens.accent,
  indicatorWeight: 2,
  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
)`,
      },
      {
        label: 'Amenity chips (selected = soft accent fill)',
        before: `Chip(label: Text(amenity))`,
        after: `Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  decoration: BoxDecoration(
    color: VxrTokens.accentSoft,
    borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
    border: Border.all(color: VxrTokens.accent.withOpacity(0.2)),
  ),
  child: Text(amenity, style: GoogleFonts.dmSans(
    fontSize: 11, fontWeight: FontWeight.w600, color: VxrTokens.accent)),
)`,
      },
    ],
  },
  {
    file: 'lib/profile_screen.dart',
    summary: 'Gradient hero card with avatar; menu rows w/ soft-accent icon tiles',
    changes: [
      {
        label: 'Header (keep rounded bottom on Profile per design)',
        before: `Container(
  color: Color(0xFFF36C6C),
  child: Column(children: [
    CircleAvatar(...), Text(name), Text(email),
  ]),
)`,
        after: `Container(
  decoration: const BoxDecoration(
    gradient: VxrTokens.brandGradient,
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
  ),
  padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 12, 18, 24),
  child: Column(children: [
    // back row
    Row(children: [
      const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
      const SizedBox(width: 6),
      Text('Profile', style: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
    const SizedBox(height: 16),
    // avatar + name
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.25),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
        image: _avatarUrl != null
          ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
          : null,
      ),
      child: _avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 32) : null,
    ),
    const SizedBox(height: 10),
    Text(_fullName, style: GoogleFonts.plusJakartaSans(
      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
    Text(_email, style: GoogleFonts.dmSans(
      fontSize: 11, color: Colors.white.withOpacity(0.75))),
  ]),
)`,
      },
      {
        label: 'Menu row pattern',
        before: `ListTile(
  leading: Icon(Icons.person),
  title: Text('Profile Information'),
  trailing: Icon(Icons.chevron_right),
)`,
        after: `// Wrap the whole list in a single rounded surface card.
// Each row:
InkWell(
  onTap: ...,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: VxrTokens.accentSoft, borderRadius: BorderRadius.circular(11)),
        child: const Icon(Icons.person_outline, color: VxrTokens.accent, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Profile Information', style: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w600)),
        Text('Update your personal details', style: GoogleFonts.dmSans(
          fontSize: 10, color: VxrTokens.textSub)),
      ])),
      Icon(Icons.chevron_right, color: VxrTokens.textMuted, size: 16),
    ]),
  ),
)`,
        note: 'Rows are separated by 1px dividers indented to align with the text (left:62).',
      },
      {
        label: 'Logout button',
        before: `ElevatedButton(child: Text('Logout'), ...)`,
        after: `VxrPrimaryButton(label: 'Logout', onPressed: _signOut)`,
      },
    ],
  },
  {
    file: 'lib/profile_information_screen.dart',
    summary: 'Standard form: VxrInputField stack',
    changes: [{
      label: 'Replace TextFormField+InputDecoration repetition',
      before: `TextFormField(
  decoration: InputDecoration(labelText: 'Full Name', filled: true, ...),
)`,
      after: `VxrInputField(
  label: 'Full Name',
  hint: 'Your full name',
  prefixIcon: Icons.person_outline,
  controller: _nameController,
)
// Save button:
VxrPrimaryButton(label: 'Save Changes', onPressed: _save, loading: _saving)`,
    }],
  },
  {
    file: 'lib/verification_screen.dart',
    summary: 'Stepper-style; reuse VxrInputField + soft-accent status pill',
    changes: [{
      label: 'Status pill',
      before: `Container(color: Colors.orange.shade100, child: Text(status))`,
      after: `Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: status == 'approved' ? const Color(0xFFDFF6E5)
         : status == 'rejected' ? const Color(0xFFFCE7E7)
                                 : VxrTokens.accentSoft,
    borderRadius: BorderRadius.circular(VxrTokens.radiusPill),
  ),
  child: Text(_statusLabel(status), style: GoogleFonts.dmSans(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: status == 'approved' ? VxrTokens.success
         : status == 'rejected' ? VxrTokens.danger
                                 : VxrTokens.accent)),
)`,
    }],
  },
  {
    file: 'lib/conversations_screen.dart',
    summary: 'Surface header; horizontal-style list rows',
    changes: [{
      label: 'AppBar + each row',
      before: `AppBar(title: Text('Messages'))
ListTile(leading: CircleAvatar(...), title: Text(name), subtitle: Text(preview))`,
      after: `appBar: VxrSurfaceAppBar(title: 'Messages', subtitle: 'Your conversations'),

// Row:
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: VxrTokens.border))),
  child: Row(children: [
    CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatar)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w700))),
        Text(time, style: GoogleFonts.dmSans(fontSize: 10, color: VxrTokens.textMuted)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(fontSize: 11, color: VxrTokens.textSub))),
        if (unread > 0) Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: VxrTokens.accent,
            borderRadius: BorderRadius.circular(VxrTokens.radiusPill)),
          child: Text('$unread', style: GoogleFonts.dmSans(
            fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    ])),
  ]),
)`,
    }],
  },
  {
    file: 'lib/chat_thread_screen.dart',
    summary: 'Bubbles: my message = gradient, theirs = surface2',
    changes: [{
      label: 'Message bubble + composer',
      before: `Container(
  color: isMe ? Colors.orange : Colors.grey[200],
  child: Text(message),
)`,
      after: `Align(
  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
  child: Container(
    constraints: const BoxConstraints(maxWidth: 260),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      gradient: isMe ? VxrTokens.brandGradient : null,
      color: isMe ? null : VxrTheme.of(context).surface2,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isMe ? 16 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 16),
      ),
    ),
    child: Text(message, style: GoogleFonts.dmSans(
      fontSize: 13, color: isMe ? Colors.white : VxrTokens.text)),
  ),
)`,
    }],
  },
  {
    file: 'lib/favorites_screen.dart',
    summary: 'Reuse VxrPropertyCard',
    changes: [{
      label: 'Replace inline card with VxrPropertyCard',
      before: `// Custom favorite tile`,
      after: `VxrPropertyCard(
  image: p.image, imageIsAsset: p.image.startsWith('assets/'),
  title: p.title, location: p.location, price: '₱\${p.price.toStringAsFixed(0)}/mo',
  beds: p.beds, baths: p.baths, area: p.area, label: p.label,
  favorited: true,
  onTap: () => _open(p),
  onFavoriteTap: () => _unfavorite(p.id),
)`,
    }],
  },
  {
    file: 'lib/filter_widget.dart',
    summary: 'Bottom sheet with 28px top radius; sliders use accent thumb',
    changes: [{
      label: 'Sheet shell',
      before: `showModalBottomSheet(...)`,
      after: `showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => Container(
    decoration: const BoxDecoration(
      color: VxrTokens.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(VxrTokens.radiusSheet)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    child: ...,
  ),
)

// And inside, wrap RangeSlider with SliderTheme:
SliderTheme(
  data: SliderTheme.of(context).copyWith(
    activeTrackColor: VxrTokens.accent,
    thumbColor: VxrTokens.accent,
    overlayColor: VxrTokens.accent.withOpacity(0.12),
    inactiveTrackColor: VxrTokens.surface2,
  ),
  child: RangeSlider(...),
)`,
    },
    {
      label: 'Apply / Reset CTA',
      before: `Row(children: [TextButton(...), ElevatedButton(...)])`,
      after: `Row(children: [
  Expanded(child: VxrSecondaryButton(label: 'Reset', onPressed: _reset)),
  const SizedBox(width: 10),
  Expanded(flex: 2, child: VxrPrimaryButton(label: 'Apply Filters', onPressed: _apply)),
])`,
    }],
  },
  {
    file: 'lib/house_enlistment_screen.dart',
    summary: 'Multi-step form. VxrInputField + step pill + sticky CTA',
    changes: [{
      label: 'Step indicator',
      before: `LinearProgressIndicator(value: step / total)`,
      after: `Row(children: List.generate(total, (i) => Expanded(
  child: Container(
    height: 3, margin: EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      gradient: i <= step ? VxrTokens.brandGradient : null,
      color: i > step ? VxrTokens.surface2 : null,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
)))`,
    },
    { label: 'All inputs', before: '// TextFormField everywhere', after: 'VxrInputField everywhere; CTAs become VxrPrimaryButton.' }],
  },
  {
    file: 'lib/manage_listing.dart',
    summary: 'List of own listings — VxrPropertyCard + status pill',
    changes: [{
      label: 'Each row',
      before: `Card(child: ListTile(...))`,
      after: `Stack(children: [
  VxrPropertyCard(
    image: l.image, title: l.title, location: l.location,
    price: '₱\${l.price.toStringAsFixed(0)}/mo',
    beds: l.beds, baths: l.baths, area: l.area,
    onTap: () => _edit(l),
  ),
  Positioned(top: 8, right: 8, child: _statusPill(l.status)),
])

Widget _statusPill(String s) {
  final colors = {
    'active':   [const Color(0xFFDFF6E5), VxrTokens.success],
    'pending':  [VxrTokens.accentSoft, VxrTokens.warning],
    'archived': [VxrTokens.surface2, VxrTokens.textSub],
  }[s]!;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: colors[0],
      borderRadius: BorderRadius.circular(VxrTokens.radiusPill)),
    child: Text(s.toUpperCase(), style: GoogleFonts.dmSans(
      fontSize: 8, fontWeight: FontWeight.w800, color: colors[1])),
  );
}`,
    }],
  },
  {
    file: 'lib/listing_image_manager.dart',
    summary: 'Image grid + add-tile',
    changes: [{
      label: 'Add-image tile',
      before: `Container(color: Colors.grey[200], child: Icon(Icons.add))`,
      after: `Container(
  decoration: BoxDecoration(
    color: VxrTokens.surface2,
    borderRadius: BorderRadius.circular(VxrTokens.radius),
    border: Border.all(color: VxrTokens.border, style: BorderStyle.solid, width: 1.5),
  ),
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: VxrTokens.accentSoft,
        borderRadius: BorderRadius.circular(11)),
      child: const Icon(Icons.add_photo_alternate_outlined,
        color: VxrTokens.accent, size: 18),
    ),
    const SizedBox(height: 8),
    Text('Add Photo', style: GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w600, color: VxrTokens.textSub)),
  ]),
)`,
    }],
  },
  {
    file: 'lib/rental_application.dart',
    summary: '5-step rental application — VxrInputField + step indicator',
    changes: [{
      label: 'Re-use enlistment patterns',
      before: '// step + form fields',
      after: 'Same as house_enlistment_screen.dart — step indicator with brandGradient bars, VxrInputField for every field, VxrPrimaryButton for Continue and final Submit.',
    }],
  },
  {
    file: 'lib/my_applications_screen.dart',
    summary: 'List of submitted applications + status',
    changes: [{
      label: 'Application card',
      before: 'Card with default styling',
      after: `Container(
  decoration: BoxDecoration(
    color: VxrTokens.surface,
    borderRadius: BorderRadius.circular(VxrTokens.radius),
    border: Border.all(color: VxrTokens.border),
    boxShadow: VxrTokens.shadowSm,
  ),
  padding: const EdgeInsets.all(14),
  child: Row(children: [
    ClipRRect(borderRadius: BorderRadius.circular(11),
      child: Image.network(a.image, width: 60, height: 60, fit: BoxFit.cover)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a.title, style: GoogleFonts.plusJakartaSans(
        fontSize: 13, fontWeight: FontWeight.w700)),
      Text('Submitted \${a.submittedDate}',
        style: GoogleFonts.dmSans(fontSize: 10, color: VxrTokens.textSub)),
      const SizedBox(height: 6),
      _statusPill(a.status),
    ])),
  ]),
)`,
    }],
  },
  {
    file: 'lib/enlistment_application.dart',
    summary: 'Landlord applicant review — same card pattern + Approve/Reject CTAs',
    changes: [{
      label: 'Action buttons',
      before: 'Two ElevatedButtons',
      after: `Row(children: [
  Expanded(child: OutlinedButton.icon(
    onPressed: () => _reject(a), icon: const Icon(Icons.close, size: 16),
    label: const Text('Reject'),
    style: OutlinedButton.styleFrom(
      foregroundColor: VxrTokens.danger,
      side: const BorderSide(color: VxrTokens.danger),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VxrTokens.radius)),
    ),
  )),
  const SizedBox(width: 10),
  Expanded(flex: 2, child: VxrPrimaryButton(
    label: 'Approve', icon: Icons.check, onPressed: () => _approve(a))),
])`,
    }],
  },
  {
    file: 'lib/contract_view_screen.dart',
    summary: 'PDF viewer + sign CTA',
    changes: [{
      label: 'Sticky bottom bar',
      before: 'Just the PDF',
      after: `bottomNavigationBar: SafeArea(
  child: Container(
    color: VxrTokens.surface,
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: VxrTokens.border))),
    child: VxrPrimaryButton(label: 'Sign Contract', icon: Icons.draw_outlined, onPressed: _sign),
  ),
)`,
    }],
  },
  {
    file: 'lib/landlord_contracts_screen.dart',
    summary: 'Contract list + status pills',
    changes: [{ label: 'Same row pattern as my_applications_screen.dart', before: '', after: 'Mirror the application card with title=tenant name, subtitle=property name, _statusPill for state.' }],
  },
  {
    file: 'lib/payment_screen.dart',
    summary: 'Payment history + sticky "Pay ₱X.XX Now" CTA',
    changes: [{
      label: 'Pay button — keep the orange-pay accent for clarity',
      before: `ElevatedButton(child: Text('Pay'), ...)`,
      after: `// Use the brand gradient; the design system's orange-pay (#FF9800) is reserved
// for the embedded payment-method card chrome, not the action button.
VxrPrimaryButton(
  label: 'Pay ₱\${amount.toStringAsFixed(2)} Now',
  icon: Icons.lock_outline,
  onPressed: _payWithStripe,
  loading: _processing,
)`,
    },
    {
      label: 'Payment-method card',
      before: 'Plain Card',
      after: `Container(
  decoration: BoxDecoration(
    color: const Color(0xFFFFF3E0), // orange-pay-light from design system
    borderRadius: BorderRadius.circular(VxrTokens.radius),
  ),
  padding: const EdgeInsets.all(14),
  child: Row(children: [
    const Icon(Icons.credit_card, color: Color(0xFFFF9800)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('•••• 4242', style: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w700)),
      Text('Visa · Expires 12/27', style: GoogleFonts.dmSans(
        fontSize: 11, color: VxrTokens.textSub)),
    ])),
    Text('Change', style: GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w700, color: VxrTokens.accent)),
  ]),
)`,
    }],
  },
  {
    file: 'lib/in_stay_dashboard_screen.dart',
    summary: 'Tenant in-stay hub — gradient hero + section grid',
    changes: [{
      label: 'Header + quick-action tiles',
      before: 'Default scaffold',
      after: `// Hero same shape as Profile, but title = "Welcome home, $firstName"
// Below: 2-column grid of action tiles. Each tile:
Container(
  decoration: BoxDecoration(
    color: VxrTokens.surface,
    borderRadius: BorderRadius.circular(VxrTokens.radius),
    border: Border.all(color: VxrTokens.border),
  ),
  padding: const EdgeInsets.all(14),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: VxrTokens.accentSoft,
        borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: VxrTokens.accent, size: 20),
    ),
    const SizedBox(height: 10),
    Text(title, style: GoogleFonts.plusJakartaSans(
      fontSize: 13, fontWeight: FontWeight.w700)),
    Text(sub, style: GoogleFonts.dmSans(
      fontSize: 10, color: VxrTokens.textSub)),
  ]),
)`,
    }],
  },
  {
    file: 'lib/tenantmanagement_screen.dart',
    summary: 'Landlord tenant list — avatar + status pill rows',
    changes: [{ label: 'Same row pattern as conversations_screen.dart', before: '', after: 'Reuse the row pattern from conversations_screen.dart, replacing message preview with rental dates and unit name.' }],
  },
  {
    file: 'lib/report_management_screen.dart',
    summary: 'Reports list — type icon + status',
    changes: [{
      label: 'Report card',
      before: 'Plain ListTile',
      after: `// Same shape as my_applications_screen.dart application card.
// Leading icon: report type (Icons.build, Icons.cleaning_services, Icons.water_drop).
// Trailing: _statusPill(report.status). Use VxrTokens.warning for 'open',
// VxrTokens.success for 'resolved', VxrTokens.textSub for 'closed'.`,
    }],
  },
  {
    file: 'lib/move_out_checklist_screen.dart',
    summary: 'Checklist with VxrTokens.accent checkboxes',
    changes: [{
      label: 'Checkbox style',
      before: `CheckboxListTile(...)`,
      after: `Theme(
  data: Theme.of(context).copyWith(
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? VxrTokens.accent : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
  child: CheckboxListTile(...),
)`,
    }],
  },
  {
    file: 'lib/relist_prompt_screen.dart',
    summary: 'Modal-style: VxrPrimaryButton + VxrSecondaryButton stack',
    changes: [{ label: 'Two CTAs', before: '', after: 'VxrPrimaryButton("Relist Property") + VxrSecondaryButton("Maybe Later")' }],
  },
  {
    file: 'lib/panorama_capture_screen.dart',
    summary: 'Camera UI — keep dark camera bg, accent the shutter',
    changes: [{
      label: 'Shutter button',
      before: 'Plain circle',
      after: `// Keep the camera scaffold dark (no theme change), but the shutter:
Container(
  width: 72, height: 72,
  decoration: const BoxDecoration(
    shape: BoxShape.circle,
    gradient: VxrTokens.brandGradient,
  ),
  child: Container(
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: Colors.transparent, width: 4),
    ),
    child: const Icon(Icons.camera_alt, color: VxrTokens.accent),
  ),
)`,
    }],
  },
  {
    file: 'lib/panorama_manager.dart',
    summary: 'Panorama list — thumbnail tile + actions',
    changes: [{ label: 'Reuse manage_listing.dart card pattern', before: '', after: 'Each panorama row: 60×60 image, name + capture date, trailing IconButton menu (Icons.more_vert) with delete/rename actions.' }],
  },
  {
    file: 'lib/panorama_tour_viewer.dart',
    summary: 'Viewer chrome — hide-on-tap brand bar',
    changes: [{
      label: 'Top + bottom chrome',
      before: 'Plain controls',
      after: `// Top safe-area bar:
Container(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
  decoration: BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.black.withOpacity(0.5), Colors.transparent]),
  ),
  child: Row(children: [
    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _close),
    const Spacer(),
    Text(roomLabel, style: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
  ]),
)`,
    }],
  },
  {
    file: 'lib/auth/auth_gate.dart',
    summary: 'Loading splash uses brand gradient + spinner',
    changes: [{
      label: 'Loading state',
      before: `CircularProgressIndicator()`,
      after: `Container(
  decoration: const BoxDecoration(gradient: VxrTokens.brandGradient),
  child: const Center(
    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
  ),
)`,
    }],
  },
  {
    file: 'lib/psgc_location_field.dart',
    summary: 'Location picker dropdown — surface2 fill + accent focus',
    changes: [{ label: 'Reuse global InputDecorationTheme', before: '', after: 'Already covered by VxrTheme.lightThemeData() — just remove any local InputDecoration overrides so the global theme takes over.' }],
  },
  {
    file: 'lib/property_data.dart',
    summary: 'NO visual changes — model file only',
    changes: [{ label: 'No styling here', before: '', after: 'This file is data + helpers. Skip.' }],
  },
  {
    file: 'lib/contract_templates.dart',
    summary: 'NO visual changes — template strings',
    changes: [{ label: 'No styling here', before: '', after: 'Skip.' }],
  },
  {
    file: 'lib/auth/auth_service.dart',
    summary: 'NO visual changes',
    changes: [{ label: 'No styling here', before: '', after: 'Skip.' }],
  },
  {
    file: 'lib/psgc_service.dart',
    summary: 'NO visual changes',
    changes: [{ label: 'No styling here', before: '', after: 'Skip.' }],
  },
  {
    file: 'lib/panorama_post_processor.dart',
    summary: 'NO visual changes',
    changes: [{ label: 'No styling here', before: '', after: 'Skip.' }],
  },
  {
    file: 'lib/panorama_stitcher.dart',
    summary: 'NO visual changes',
    changes: [{ label: 'No styling here', before: '', after: 'Skip.' }],
  },
  {
    file: 'lib/application_view.dart',
    summary: 'Application detail — section cards + status timeline',
    changes: [{
      label: 'Status timeline',
      before: 'Plain list',
      after: `// Vertical stepper. Each step:
Row(children: [
  Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: stepDone ? VxrTokens.brandGradient : null,
      color: stepDone ? null : VxrTokens.surface2,
      border: stepDone ? null : Border.all(color: VxrTokens.border),
    ),
    child: Icon(
      stepDone ? Icons.check : Icons.circle_outlined,
      size: 14, color: stepDone ? Colors.white : VxrTokens.textMuted),
  ),
  const SizedBox(width: 12),
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(step.label, style: GoogleFonts.plusJakartaSans(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: stepDone ? VxrTokens.text : VxrTokens.textMuted)),
    if (step.timestamp != null)
      Text(step.timestamp!, style: GoogleFonts.dmSans(
        fontSize: 10, color: VxrTokens.textSub)),
  ])),
])`,
    }],
  },
];

window.PATCHES = PATCHES;
