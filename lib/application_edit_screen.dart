import 'package:flutter/material.dart';

import 'property_data.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'widgets/application_form_fields.dart';

/// Edit screen for a PENDING rental application. Mirrors the web
/// `ApplicationEditModal` — pre-fills from the row, lets the tenant
/// update personal/employment/rental fields, and saves through
/// [updateApplicationForTenant] which re-checks `status='pending'`
/// server-side. Document uploads are intentionally not editable
/// (matches the web modal).
class ApplicationEditScreen extends StatefulWidget {
  final String applicationId;
  final String tenantId;

  const ApplicationEditScreen({
    super.key,
    required this.applicationId,
    required this.tenantId,
  });

  @override
  State<ApplicationEditScreen> createState() => _ApplicationEditScreenState();
}

class _ApplicationEditScreenState extends State<ApplicationEditScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Personal
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Employment
  String? _employmentStatus;
  final _jobTitleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  String? _employmentLength;
  final _workAddressCtrl = TextEditingController();

  // Rental history
  final _prevAddressCtrl = TextEditingController();
  String? _rentalDuration;
  final _reasonCtrl = TextEditingController();
  final _landlordNameCtrl = TextEditingController();
  final _landlordContactCtrl = TextEditingController();

  bool _consentIdentity = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameCtrl, _emailCtrl, _phoneCtrl, _dobCtrl, _addressCtrl,
      _jobTitleCtrl, _companyCtrl, _incomeCtrl, _workAddressCtrl,
      _prevAddressCtrl, _reasonCtrl, _landlordNameCtrl, _landlordContactCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final data = await fetchApplicationForTenant(
      widget.applicationId,
      widget.tenantId,
    );
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _loadError = 'Application not found.';
      });
      return;
    }
    if (data['status'] != 'pending') {
      setState(() {
        _loading = false;
        _loadError = 'This application can no longer be edited.';
      });
      return;
    }
    setState(() {
      _fullNameCtrl.text = data['fullName'] ?? '';
      _emailCtrl.text = data['email'] ?? '';
      _phoneCtrl.text = data['contactNumber'] ?? '';
      _dobCtrl.text = data['dateOfBirth'] ?? '';
      _addressCtrl.text = data['currentAddress'] ?? '';
      _employmentStatus = _toNullIfEmpty(data['employmentStatus']);
      _jobTitleCtrl.text = data['jobTitle'] ?? '';
      _companyCtrl.text = data['companyName'] ?? '';
      _incomeCtrl.text = data['monthlyIncome'] ?? '';
      _employmentLength = _toNullIfEmpty(data['lengthOfEmployment']);
      _workAddressCtrl.text = data['workAddress'] ?? '';
      _prevAddressCtrl.text = data['previousAddress'] ?? '';
      _rentalDuration = _toNullIfEmpty(data['rentalDuration']);
      _reasonCtrl.text = data['reasonForLeaving'] ?? '';
      _landlordNameCtrl.text = data['landlordName'] ?? '';
      _landlordContactCtrl.text = data['landlordPhone'] ?? '';
      _consentIdentity = data['consentIdentity'] == true;
      _loading = false;
    });
  }

  String? _toNullIfEmpty(dynamic v) {
    final s = (v ?? '').toString();
    return s.isEmpty ? null : s;
  }

  bool get _needsEmploymentDetails =>
      _employmentStatus != null &&
      !kIncomeNoDetails.contains(_employmentStatus);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_employmentStatus == null) {
      _snack('Employment status is required.', isError: true);
      return;
    }
    if (_needsEmploymentDetails && _employmentLength == null) {
      _snack('Length of employment is required.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await updateApplicationForTenant(
        applicationId: widget.applicationId,
        tenantId: widget.tenantId,
        patch: {
          'fullName': _fullNameCtrl.text,
          'dateOfBirth': _dobCtrl.text,
          'contactNumber': _phoneCtrl.text,
          'email': _emailCtrl.text,
          'currentAddress': _addressCtrl.text,
          'employmentStatus': _employmentStatus,
          'jobTitle': _needsEmploymentDetails ? _jobTitleCtrl.text : '',
          'companyName': _needsEmploymentDetails ? _companyCtrl.text : '',
          'monthlyIncome': _needsEmploymentDetails ? _incomeCtrl.text : '',
          'lengthOfEmployment':
              _needsEmploymentDetails ? _employmentLength : '',
          'workAddress':
              _needsEmploymentDetails ? _workAddressCtrl.text : '',
          'previousAddress': _prevAddressCtrl.text,
          'rentalDuration': _rentalDuration ?? '',
          'reasonForLeaving': _reasonCtrl.text,
          'landlordName': _landlordNameCtrl.text,
          'landlordPhone': _landlordContactCtrl.text,
          'consentIdentity': _consentIdentity,
        },
      );
      if (!mounted) return;
      _snack('Application updated.');
      Navigator.pop(context, true);
    } catch (e) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? VxrTokens.danger : VxrTokens.accent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: const Text('Edit Application'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent))
          : _loadError != null
              ? _errorState()
              : _form(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline,
                size: 48, color: VxrTokens.textMuted),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'Could not load application.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VxrTokens.textSub, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            VxrPrimaryButton(
              label: 'Back',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return AbsorbPointer(
      absorbing: _saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ApplicationFormCard(
                title: 'Personal Information',
                children: [
                  ApplicationTextField(
                    label: 'Full Name',
                    hint: 'Juan Dela Cruz',
                    controller: _fullNameCtrl,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Email',
                    hint: 'juan@example.com',
                    controller: _emailCtrl,
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
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationDateField(
                    label: 'Date of Birth',
                    controller: _dobCtrl,
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                    initialDate: DateTime(1995),
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Current Address',
                    hint: 'Enter your current address',
                    controller: _addressCtrl,
                    maxLines: 3,
                    validator: requiredValidator,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ApplicationFormCard(
                title: 'Employment & Financial',
                children: [
                  ApplicationDropdown(
                    label: 'Employment Status',
                    hint: 'Select status',
                    value: _employmentStatus,
                    items: const [
                      'Employed',
                      'Self-employed',
                      'Freelance',
                      'Student',
                      'Unemployed',
                      'Retired',
                    ],
                    onChanged: (v) => setState(() => _employmentStatus = v),
                    validator: (v) =>
                        v == null ? 'Employment status is required' : null,
                  ),
                  if (_needsEmploymentDetails) ...[
                    const SizedBox(height: kAppFieldSpacing),
                    ApplicationTextField(
                      label: 'Job Title',
                      hint: 'Your position',
                      controller: _jobTitleCtrl,
                    ),
                    const SizedBox(height: kAppFieldSpacing),
                    ApplicationTextField(
                      label: 'Company Name',
                      hint: 'Company',
                      controller: _companyCtrl,
                    ),
                    const SizedBox(height: kAppFieldSpacing),
                    ApplicationTextField(
                      label: 'Monthly Income',
                      hint: '₱ 0',
                      controller: _incomeCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: kAppFieldSpacing),
                    ApplicationDropdown(
                      label: 'Length of Employment',
                      hint: 'Select duration',
                      value: _employmentLength,
                      items: kEmploymentLengths,
                      onChanged: (v) =>
                          setState(() => _employmentLength = v),
                    ),
                    const SizedBox(height: kAppFieldSpacing),
                    ApplicationTextField(
                      label: 'Work Address',
                      hint: 'Enter your work address',
                      controller: _workAddressCtrl,
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              ApplicationFormCard(
                title: 'Rental History',
                children: [
                  ApplicationTextField(
                    label: 'Previous Rental Address',
                    hint: 'Leave blank if first time renting',
                    controller: _prevAddressCtrl,
                    maxLines: 3,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationDropdown(
                    label: 'Rental Duration',
                    hint: 'Select duration',
                    value: _rentalDuration,
                    items: kRentalDurations,
                    onChanged: (v) => setState(() => _rentalDuration = v),
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Reason for Leaving',
                    hint: 'Optional',
                    controller: _reasonCtrl,
                    maxLines: 3,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Previous Landlord Name',
                    hint: 'Optional',
                    controller: _landlordNameCtrl,
                  ),
                  const SizedBox(height: kAppFieldSpacing),
                  ApplicationTextField(
                    label: 'Landlord Contact',
                    hint: 'Optional',
                    controller: _landlordContactCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: VxrSecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: VxrPrimaryButton(
                      label: _saving ? 'Saving…' : 'Save Changes',
                      onPressed: _saving ? () {} : _save,
                      fullWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
