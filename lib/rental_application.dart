import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'property_data.dart';

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

// ─── Main Screen ──────────────────────────────────────────────────────────────

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
  String? _idFront, _idBack;
  XFile? _idFrontFile, _idBackFile;
  bool _isSubmitting = false;

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

  Future<void> _submitApplication() async {
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

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check if user already applied to this listing
      final alreadyApplied = await hasAppliedToListing(widget.listingId);
      if (alreadyApplied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You have already submitted an application for this listing.'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      // Build application data
      final applicationData = <String, dynamic>{
        'tenant_id': userId,
        'listing_id': widget.listingId,
        'status': 'pending',
        // Personal info
        'first_name': _firstNameCtrl.text,
        'last_name': _lastNameCtrl.text,
        'email': _emailCtrl.text,
        'phone_number': _phoneCtrl.text,
        'date_of_birth': _dobCtrl.text.isEmpty ? null : _dobCtrl.text,
        'current_address': _addressCtrl.text,
        // Employment
        'employment_status': _employmentStatus,
        'company_name': _companyCtrl.text.isEmpty ? null : _companyCtrl.text,
        'job_title': _jobTitleCtrl.text.isEmpty ? null : _jobTitleCtrl.text,
        'monthly_income': _incomeCtrl.text.isEmpty ? null : double.tryParse(_incomeCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')),
        'employment_length': _lengthCtrl.text.isEmpty ? null : _lengthCtrl.text,
        'work_address': _workAddressCtrl.text.isEmpty ? null : _workAddressCtrl.text,
        // Rental history
        'previous_address': _prevAddressCtrl.text.isEmpty ? null : _prevAddressCtrl.text,
        'move_in_date': _moveInCtrl.text.isEmpty ? null : _moveInCtrl.text,
        'move_out_date': _moveOutCtrl.text.isEmpty ? null : _moveOutCtrl.text,
        'previous_landlord': _landlordNameCtrl.text.isEmpty ? null : _landlordNameCtrl.text,
        'landlord_contact': _landlordContactCtrl.text.isEmpty ? null : _landlordContactCtrl.text,
        'reason_for_leaving': _reasonCtrl.text.isEmpty ? null : _reasonCtrl.text,
        // Declaration
        'agreed_to_declaration': _agreed,
        'declaration_name': _signatureCtrl.text,
        'declaration_date': _signDateCtrl.text.isEmpty ? null : _signDateCtrl.text,
      };

      final applicationId = await submitRentalApplication(applicationData);

      if (applicationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit application')),
          );
        }
        return;
      }

      // Upload documents
      final docs = <Map<String, String>>[];
      final uploads = [
        ('primary_id_front', _idFrontFile),
        ('primary_id_back', _idBackFile),
      ];

      debugPrint('Document upload: ${uploads.where((u) => u.$2 != null).length} files to upload');

      final storage = Supabase.instance.client.storage.from('listing-images');

      for (final (docType, file) in uploads) {
        if (file != null) {
          try {
            debugPrint('Uploading $docType: ${file.name}');
            final bytes = await file.readAsBytes();
            final ext = file.name.split('.').last;
            final fileName = '${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            final path = 'applications/$applicationId/$fileName';
            await storage.uploadBinary(path, bytes);
            final publicUrl = storage.getPublicUrl(path);
            debugPrint('Upload success $docType: $publicUrl');
            docs.add({
              'document_type': docType,
              'url': publicUrl,
              'file_name': fileName,
            });
          } catch (e) {
            debugPrint('Doc upload ($docType) failed: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed ($docType): $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }

      if (docs.isNotEmpty) {
        try {
          await saveApplicationDocuments(applicationId, docs);
          debugPrint('Saved ${docs.length} documents to application_document table');
        } catch (e) {
          debugPrint('saveApplicationDocuments failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save documents: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        debugPrint('No documents to save (all files were null or uploads failed)');
      }

      if (mounted) {
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
                  Navigator.pop(context, true);
                },
                child: const Text('OK', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('_submitApplication ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          onIdFrontPicked: (v) => setState(() => _idFront = v),
          onIdBackPicked: (v) => setState(() => _idBack = v),
          onIdFrontFilePicked: (v) => setState(() => _idFrontFile = v),
          onIdBackFilePicked: (v) => setState(() => _idBackFile = v),
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
          initialValue: value,
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
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  bool get _showEmploymentFields {
    final s = employmentStatus;
    if (s == null) return true;
    return s != 'Unemployed' && s != 'Student' && s != 'Retired';
  }

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
                    'Employed',
                    'Self-Employed',
                    'Freelancer',
                    'Student',
                    'Retired',
                    'Unemployed',
                  ],
                  onChanged: onStatusChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
                if (_showEmploymentFields) ...[
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
                      'First time renting? If yes, click the next button. If no, please fill out the form below.',
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
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

class Step4Identity extends StatefulWidget {
  final String? idFront, idBack;
  final ValueChanged<String?> onIdFrontPicked, onIdBackPicked;
  final ValueChanged<XFile?> onIdFrontFilePicked, onIdBackFilePicked;
  final VoidCallback onBack, onNext;

  const Step4Identity({
    super.key,
    required this.idFront,
    required this.idBack,
    required this.onIdFrontPicked,
    required this.onIdBackPicked,
    required this.onIdFrontFilePicked,
    required this.onIdBackFilePicked,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<Step4Identity> createState() => _Step4IdentityState();
}

class _Step4IdentityState extends State<Step4Identity> {
  XFile? _previewFile;

  Future<void> _pickImage(
      ValueChanged<String?> onName, ValueChanged<XFile?> onFile) async {
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      onName(picked.name);
      onFile(picked);
      // Show preview
      setState(() => _previewFile = picked);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.file(
                      File(picked.path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          picked.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK', style: TextStyle(color: AppColors.primary)),
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
                  'Please upload or capture the required documents for verification',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                UploadCard(
                  title: 'Valid ID (Front)',
                  subtitle: 'Upload or capture a clear photo of your government-issued ID',
                  fileName: widget.idFront,
                  onChoose: () => _pickImage(widget.onIdFrontPicked, widget.onIdFrontFilePicked),
                ),
                const SizedBox(height: 14),
                UploadCard(
                  title: 'Valid ID (Back)',
                  subtitle: 'Upload or capture the back side of your ID',
                  fileName: widget.idBack,
                  onChoose: () => _pickImage(widget.onIdBackPicked, widget.onIdBackFilePicked),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _BottomButtons(onBack: widget.onBack, onNext: widget.onNext),
        ],
      ),
    );
  }
}

// ─── STEP 5: Declaration & Consent ───────────────────────────────────────────

class Step5Declaration extends StatefulWidget {
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

  @override
  State<Step5Declaration> createState() => _Step5DeclarationState();
}

class _Step5DeclarationState extends State<Step5Declaration> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: widget.formKey,
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
                    onTap: () => widget.onAgreedChanged(!widget.agreed),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: widget.agreed,
                            onChanged: widget.onAgreedChanged,
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
                    label: 'Full Name',
                    hint: 'Full name as signature',
                    controller: widget.signatureCtrl,
                    validator: _required,
                  ),
                  const SizedBox(height: kFieldSpacing),
                  // E-Signature pad
                  RichText(
                    text: const TextSpan(
                      text: 'E-Signature',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.1,
                      ),
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onPanStart: (d) {
                      setState(() {
                        _currentStroke = [d.localPosition];
                        _strokes.add(_currentStroke);
                      });
                    },
                    onPanUpdate: (d) {
                      setState(() {
                        _currentStroke.add(d.localPosition);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _currentStroke = [];
                      });
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CustomPaint(
                          painter: _SignaturePainter(
                            strokes: _strokes,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearSignature,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: kFieldSpacing),
                  CustomTextField(
                    label: 'Date',
                    hint: 'yyyy-mm-dd',
                    controller: widget.dateCtrl,
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
                        widget.dateCtrl.text =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
                    onPressed: widget.onBack,
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    label: 'Submit Application',
                    onPressed: widget.onSubmit,
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

// ─── Signature Canvas Painter ─────────────────────────────────────────────────

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;

  _SignaturePainter({required this.strokes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 1.25, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = ui.Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        final p0 = stroke[i - 1];
        final p1 = stroke[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}