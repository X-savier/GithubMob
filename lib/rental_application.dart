import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'property_data.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'verification_screen.dart';
import 'widgets/application_form_fields.dart';

/// 5-step tenant rental application form. Ported to mirror the web
/// implementation (`vxr-web/my-react-app/src/RentalApplicationForm.jsx`):
/// single Full Name field, dropdown employment length, first-time-renter
/// gate, proof-of-income only (identity verified separately), and two
/// required consent checkboxes instead of an e-signature pad.
class RentalApplicationScreen extends StatefulWidget {
  final String listingId;

  const RentalApplicationScreen({super.key, required this.listingId});

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

  // Step 1 — Personal
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Step 2 — Employment
  String? _employmentStatus;
  final _companyCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  String? _employmentLength;
  final _workAddressCtrl = TextEditingController();

  // Step 3 — Rental history
  String? _firstTimeRenter; // "Yes" or "No"
  final _prevAddressCtrl = TextEditingController();
  String? _rentalDuration;
  final _reasonCtrl = TextEditingController();
  final _landlordNameCtrl = TextEditingController();
  final _landlordContactCtrl = TextEditingController();

  // Step 4 — Proof of income only (no in-form ID upload)
  XFile? _incomeProofFile;

  // Step 5 — Two consents (no signature pad, no separate date field)
  bool _consentIdentity = false;
  bool _consentDataPrivacy = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
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
      _fullNameCtrl, _emailCtrl, _phoneCtrl, _dobCtrl, _addressCtrl,
      _companyCtrl, _jobTitleCtrl, _incomeCtrl, _workAddressCtrl,
      _prevAddressCtrl, _reasonCtrl, _landlordNameCtrl, _landlordContactCtrl,
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

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        final ok = _step2Key.currentState?.validate() ?? false;
        if (!ok) return false;
        if (_employmentStatus == null) {
          _snack('Employment status is required.');
          return false;
        }
        return true;
      case 2:
        if (_firstTimeRenter == null) {
          _snack('Please indicate if this is your first time renting.');
          return false;
        }
        if (_firstTimeRenter == 'Yes') return true;
        return _step3Key.currentState?.validate() ?? false;
      case 3:
        if (_incomeProofFile == null) {
          _snack('Please upload your proof of income.');
          return false;
        }
        return true;
      case 4:
        final ok = _step5Key.currentState?.validate() ?? false;
        if (!ok) return false;
        if (!_consentIdentity || !_consentDataPrivacy) {
          _snack('Please confirm both consent statements to submit.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < 4) _animateToStep(_currentStep + 1);
  }

  void _prevStep() {
    if (_currentStep > 0) _animateToStep(_currentStep - 1);
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? VxrTokens.danger : VxrTokens.accent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_validateStep(4)) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _snack('Please log in first.', isError: true);
      return;
    }

    // Defense-in-depth: the server-side check runs again inside
    // submitRentalApplicationV2, but the UX is much nicer if we redirect
    // unverified tenants to the verification flow before they uploaded
    // anything.
    final verified = await ensureVerifiedToApply(context);
    if (!verified) return;

    setState(() => _isSubmitting = true);

    try {
      final fullName = _fullNameCtrl.text.trim();
      final parts = fullName.isEmpty
          ? <String>[]
          : fullName.split(RegExp(r'\s+'));
      final firstName = parts.isNotEmpty ? parts.first : null;
      final lastName =
          parts.length > 1 ? parts.sublist(1).join(' ') : null;
      final today =
          DateTime.now().toIso8601String().split('T').first;
      final needsEmployment =
          !kIncomeNoDetails.contains(_employmentStatus);
      final isFirstTime = _firstTimeRenter == 'Yes';

      final formRow = <String, dynamic>{
        // Step 1
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': _trimOrNull(_phoneCtrl.text),
        'email': _trimOrNull(_emailCtrl.text),
        'date_of_birth': _trimOrNull(_dobCtrl.text),
        'current_address': _trimOrNull(_addressCtrl.text),
        // Step 2
        'employment_status': _employmentStatus,
        'job_title': needsEmployment ? _trimOrNull(_jobTitleCtrl.text) : null,
        'company_name': needsEmployment ? _trimOrNull(_companyCtrl.text) : null,
        'monthly_income': needsEmployment
            ? _toNumOrNull(_incomeCtrl.text)
            : null,
        'employment_length': needsEmployment ? _employmentLength : null,
        'work_address': needsEmployment
            ? _trimOrNull(_workAddressCtrl.text)
            : null,
        // Step 3
        'previous_address':
            isFirstTime ? null : _trimOrNull(_prevAddressCtrl.text),
        'stayed_duration': isFirstTime ? null : _rentalDuration,
        'reason_for_leaving':
            isFirstTime ? null : _trimOrNull(_reasonCtrl.text),
        'previous_landlord':
            isFirstTime ? null : _trimOrNull(_landlordNameCtrl.text),
        'landlord_contact':
            isFirstTime ? null : _trimOrNull(_landlordContactCtrl.text),
        // Step 5
        'agreed_to_declaration': _consentIdentity,
        'declaration_name': fullName.isEmpty ? null : fullName,
        'declaration_date': _consentIdentity ? today : null,
      };

      final result = await submitRentalApplicationV2(
        listingId: widget.listingId,
        tenantId: userId,
        formRow: formRow,
      );

      // Upload proof of income to the private application-documents bucket.
      // Path: {userId}/{ts}-income_proof-{safeName}
      try {
        final file = _incomeProofFile!;
        final bytes = await file.readAsBytes();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final safe =
            file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final path = '$userId/$ts-income_proof-$safe';
        await Supabase.instance.client.storage
            .from('application-documents')
            .uploadBinary(path, bytes);

        await saveApplicationDocuments(result.id, [
          {
            'document_type': 'proof_of_income',
            'url': path,
            'file_name': file.name,
          },
        ]);
      } catch (e) {
        debugPrint('income proof upload failed: $e');
        _snack('Application submitted, but uploading proof of income failed: $e',
            isError: true);
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Application Submitted!',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            result.isReapplication
                ? 'Your re-submitted application is back in review. The landlord will respond within 2–3 business days.'
                : 'Your rental application has been submitted successfully. The landlord will review it within 2–3 business days.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text('OK',
                  style: TextStyle(color: VxrTokens.accent)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('_submitApplication ERROR: $e');
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  static String? _trimOrNull(String? v) {
    if (v == null) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  static double? _toNumOrNull(String? v) {
    if (v == null) return null;
    final s = v.replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static const _stepTitles = [
    'Personal Information',
    'Employment & Financial',
    'Rental History',
    'Proof of Income',
    'Declaration & Consent',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VxrTokens.text),
          onPressed: () {
            if (_currentStep > 0) {
              _prevStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Rental Application',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: VxrTokens.text,
          ),
        ),
        centerTitle: true,
      ),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: Column(
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: VxrTokens.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of 5 — ${_stepTitles[_currentStep]}',
            style: const TextStyle(
              fontSize: 12,
              color: VxrTokens.textSub,
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
        return _Step1PersonalInfo(
          formKey: _step1Key,
          fullNameCtrl: _fullNameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          dobCtrl: _dobCtrl,
          addressCtrl: _addressCtrl,
          onNext: _nextStep,
        );
      case 1:
        return _Step2Employment(
          formKey: _step2Key,
          employmentStatus: _employmentStatus,
          onStatusChanged: (v) => setState(() => _employmentStatus = v),
          companyCtrl: _companyCtrl,
          jobTitleCtrl: _jobTitleCtrl,
          incomeCtrl: _incomeCtrl,
          employmentLength: _employmentLength,
          onLengthChanged: (v) => setState(() => _employmentLength = v),
          workAddressCtrl: _workAddressCtrl,
          onBack: _prevStep,
          onNext: _nextStep,
        );
      case 2:
        return _Step3RentalHistory(
          formKey: _step3Key,
          firstTimeRenter: _firstTimeRenter,
          onFirstTimeChanged: (v) => setState(() => _firstTimeRenter = v),
          prevAddressCtrl: _prevAddressCtrl,
          rentalDuration: _rentalDuration,
          onDurationChanged: (v) => setState(() => _rentalDuration = v),
          reasonCtrl: _reasonCtrl,
          landlordNameCtrl: _landlordNameCtrl,
          landlordContactCtrl: _landlordContactCtrl,
          onBack: _prevStep,
          onNext: _nextStep,
        );
      case 3:
        return _Step4ProofOfIncome(
          file: _incomeProofFile,
          onPicked: (f) => setState(() => _incomeProofFile = f),
          onBack: _prevStep,
          onNext: _nextStep,
        );
      case 4:
        return _Step5Declaration(
          formKey: _step5Key,
          fullName: _fullNameCtrl.text,
          consentIdentity: _consentIdentity,
          onConsentIdentityChanged: (v) =>
              setState(() => _consentIdentity = v ?? false),
          consentDataPrivacy: _consentDataPrivacy,
          onConsentDataPrivacyChanged: (v) =>
              setState(() => _consentDataPrivacy = v ?? false),
          isSubmitting: _isSubmitting,
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
              color: VxrTokens.surface2,
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
              gradient: VxrTokens.brandGradient,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      );
    });
  }
}

// ─── STEP 1: Personal Information ─────────────────────────────────────────────

class _Step1PersonalInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameCtrl, emailCtrl, phoneCtrl, dobCtrl,
      addressCtrl;
  final VoidCallback onNext;

  const _Step1PersonalInfo({
    required this.formKey,
    required this.fullNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.dobCtrl,
    required this.addressCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            ApplicationFormCard(
              title: 'Personal Information',
              children: [
                ApplicationTextField(
                  label: 'Full Name',
                  hint: 'Juan Dela Cruz',
                  controller: fullNameCtrl,
                  validator: requiredValidator,
                ),
                const SizedBox(height: kAppFieldSpacing),
                ApplicationTextField(
                  label: 'Email',
                  hint: 'juan@example.com',
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(s)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: kAppFieldSpacing),
                ApplicationTextField(
                  label: 'Contact Number',
                  hint: '+63 912 345 6789',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: requiredValidator,
                ),
                const SizedBox(height: kAppFieldSpacing),
                ApplicationDateField(
                  label: 'Date of Birth',
                  controller: dobCtrl,
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  initialDate: DateTime(1995),
                  validator: requiredValidator,
                ),
                const SizedBox(height: kAppFieldSpacing),
                ApplicationTextField(
                  label: 'Current Address',
                  hint: 'Enter your current address',
                  controller: addressCtrl,
                  maxLines: 3,
                  validator: requiredValidator,
                ),
              ],
            ),
            const SizedBox(height: 20),
            VxrPrimaryButton(label: 'Next', onPressed: onNext, fullWidth: true),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 2: Employment & Financial ───────────────────────────────────────────

class _Step2Employment extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? employmentStatus;
  final ValueChanged<String?> onStatusChanged;
  final TextEditingController companyCtrl, jobTitleCtrl, incomeCtrl,
      workAddressCtrl;
  final String? employmentLength;
  final ValueChanged<String?> onLengthChanged;
  final VoidCallback onBack, onNext;

  const _Step2Employment({
    required this.formKey,
    required this.employmentStatus,
    required this.onStatusChanged,
    required this.companyCtrl,
    required this.jobTitleCtrl,
    required this.incomeCtrl,
    required this.employmentLength,
    required this.onLengthChanged,
    required this.workAddressCtrl,
    required this.onBack,
    required this.onNext,
  });

  bool get _needsDetails =>
      employmentStatus != null && !kIncomeNoDetails.contains(employmentStatus);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            ApplicationFormCard(
              title: 'Employment & Financial Information',
              children: [
                ApplicationDropdown(
                  label: 'Employment Status',
                  hint: 'Select status',
                  value: employmentStatus,
                  items: const [
                    'Employed',
                    'Self-employed',
                    'Freelance',
                    'Student',
                    'Unemployed',
                    'Retired',
                  ],
                  onChanged: onStatusChanged,
                  validator: (v) =>
                      v == null ? 'Employment status is required' : null,
                ),
                if (_needsDetails) ...[
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Job Title',
                    hint: 'Your position',
                    controller: jobTitleCtrl,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Company Name',
                    hint: 'Company',
                    controller: companyCtrl,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Monthly Income',
                    hint: '₱ 0',
                    controller: incomeCtrl,
                    keyboardType: TextInputType.number,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationDropdown(
                    label: 'Length of Employment',
                    hint: 'Select duration',
                    value: employmentLength,
                    items: kEmploymentLengths,
                    onChanged: onLengthChanged,
                    validator: (v) =>
                        v == null ? 'Length of employment is required' : null,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Work Address',
                    hint: 'Enter your work address',
                    controller: workAddressCtrl,
                    maxLines: 3,
                    validator: requiredValidator,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            ApplicationStepNav(onBack: onBack, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 3: Rental History ───────────────────────────────────────────────────

class _Step3RentalHistory extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? firstTimeRenter;
  final ValueChanged<String?> onFirstTimeChanged;
  final TextEditingController prevAddressCtrl, reasonCtrl, landlordNameCtrl,
      landlordContactCtrl;
  final String? rentalDuration;
  final ValueChanged<String?> onDurationChanged;
  final VoidCallback onBack, onNext;

  const _Step3RentalHistory({
    required this.formKey,
    required this.firstTimeRenter,
    required this.onFirstTimeChanged,
    required this.prevAddressCtrl,
    required this.rentalDuration,
    required this.onDurationChanged,
    required this.reasonCtrl,
    required this.landlordNameCtrl,
    required this.landlordContactCtrl,
    required this.onBack,
    required this.onNext,
  });

  Widget _yesNoButton(String label, {required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? VxrTokens.accentSoft : VxrTokens.surface2,
            border: Border.all(
              color: selected ? VxrTokens.accent : VxrTokens.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? VxrTokens.accent : VxrTokens.textSub,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showHistory = firstTimeRenter == 'No';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApplicationFormCard(
              title: 'Rental History',
              children: [
                const Text(
                  'Is this your first time renting?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: VxrTokens.textSub,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _yesNoButton(
                      'Yes',
                      selected: firstTimeRenter == 'Yes',
                      onTap: () => onFirstTimeChanged('Yes'),
                    ),
                    const SizedBox(width: 12),
                    _yesNoButton(
                      'No',
                      selected: firstTimeRenter == 'No',
                      onTap: () => onFirstTimeChanged('No'),
                    ),
                  ],
                ),
                if (firstTimeRenter == 'Yes') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VxrTokens.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VxrTokens.accent.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: VxrTokens.accent, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No prior rental history needed. Continue to the next step.',
                            style: TextStyle(fontSize: 12.5, color: VxrTokens.text, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showHistory) ...[
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Previous Rental Address',
                    hint: 'Enter previous address',
                    controller: prevAddressCtrl,
                    maxLines: 3,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationDropdown(
                    label: 'Rental Duration',
                    hint: 'Select duration',
                    value: rentalDuration,
                    items: kRentalDurations,
                    onChanged: onDurationChanged,
                    validator: (v) =>
                        v == null ? 'Rental duration is required' : null,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Reason for Leaving',
                    hint: 'Why are/were you moving?',
                    controller: reasonCtrl,
                    maxLines: 3,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Previous Landlord Name',
                    hint: 'Landlord name',
                    controller: landlordNameCtrl,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Landlord Contact',
                    hint: '+63 912 345 6789',
                    controller: landlordContactCtrl,
                    keyboardType: TextInputType.phone,
                    validator: requiredValidator,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            ApplicationStepNav(onBack: onBack, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

// ─── STEP 4: Proof of Income ─────────────────────────────────────────────────

class _Step4ProofOfIncome extends StatefulWidget {
  final XFile? file;
  final ValueChanged<XFile?> onPicked;
  final VoidCallback onBack, onNext;

  const _Step4ProofOfIncome({
    required this.file,
    required this.onPicked,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<_Step4ProofOfIncome> createState() => _Step4ProofOfIncomeState();
}

class _Step4ProofOfIncomeState extends State<_Step4ProofOfIncome> {
  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: VxrTokens.accent),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: VxrTokens.accent),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          ApplicationFormCard(
            title: 'Proof of Income',
            children: [
              const Text(
                'Upload a clear photo of your payslip, certificate of employment, or bank statement (last 3 months).',
                style: TextStyle(
                    fontSize: 12.5,
                    color: VxrTokens.textSub,
                    height: 1.45),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kAppRadius),
                  border: Border.all(
                    color: file != null
                        ? VxrTokens.accent.withValues(alpha: 0.4)
                        : VxrTokens.border,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: VxrTokens.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.upload_rounded,
                          color: VxrTokens.accent, size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Proof of Income',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: VxrTokens.text),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Payslip, COE, or bank statement (last 3 months)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: VxrTokens.textSub,
                          height: 1.4),
                    ),
                    if (file != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(file.path),
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file.name,
                        style: const TextStyle(
                            fontSize: 12,
                            color: VxrTokens.accent,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: Text(file == null ? 'Choose File' : 'Replace File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VxrTokens.textSub,
                        side: const BorderSide(color: VxrTokens.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VxrTokens.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: VxrTokens.textSub),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your government-issued ID is verified separately in your profile and is no longer collected here.',
                        style: TextStyle(
                            fontSize: 11.5, color: VxrTokens.textSub, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ApplicationStepNav(onBack: widget.onBack, onNext: widget.onNext),
        ],
      ),
    );
  }
}

// ─── STEP 5: Declaration & Consent ───────────────────────────────────────────

class _Step5Declaration extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String fullName;
  final bool consentIdentity;
  final ValueChanged<bool?> onConsentIdentityChanged;
  final bool consentDataPrivacy;
  final ValueChanged<bool?> onConsentDataPrivacyChanged;
  final bool isSubmitting;
  final VoidCallback onBack, onSubmit;

  const _Step5Declaration({
    required this.formKey,
    required this.fullName,
    required this.consentIdentity,
    required this.onConsentIdentityChanged,
    required this.consentDataPrivacy,
    required this.onConsentDataPrivacyChanged,
    required this.isSubmitting,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            ApplicationFormCard(
              title: 'Declaration & Consent',
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VxrTokens.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VxrTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'I, ${fullName.trim().isEmpty ? '[Full Name]' : fullName.trim()}, hereby declare that all information provided in this rental application is true, complete, and accurate to the best of my knowledge.',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: VxrTokens.text,
                            height: 1.5,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'I acknowledge that the personal information I have submitted will be processed in accordance with the Data Privacy Act of 2012 (RA 10173) for the sole purpose of evaluating my rental application and managing the resulting tenancy.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: VxrTokens.textSub,
                            height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'I authorize the landlord to verify the documents I have submitted, including identity verification and reference checks where applicable.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: VxrTokens.textSub,
                            height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Declaration date: $dateStr',
                        style: const TextStyle(
                            fontSize: 12,
                            color: VxrTokens.textMuted,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: consentIdentity,
                  onChanged: onConsentIdentityChanged,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: VxrTokens.accent,
                  title: const Text(
                    'I consent to identity verification and authorize the landlord to verify the documents I have submitted.',
                    style: TextStyle(
                        fontSize: 13,
                        color: VxrTokens.text,
                        height: 1.45),
                  ),
                ),
                CheckboxListTile(
                  value: consentDataPrivacy,
                  onChanged: onConsentDataPrivacyChanged,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: VxrTokens.accent,
                  title: const Text(
                    'I agree to the collection and processing of my personal data in accordance with the Data Privacy Act of 2012.',
                    style: TextStyle(
                        fontSize: 13,
                        color: VxrTokens.text,
                        height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VxrTokens.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_rounded,
                          color: VxrTokens.accent, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'By submitting this application, you agree to our Terms of Service and Privacy Policy. The landlord will review within 2–3 business days.',
                          style: TextStyle(
                              fontSize: 12,
                              color: VxrTokens.text,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: VxrSecondaryButton(label: 'Back', onPressed: onBack),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: VxrPrimaryButton(
                    label: isSubmitting ? 'Submitting…' : 'Submit Application',
                    onPressed: isSubmitting ? () {} : onSubmit,
                    fullWidth: true,
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
