import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'application_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const RentalManagementApp());
}

// ─── Colors ───────────────────────────────────────────────────────────────────

class AppColors {
  static const coral = Color(0xFFE85D5D);
  static const coralLight = Color(0xFFFF7B7B);
  static const background = Color(0xFFF4F4F6);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B6B80);
  static const textHint = Color(0xFFAAAAAB);
  static const border = Color(0xFFEEEEF2);
  static const pendingBg = Color(0xFFFFF0E6);
  static const pendingText = Color(0xFFE07820);
  static const approvedBg = Color(0xFFE6F7EE);
  static const approvedText = Color(0xFF1A9E4A);
  static const rejectedBg = Color(0xFFFFECEC);
  static const rejectedText = Color(0xFFD93636);
  static const gradientStart = Color(0xFFFF7B7B);
  static const gradientEnd = Color(0xFFE85D5D);
}

const double kRadius = 14.0;
const double kPadding = 16.0;

// ─── Models ───────────────────────────────────────────────────────────────────

class UnitModel {
  final String title;
  final String beds;
  final String baths;
  final String size;
  final String location;
  final String price;
  final int applicantCount;
  final String imageUrl;

  const UnitModel({
    required this.title,
    required this.beds,
    required this.baths,
    required this.size,
    required this.location,
    required this.price,
    required this.applicantCount,
    required this.imageUrl,
  });
}

enum AppStatus { pending, approved, rejected }

class ApplicantModel {
  final String name;
  final String appliedDate;
  final AppStatus status;

  const ApplicantModel({
    required this.name,
    required this.appliedDate,
    required this.status,
  });
}

// ─── Sample Data ──────────────────────────────────────────────────────────────

const sampleUnits = [
  UnitModel(
    title: 'Modern Studio Appartment',
    beds: '1',
    baths: '1',
    size: '25m\u00b2',
    location: 'Makati City, Metro Manila',
    price: '\u20b14,000',
    applicantCount: 3,
    imageUrl:
        'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=600&q=80',
  ),
  UnitModel(
    title: '2 Floor Appartment',
    beds: '4',
    baths: '3',
    size: '85m\u00b2',
    location: 'Makati City, Metro Manila',
    price: '\u20b14,500',
    applicantCount: 3,
    imageUrl:
        'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=600&q=80',
  ),
  UnitModel(
    title: 'Deluxe Corner Unit',
    beds: '2',
    baths: '2',
    size: '45m\u00b2',
    location: 'BGC, Taguig City',
    price: '\u20b16,200',
    applicantCount: 5,
    imageUrl:
        'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600&q=80',
  ),
];

const sampleApplicants = [
  ApplicantModel(
      name: 'Juan Dela Cruz',
      appliedDate: 'Feb 10, 2025',
      status: AppStatus.pending),
  ApplicantModel(
      name: 'Maria Santos',
      appliedDate: 'Feb 10, 2025',
      status: AppStatus.pending),
  ApplicantModel(
      name: 'Pedro Reyes',
      appliedDate: 'Feb 11, 2025',
      status: AppStatus.approved),
  ApplicantModel(
      name: 'Ana Gomez',
      appliedDate: 'Feb 12, 2025',
      status: AppStatus.approved),
  ApplicantModel(
      name: 'Carlo Bautista',
      appliedDate: 'Feb 09, 2025',
      status: AppStatus.rejected),
  ApplicantModel(
      name: 'Liza Torres',
      appliedDate: 'Feb 08, 2025',
      status: AppStatus.pending),
];

// ─── App Root ─────────────────────────────────────────────────────────────────

class RentalManagementApp extends StatelessWidget {
  const RentalManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rental Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.coral),
      ),
      home: const ApplicantsScreen(),
    );
  }
}

// ─── GradientHeader ───────────────────────────────────────────────────────────

class GradientHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const GradientHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── StatusBadge ──────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final AppStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final String label;

    switch (status) {
      case AppStatus.pending:
        bg = AppColors.pendingBg;
        textColor = AppColors.pendingText;
        label = 'Pending';
        break;
      case AppStatus.approved:
        bg = AppColors.approvedBg;
        textColor = AppColors.approvedText;
        label = 'Approve';
        break;
      case AppStatus.rejected:
        bg = AppColors.rejectedBg;
        textColor = AppColors.rejectedText;
        label = 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ─── CustomSegmentedControl ───────────────────────────────────────────────────

class CustomSegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const CustomSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── ApplicantCard ────────────────────────────────────────────────────────────

class ApplicantCard extends StatelessWidget {
  final ApplicantModel applicant;
  final VoidCallback onView;

  const ApplicantCard({
    super.key,
    required this.applicant,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            applicant.name,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 7),
          StatusBadge(status: applicant.status),
          const SizedBox(height: 8),
          Text(
            'Applied: ${applicant.appliedDate}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onView,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('View Application'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── UnitCard ─────────────────────────────────────────────────────────────────

class UnitCard extends StatelessWidget {
  final UnitModel unit;
  final VoidCallback onTap;

  const UnitCard({super.key, required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(kRadius),
              ),
              child: Image.network(
                unit.imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 160,
                    color: const Color(0xFFEEEEF2),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.coral,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: const Color(0xFFEEEEF2),
                  child: const Center(
                    child: Icon(Icons.apartment_rounded,
                        color: AppColors.textHint, size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          unit.title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${unit.beds} Bed  |  ${unit.baths} Bath  |  ${unit.size}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        unit.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [],
                        ),
                        textScaler: TextScaler.noScaling,
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: unit.price,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.coral,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const TextSpan(
                              text: '/month',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Applicants (${unit.applicantCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BottomNavBar ─────────────────────────────────────────────────────────────

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
      _NavItem(Icons.search_rounded, Icons.search_rounded, 'Search'),
      _NavItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded,
          'Message'),
      _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? items[i].activeIcon : items[i].icon,
                        color: isActive
                            ? AppColors.coral
                            : AppColors.textSecondary,
                        size: 23,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? AppColors.coral
                              : AppColors.textSecondary,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;

  const _NavItem(this.activeIcon, this.icon, this.label);
}

// ─── Screen 1: Applicants ─────────────────────────────────────────────────────

class ApplicantsScreen extends StatefulWidget {
  const ApplicantsScreen({super.key});

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(title: 'Applicants', onBack: () {}),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: Text(
                    'Units',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                ...sampleUnits.map(
                  (unit) => UnitCard(
                    unit: unit,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplicationsScreen(
                          unitTitle: unit.title,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ─── Screen 2: Applications ────────────────────────────────────────────────

class ApplicationsScreen extends StatefulWidget {
  final String unitTitle;

  const ApplicationsScreen({super.key, required this.unitTitle});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  int _tabIndex = 0;

  List<ApplicantModel> get _filtered {
    final statusList = [
      AppStatus.pending,
      AppStatus.approved,
      AppStatus.rejected,
    ];
    return sampleApplicants
        .where((a) => a.status == statusList[_tabIndex])
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(title: 'Applications'),
          CustomSegmentedControl(
            selectedIndex: _tabIndex,
            labels: const ['Pending', 'Approve', 'Rejected'],
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOut,
              child: _filtered.isEmpty
                  ? _EmptyState(key: ValueKey(_tabIndex), tabIndex: _tabIndex)
                  : ListView.builder(
                      key: ValueKey('list_$_tabIndex'),
                      padding: const EdgeInsets.only(bottom: 28, top: 6),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => ApplicantCard(
                        applicant: _filtered[i],
                        onView: () {
                          // Navigate directly to ApplicationDetailsScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ApplicationDetailsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({super.key, required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    const labels = ['pending', 'approved', 'rejected'];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.coral.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: AppColors.coral, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            'No ${labels[tabIndex]} applications',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Applications will appear here once submitted.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}