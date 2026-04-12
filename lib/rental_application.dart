import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const RentalApp());
}

// ─── Theme & Constants ────────────────────────────────────────────────────────

class AppColors {
  static const primary = Color(0xFFE85D5D);
  static const primaryLight = Color(0xFFFFF0F0);
  static const background = Color(0xFFF2F2F5);
  static const card = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFF5F5F7);
  static const border = Color(0xFFE8E8EC);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B6B80);
  static const textHint = Color(0xFFAAAAAB);
  static const infoBlue = Color(0xFFEEF4FF);
  static const infoBlueBorder = Color(0xFFBDD3FF);
  static const progressBg = Color(0xFFE8E8EC);
  static const shadowColor = Color(0x14000000);
}

const double kRadius = 14.0;
const double kCardPadding = 20.0;
const double kFieldSpacing = 14.0;
const double kButtonHeight = 52.0;

// ─── App Root ─────────────────────────────────────────────────────────────────

class RentalApp extends StatelessWidget {
  const RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rental Application',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const RentalApplicationScreen(),
    );
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class RentalApplicationScreen extends StatefulWidget {
  const RentalApplicationScreen({super.key});

  @override
  State<RentalApplicationScreen> createState() =>
      _RentalApplicationScreenState();
}

class _RentalApplicationScreenState extends State<RentalApplicationScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step5Key = GlobalKey<FormState>();

  // Step 1
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Step 2
  String? _employmentStatus;
  final _companyCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _workAddressCtrl = TextEditingController();

  // Step 3
  final _prevAddressCtrl = TextEditingController();
  final _moveInCtrl = TextEditingController();
  final _moveOutCtrl = TextEditingController();
  final _landlordNameCtrl = TextEditingController();
  final _landlordContactCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  // Step 4
  String? _idFront, _idBack, _proofOfIncome;

  // Step 5
  bool _agreed = false;
  final _signatureCtrl = TextEditingController();
  final _signDateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl,
      _dobCtrl, _addressCtrl, _companyCtrl, _jobTitleCtrl,
      _incomeCtrl, _lengthCtrl, _workAddressCtrl, _prevAddressCtrl,
      _moveInCtrl, _moveOutCtrl, _landlordNameCtrl, _landlordContactCtrl,
      _reasonCtrl, _signatureCtrl, _signDateCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _animateToStep(int step) {
    _animController.reset();
    setState(() => _currentStep = step);
    _animController.forward();
  }

  void _nextStep() {
    bool valid = true;
    if (_currentStep == 0) valid = _step1Key.currentState?.validate() ?? false;
    if (_currentStep == 1) valid = _step2Key.currentState?.validate() ?? false;
    if (_currentStep == 2) valid = _step3Key.currentState?.validate() ?? false;
    if (_currentStep == 4) valid = _step5Key.currentState?.validate() ?? false;

    if (!valid) return;
    if (_currentStep < 4) _animateToStep(_currentStep + 1);
  }

  void _prevStep() {
    if (_currentStep > 0) _animateToStep(_currentStep - 1);
  }

  void _submitApplication() {
    if (!(_step5Key.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the declaration.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Application Submitted!',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Your rental application has been submitted successfully. The landlord will review it within 2–3 business days.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to home screen
            },
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  static const _stepTitles = [
    'Personal Information',
    'Employment & Financial',
    'Rental History',
    'Identity Verification',
    'Declaration & Consent',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Rental Application',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildCurrentStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of 5',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AppProgressBar(currentStep: _currentStep, totalSteps: 5),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return Step1PersonalInfo(
          formKey: _step1Key,
          firstNameCtrl: _firstNameCtrl,
          lastNameCtrl: _lastNameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          dobCtrl: _dobCtrl,
          addressCtrl: _addressCtrl,
          onNext: _nextStep,
        );
      case 1:
        return Step2Employment(
          formKey: _step2Key,
          employmentStatus: _employmentStatus,
          onStatusChanged: (v) => setState(() => _employmentStatus = v),
          companyCtrl: _companyCtrl,
          jobTitleCtrl: _jobTitleCtrl,
          incomeCtrl: _incomeCtrl,
          lengthCtrl: _lengthCtrl,
          workAddressCtrl: _workAddressCtrl,
          onBack: _prevStep,
          onNext: _nextStep,
        );
      case 2:
        return Step3RentalHistory(
          formKey: _step3Key,
          prevAddressCtrl: _prevAddressCtrl,
          moveInCtrl: _moveInCtrl,
          moveOutCtrl: _moveOutCtrl,
          landlordNameCtrl: _landlordNameCtrl,
          landlordContactCtrl: _landlordContactCtrl,
          reasonCtrl: _reasonCtrl,
          onBack: _prevStep,
          onNext: _nextStep,
        );
      case 3:
        return Step4Identity(
          idFront: _idFront,
          idBack: _idBack,
          proofOfIncome: _proofOfIncome,
          onIdFrontPicked: (v) => setState(() => _idFront = v),
          onIdBackPicked: (v) => setState(() => _idBack = v),
          onProofPicked: (v) => setState(() => _proofOfIncome = v),
          onBack: _prevStep,
          onNext: _nextStep,
        );
      case 4:
        return Step5Declaration(
          formKey: _step5Key,
          agreed: _agreed,
          onAgreedChanged: (v) => setState(() => _agreed = v ?? false),
          signatureCtrl: _signatureCtrl,
          dateCtrl: _signDateCtrl,
          onBack: _prevStep,
          onSubmit: _submitApplication,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────

class AppProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const AppProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            height: 4,
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: AppColors.progressBg,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            height: 4,
            width: constraints.maxWidth *
                ((currentStep + 1) / totalSteps),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      );
    });
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class FormCardContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const FormCardContainer({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(kCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
            children: [
              if (validator != null)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textHint,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 14 : 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 11, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class CustomDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          validator: validator,
          hint: Text(hint,
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 13.5)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary, size: 20),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            errorStyle: const TextStyle(fontSize: 11, color: AppColors.primary),
          ),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool outlined;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, kButtonHeight),
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius)),
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, kButtonHeight),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius)),
              textStyle: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class UploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? fileName;
  final VoidCallback onChoose;

  const UploadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: fileName != null
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.border,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.upload_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (fileName != null) ...[
              const SizedBox(height: 8),
              Text(
                fileName!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('Choose File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 1: Personal Information ─────────────────────────────────────────────

class Step1PersonalInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl, lastNameCtrl, emailCtrl,
      phoneCtrl, dobCtrl, addressCtrl;
  final VoidCallback onNext;

  const Step1PersonalInfo({
    super.key,
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.dobCtrl,
    required this.addressCtrl,
    required this.onNext,
  });

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            FormCardContainer(
              title: 'Personal Information',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'First Name',
                        hint: 'Juan',
                        controller: firstNameCtrl,
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Last Name',
                        hint: 'Dela Cruz',
                        controller: lastNameCtrl,
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Email',
                  hint: 'juan@example.com',
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Phone Number',
                  hint: '+63 912 345 6789',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Date of Birth',
                  hint: 'dd/mm/yyyy',
                  controller: dobCtrl,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.calendar_today_rounded,
                      size: 18, color: AppColors.textSecondary),
                  validator: _required,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime(1995),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: AppColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (date != null) {
                      dobCtrl.text =
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    }
                  },
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Current Address',
                  hint: 'Enter your current address',
                  controller: addressCtrl,
                  maxLines: 3,
                  validator: _required,
                ),
              ],
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Next',
              onPressed: onNext,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 2: Employment & Financial ───────────────────────────────────────────

class Step2Employment extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? employmentStatus;
  final ValueChanged<String?> onStatusChanged;
  final TextEditingController companyCtrl, jobTitleCtrl, incomeCtrl,
      lengthCtrl, workAddressCtrl;
  final VoidCallback onBack, onNext;

  const Step2Employment({
    super.key,
    required this.formKey,
    required this.employmentStatus,
    required this.onStatusChanged,
    required this.companyCtrl,
    required this.jobTitleCtrl,
    required this.incomeCtrl,
    required this.lengthCtrl,
    required this.workAddressCtrl,
    required this.onBack,
    required this.onNext,
  });

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            FormCardContainer(
              title: 'Employment & Financial Information',
              children: [
                CustomDropdown(
                  label: 'Employment Status',
                  hint: 'Select status',
                  value: employmentStatus,
                  items: const [
                    'Employed (Full-Time)',
                    'Employed (Part-Time)',
                    'Self-Employed',
                    'Freelancer',
                    'Unemployed',
                    'Retired',
                    'Student',
                  ],
                  onChanged: onStatusChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Employer / Company Name',
                  hint: 'Company Name',
                  controller: companyCtrl,
                  validator: _required,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Personal / Job Title',
                  hint: 'Your position',
                  controller: jobTitleCtrl,
                  validator: _required,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Monthly Income',
                  hint: '₱ 0',
                  controller: incomeCtrl,
                  keyboardType: TextInputType.number,
                  validator: _required,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Length of Employment',
                  hint: 'e.g., 2 years',
                  controller: lengthCtrl,
                  validator: _required,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Work Address',
                  hint: 'Enter your work address',
                  controller: workAddressCtrl,
                  maxLines: 3,
                  validator: _required,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _BottomButtons(onBack: onBack, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 3: Rental History ───────────────────────────────────────────────────

class Step3RentalHistory extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController prevAddressCtrl, moveInCtrl, moveOutCtrl,
      landlordNameCtrl, landlordContactCtrl, reasonCtrl;
  final VoidCallback onBack, onNext;

  const Step3RentalHistory({
    super.key,
    required this.formKey,
    required this.prevAddressCtrl,
    required this.moveInCtrl,
    required this.moveOutCtrl,
    required this.landlordNameCtrl,
    required this.landlordContactCtrl,
    required this.reasonCtrl,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.infoBlueBorder, width: 1),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF4A7FE5), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'First time renting? If yes please fill the form below, if no click the next button.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF3A5FA0),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FormCardContainer(
              title: 'Rental History',
              children: [
                CustomTextField(
                  label: 'Previous Rental Address',
                  hint: 'Enter previous address',
                  controller: prevAddressCtrl,
                ),
                const SizedBox(height: kFieldSpacing),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Move-in Date',
                        hint: 'dd/mm/yyyy',
                        controller: moveInCtrl,
                        readOnly: true,
                        suffixIcon: const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.textSecondary),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2020),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (c, child) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) {
                            moveInCtrl.text =
                                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Move-out Date',
                        hint: 'dd/mm/yyyy',
                        controller: moveOutCtrl,
                        readOnly: true,
                        suffixIcon: const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.textSecondary),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2030),
                            builder: (c, child) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) {
                            moveOutCtrl.text =
                                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Previous Landlord Name',
                  hint: 'Landlord Name',
                  controller: landlordNameCtrl,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Landlord Contact Number',
                  hint: '+63 912 345 6789',
                  controller: landlordContactCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: kFieldSpacing),
                CustomTextField(
                  label: 'Reason for Leaving',
                  hint: 'Why are you moving?',
                  controller: reasonCtrl,
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _BottomButtons(onBack: onBack, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 4: Identity Verification ───────────────────────────────────────────

class Step4Identity extends StatelessWidget {
  final String? idFront, idBack, proofOfIncome;
  final ValueChanged<String?> onIdFrontPicked, onIdBackPicked, onProofPicked;
  final VoidCallback onBack, onNext;

  const Step4Identity({
    super.key,
    required this.idFront,
    required this.idBack,
    required this.proofOfIncome,
    required this.onIdFrontPicked,
    required this.onIdBackPicked,
    required this.onProofPicked,
    required this.onBack,
    required this.onNext,
  });

  void _simulatePick(BuildContext context, ValueChanged<String?> onPicked) {
    final names = [
      'document_scan.pdf',
      'id_photo.jpg',
      'proof.png',
      'file_upload.pdf'
    ];
    onPicked(names[DateTime.now().millisecond % names.length]);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(kCardPadding),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(kRadius),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 16,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Identity Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please upload the required documents for verification',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                UploadCard(
                  title: 'Valid ID (Front)',
                  subtitle: 'Upload a clear photo of your government-issued ID',
                  fileName: idFront,
                  onChoose: () => _simulatePick(context, onIdFrontPicked),
                ),
                const SizedBox(height: 14),
                UploadCard(
                  title: 'Valid ID (Back)',
                  subtitle: 'Upload the back side of your ID',
                  fileName: idBack,
                  onChoose: () => _simulatePick(context, onIdBackPicked),
                ),
                const SizedBox(height: 14),
                UploadCard(
                  title: 'Proof of Income',
                  subtitle:
                      'Latest payslip, ITR, or Certificate of Employment',
                  fileName: proofOfIncome,
                  onChoose: () => _simulatePick(context, onProofPicked),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _BottomButtons(onBack: onBack, onNext: onNext),
        ],
      ),
    );
  }
}

// ─── STEP 5: Declaration & Consent ───────────────────────────────────────────

class Step5Declaration extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool agreed;
  final ValueChanged<bool?> onAgreedChanged;
  final TextEditingController signatureCtrl, dateCtrl;
  final VoidCallback onBack, onSubmit;

  const Step5Declaration({
    super.key,
    required this.formKey,
    required this.agreed,
    required this.onAgreedChanged,
    required this.signatureCtrl,
    required this.dateCtrl,
    required this.onBack,
    required this.onSubmit,
  });

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(kCardPadding),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(kRadius),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 16,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Declaration & Consent',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'I hereby declare that all information provided in this application is true and accurate to the best of my knowledge.\n\nI understand that any false information may result in the rejection of my application or termination of the lease agreement.\n\nI consent to background and credit checks as part of the application process.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => onAgreedChanged(!agreed),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: agreed,
                            onChanged: onAgreedChanged,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            side: const BorderSide(
                                color: AppColors.border, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'I agree to the terms and conditions stated above.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Digital Signature (Full Name)',
                    hint: 'Full name',
                    controller: signatureCtrl,
                    validator: _required,
                  ),
                  const SizedBox(height: kFieldSpacing),
                  CustomTextField(
                    label: 'Date',
                    hint: 'dd/mm/yyyy',
                    controller: dateCtrl,
                    readOnly: true,
                    suffixIcon: const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.textSecondary),
                    validator: _required,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: AppColors.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null) {
                        dateCtrl.text =
                            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.infoBlueBorder, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_rounded,
                            color: Color(0xFF4A7FE5), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Note: By submitting this application, you agree to our Terms of Service and Privacy Policy. The landlord will review your application within 2–3 business days.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3A5FA0),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Back',
                    onPressed: onBack,
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    label: 'Submit Application',
                    onPressed: onSubmit,
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

// ─── Shared Bottom Buttons ────────────────────────────────────────────────────

class _BottomButtons extends StatelessWidget {
  final VoidCallback onBack, onNext;

  const _BottomButtons({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            label: 'Back',
            onPressed: onBack,
            outlined: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CustomButton(
            label: 'Next',
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}