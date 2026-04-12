import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const App());
}

// ─── Colors ───────────────────────────────────────────────────────────────────

class C {
  static const coral = Color(0xFFE85D5D);
  static const bg = Color(0xFFF4F4F6);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF1A1A2E);
  static const textLabel = Color(0xFF9898A8);
  static const textValue = Color(0xFF2A2A3E);
  static const border = Color(0xFFEEEEF2);
  static const green = Color(0xFF1DB954);
  static const red = Color(0xFFE03C3C);
  static const gradStart = Color(0xFFFF7B7B);
  static const gradEnd = Color(0xFFE85D5D);
}

// ─── App ──────────────────────────────────────────────────────────────────────

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Application Details',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: C.coral),
      ),
      home: const ApplicationDetailsScreen(),
    );
  }
}

// ─── Status enum ─────────────────────────────────────────────────────────────

enum AppStatus { pending, approved, rejected }

// ─── Application Data ─────────────────────────────────────────────────────────

class ApplicationData {
  final String name, dob, email, phone, currentAddress;
  final String employmentStatus, jobTitle, company, monthlyIncome,
      lengthOfEmployment, workAddress;
  final String previousAddress, reasonForLeaving, rentalDuration,
      previousLandlord, landlordContact, rentalReasonLeaving;
  final List<String> documents;

  const ApplicationData({
    required this.name,
    required this.dob,
    required this.email,
    required this.phone,
    required this.currentAddress,
    required this.employmentStatus,
    required this.jobTitle,
    required this.company,
    required this.monthlyIncome,
    required this.lengthOfEmployment,
    required this.workAddress,
    required this.previousAddress,
    required this.reasonForLeaving,
    required this.rentalDuration,
    required this.previousLandlord,
    required this.landlordContact,
    required this.rentalReasonLeaving,
    required this.documents,
  });
}

const _sampleData = ApplicationData(
  name: 'Juan Dela Cruz',
  dob: 'dd/mm/yyy',
  email: 'juandelacruz@email.com',
  phone: '(555) 123-4567',
  currentAddress: '456 Oak Street, Apt 2C, Springfield',
  employmentStatus: 'Employed',
  jobTitle: 'Software Engineer',
  company: 'Tech Corp Inc.',
  monthlyIncome: '\u20b120,000',
  lengthOfEmployment: '3 Years 2 months',
  workAddress: 'Trece Martires City',
  previousAddress: '789 Pine Avenue, Springfield',
  reasonForLeaving: 'Relocating for job',
  rentalDuration: '2 Years 1 month',
  previousLandlord: 'Juanito jose tinapa',
  landlordContact: '+63 912 345 6789',
  rentalReasonLeaving: 'Broken',
  documents: ['Valid ID', 'Valid ID (Back)', 'Proof of Income'],
);

// ─── Main Screen ──────────────────────────────────────────────────────────────

class ApplicationDetailsScreen extends StatefulWidget {
  const ApplicationDetailsScreen({super.key});
  @override
  State<ApplicationDetailsScreen> createState() =>
      _ApplicationDetailsScreenState();
}

class _ApplicationDetailsScreenState extends State<ApplicationDetailsScreen> {
  AppStatus _status = AppStatus.pending;
  final _data = _sampleData;

  Future<void> _onApprove() async {
    final ok = await ConfirmationDialog.show(
      context: context,
      title: 'Are you sure?',
      message: 'Are you sure to Approve\nthis Applicant?',
      confirmColor: C.green,
    );
    if (ok == true) setState(() => _status = AppStatus.approved);
  }

  Future<void> _onReject() async {
    final ok = await ConfirmationDialog.show(
      context: context,
      title: 'Are you sure?',
      message: 'Are you sure to Reject\nthis Applicant?',
      confirmColor: C.red,
    );
    if (ok == true) setState(() => _status = AppStatus.rejected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          const GradientHeader(title: 'Application Details'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _personalCard(),
                const SizedBox(height: 14),
                _employmentCard(),
                const SizedBox(height: 14),
                _rentalCard(),
                const SizedBox(height: 14),
                _documentsCard(),
                const SizedBox(height: 22),
                _actionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _data.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: C.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelValue(label: 'Date of Birth', value: _data.dob),
                    const SizedBox(height: 12),
                    LabelValue(label: 'Phone', value: _data.phone),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LabelValue(label: 'Email', value: _data.email),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LabelValue(
              label: 'Current Address', value: _data.currentAddress),
        ],
      ),
    );
  }

  Widget _employmentCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Employment'),
          const SizedBox(height: 14),
          TwoColumnRow(
            left: LabelValue(
                label: 'Employment Status',
                value: _data.employmentStatus),
            right:
                LabelValue(label: 'Job Title', value: _data.jobTitle),
          ),
          const SizedBox(height: 12),
          TwoColumnRow(
            left: LabelValue(label: 'Company', value: _data.company),
            right: LabelValue(
                label: 'Monthly Income', value: _data.monthlyIncome),
          ),
          const SizedBox(height: 12),
          TwoColumnRow(
            left: LabelValue(
                label: 'Length of Employment',
                value: _data.lengthOfEmployment),
            right: LabelValue(
                label: 'Work Address', value: _data.workAddress),
          ),
        ],
      ),
    );
  }

  Widget _rentalCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Rental History'),
          const SizedBox(height: 14),
          TwoColumnRow(
            left: LabelValue(
                label: 'Previous Address',
                value: _data.previousAddress),
            right: LabelValue(
                label: 'Reason for Leaving',
                value: _data.reasonForLeaving),
          ),
          const SizedBox(height: 12),
          TwoColumnRow(
            left: LabelValue(
                label: 'Rental Duration',
                value: _data.rentalDuration),
            right: LabelValue(
                label: 'Previous Landlord Name',
                value: _data.previousLandlord),
          ),
          const SizedBox(height: 12),
          TwoColumnRow(
            left: LabelValue(
                label: 'Landlord Contact Number',
                value: _data.landlordContact),
            right: LabelValue(
                label: 'Reason for Leaving',
                value: _data.rentalReasonLeaving),
          ),
        ],
      ),
    );
  }

  Widget _documentsCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Document'),
          const SizedBox(height: 12),
          ..._data.documents.asMap().entries.map(
                (e) => Padding(
                  padding: EdgeInsets.only(top: e.key > 0 ? 10 : 0),
                  child: DocumentItem(
                    label: e.value,
                    onView: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Viewing: ${e.value}'),
                          backgroundColor: C.coral,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    switch (_status) {
      case AppStatus.pending:
        return Row(
          children: [
            Expanded(
              child: StatusButton(
                label: 'Approve Applicant',
                color: C.green,
                onPressed: _onApprove,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatusButton(
                label: 'Reject Applicant',
                color: C.red,
                onPressed: _onReject,
              ),
            ),
          ],
        );
      case AppStatus.approved:
        return Center(
          child: StatusButton(
            label: 'Approved!',
            color: C.green,
            onPressed: null,
            minWidth: 180,
          ),
        );
      case AppStatus.rejected:
        return Center(
          child: StatusButton(
            label: 'Rejected',
            color: C.red,
            onPressed: null,
            minWidth: 180,
          ),
        );
    }
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
          colors: [C.gradStart, C.gradEnd],
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
                onTap: onBack ?? () => Navigator.pop(context),
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

// ─── InfoCard ─────────────────────────────────────────────────────────────────

class InfoCard extends StatelessWidget {
  final Widget child;
  const InfoCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── TwoColumnRow ─────────────────────────────────────────────────────────────

class TwoColumnRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const TwoColumnRow({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

// ─── LabelValue ───────────────────────────────────────────────────────────────

class LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const LabelValue({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: C.textLabel,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: C.textValue,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

// ─── SectionTitle ─────────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: C.textPrimary,
        letterSpacing: -0.1,
      ),
    );
  }
}

// ─── DocumentItem ─────────────────────────────────────────────────────────────

class DocumentItem extends StatelessWidget {
  final String label;
  final VoidCallback onView;
  const DocumentItem({super.key, required this.label, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.border),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 16,
              color: C.textLabel,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: C.textValue,
              ),
            ),
          ),
          GestureDetector(
            onTap: onView,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.border, width: 1),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: C.textValue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── StatusButton ─────────────────────────────────────────────────────────────

class StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final double? minWidth;

  const StatusButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: minWidth,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

// ─── ConfirmationDialog ───────────────────────────────────────────────────────

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final Color confirmColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmColor,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.38),
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: C.textLabel,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.textLabel,
                        side: const BorderSide(color: C.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
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
                      child: const Text('Yes'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}