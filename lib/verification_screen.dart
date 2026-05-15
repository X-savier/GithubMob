import 'dart:io';

import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'package:image_picker/image_picker.dart';

import 'property_data.dart';

/// AI-powered identity verification screen.
///
/// Flow:
///   0. Pick a Philippine valid ID type.
///   1. Capture the ID front (rear camera).
///   2. Capture the ID back (skipped when the chosen ID has no back data).
///   3. Capture a live selfie (front camera).
///   4. Review thumbnails and submit.
/// On submit, we upload the three images, invoke the `verify-identity`
/// Edge Function, and render the AI decision (approved / manual_review
/// / rejected) with a retry path on rejection.
///
/// Pops with `true` once the user is approved (so the calling gate can
/// proceed), `false` otherwise.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _coral = VxrTokens.accent;
  static const _bg = VxrTokens.bg;

  final _picker = ImagePicker();

  PhilippineIdType? _idType;
  XFile? _front;
  XFile? _back;
  XFile? _selfie;
  int _step = 0;

  bool _submitting = false;
  VerificationResult? _result;

  // ── Step navigation ─────────────────────────────────────────────

  /// Total interactive steps (ID type → front → [back] → selfie → review).
  int get _totalSteps => 4 + (_idType?.requiresBack == true ? 1 : 0);

  void _next() {
    if (_step >= _totalSteps - 1) return;
    setState(() => _step += 1);
  }

  void _back0() {
    if (_step == 0) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _step -= 1);
  }

  // ── Capture helpers ─────────────────────────────────────────────

  Future<void> _capture({
    required CameraDevice device,
    required ValueChanged<XFile> onPicked,
  }) async {
    final f = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: device,
      imageQuality: 85,
    );
    if (f != null) setState(() => onPicked(f));
  }

  Future<void> _captureFront() => _capture(
        device: CameraDevice.rear,
        onPicked: (f) => _front = f,
      );

  Future<void> _captureBack() => _capture(
        device: CameraDevice.rear,
        onPicked: (f) => _back = f,
      );

  Future<void> _captureSelfie() => _capture(
        device: CameraDevice.front,
        onPicked: (f) => _selfie = f,
      );

  // ── Submit ──────────────────────────────────────────────────────

  Future<void> _submit() async {
    final type = _idType;
    if (type == null || _front == null || _selfie == null) return;
    if (type.requiresBack && _back == null) return;
    setState(() => _submitting = true);
    try {
      final frontBytes = await _front!.readAsBytes();
      final selfieBytes = await _selfie!.readAsBytes();
      final backBytes =
          type.requiresBack ? await _back!.readAsBytes() : null;
      final result = await submitUserVerification(
        idType: type.key,
        idFrontBytes: frontBytes,
        idBackBytes: backBytes,
        selfieBytes: selfieBytes,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _retry() {
    setState(() {
      _result = null;
      _front = null;
      _back = null;
      _selfie = null;
      _step = 1; // back to ID-front capture (keep chosen ID type)
    });
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _result != null || _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back0();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Verify Your Identity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _result != null ? null : _back0,
          ),
        ),
        body: SafeArea(
          child: _result != null
              ? _ResultView(
                  result: _result!,
                  onRetry: _retry,
                  onClose: () =>
                      Navigator.pop(context, _result!.isApproved),
                )
              : _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return Column(
      children: [
        _ProgressBar(current: _step, total: _totalSteps),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _stepBody(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _stepFooter(),
        ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_stepName()) {
      case 'pick':
        return _PickIdStep(
          selected: _idType,
          onSelect: (t) => setState(() => _idType = t),
        );
      case 'front':
        return _CaptureStep(
          title: 'Capture ID front',
          subtitle:
              'Place your ${_idType?.displayName ?? "ID"} flat on a dark '
              'surface. Make sure all 4 corners are visible and the text '
              'is sharp.',
          icon: Icons.credit_card,
          file: _front,
          onCapture: _captureFront,
          actionLabel: _front == null ? 'Open camera' : 'Retake',
        );
      case 'back':
        return _CaptureStep(
          title: 'Capture ID back',
          subtitle:
              'Now flip the ID over and capture the back. Same lighting + '
              'all corners visible.',
          icon: Icons.flip_to_back,
          file: _back,
          onCapture: _captureBack,
          actionLabel: _back == null ? 'Open camera' : 'Retake',
        );
      case 'selfie':
        return _CaptureStep(
          title: 'Take a selfie',
          subtitle:
              'Look straight at the camera. Plain background, no sunglasses '
              'or hats. We will compare this to the photo on your ID.',
          icon: Icons.face,
          file: _selfie,
          onCapture: _captureSelfie,
          actionLabel: _selfie == null ? 'Open camera' : 'Retake',
        );
      case 'review':
        return _ReviewStep(
          idType: _idType!,
          front: _front,
          back: _back,
          selfie: _selfie,
        );
    }
    return const SizedBox.shrink();
  }

  /// Maps the integer step to a logical step name, accounting for the
  /// optional back-capture step.
  String _stepName() {
    final hasBack = _idType?.requiresBack == true;
    switch (_step) {
      case 0:
        return 'pick';
      case 1:
        return 'front';
      case 2:
        return hasBack ? 'back' : 'selfie';
      case 3:
        return hasBack ? 'selfie' : 'review';
      case 4:
        return 'review';
    }
    return 'review';
  }

  Widget _stepFooter() {
    final isLast = _stepName() == 'review';
    final canAdvance = _canAdvance();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !canAdvance || _submitting
            ? null
            : (isLast ? _submit : _next),
        style: ElevatedButton.styleFrom(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                isLast ? 'Submit for AI verification' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  bool _canAdvance() {
    switch (_stepName()) {
      case 'pick':
        return _idType != null;
      case 'front':
        return _front != null;
      case 'back':
        return _back != null;
      case 'selfie':
        return _selfie != null;
      case 'review':
        return _front != null &&
            _selfie != null &&
            (_idType?.requiresBack != true || _back != null);
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────
// Step widgets
// ─────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i <= current;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color:
                    filled ? VxrTokens.accent : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PickIdStep extends StatelessWidget {
  final PhilippineIdType? selected;
  final ValueChanged<PhilippineIdType> onSelect;
  const _PickIdStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your ID',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pick any Philippine government-issued ID. Your documents are '
          'stored privately and only used for verification.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              for (final t in kPhilippineIdTypes)
                _IdCard(
                  type: t,
                  selected: selected?.key == t.key,
                  onTap: () => onSelect(t),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdCard extends StatelessWidget {
  static const _coral = VxrTokens.accent;
  final PhilippineIdType type;
  final bool selected;
  final VoidCallback onTap;
  const _IdCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _coral : Colors.grey.shade300,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(type.icon,
                color: selected ? _coral : Colors.grey.shade700, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? _coral : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureStep extends StatelessWidget {
  static const _coral = VxrTokens.accent;
  final String title;
  final String subtitle;
  final IconData icon;
  final XFile? file;
  final VoidCallback onCapture;
  final String actionLabel;
  const _CaptureStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.file,
    required this.onCapture,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle,
            style:
                const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: file == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No photo yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : Image.file(File(file!.path), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onCapture,
          icon: const Icon(Icons.camera_alt_outlined, color: _coral),
          label: Text(actionLabel,
              style: const TextStyle(color: _coral)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _coral),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final PhilippineIdType idType;
  final XFile? front;
  final XFile? back;
  final XFile? selfie;
  const _ReviewStep({
    required this.idType,
    required this.front,
    required this.back,
    required this.selfie,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review and submit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Our AI will read your ID, compare it to your selfie, and '
            'check the name against your profile. Most accounts are '
            'approved instantly; borderline cases go to admin review.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _summaryRow(label: 'ID type', value: idType.displayName),
          const SizedBox(height: 12),
          _Thumb(label: 'ID front', file: front),
          if (idType.requiresBack) ...[
            const SizedBox(height: 8),
            _Thumb(label: 'ID back', file: back),
          ],
          const SizedBox(height: 8),
          _Thumb(label: 'Selfie', file: selfie),
        ],
      ),
    );
  }

  Widget _summaryRow({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.black54, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String label;
  final XFile? file;
  const _Thumb({required this.label, required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: file == null
                  ? Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_outlined,
                          color: Colors.grey),
                    )
                  : Image.file(File(file!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Icon(
            file == null ? Icons.error_outline : Icons.check_circle,
            color: file == null ? VxrTokens.warning : VxrTokens.accent,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Result view
// ─────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final VerificationResult result;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  const _ResultView({
    required this.result,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (result.decision) {
      'approved' => (
          const Color(0xff2e7d32),
          Icons.verified_rounded,
          'You are verified!'
        ),
      'manual_review' => (
          const Color(0xffe6a700),
          Icons.hourglass_top_rounded,
          'Pending admin review'
        ),
      'rejected' => (
          VxrTokens.accent,
          Icons.error_outline,
          'Verification failed'
        ),
      _ => (
          VxrTokens.accent,
          Icons.error_outline,
          'Something went wrong'
        ),
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          if (result.reason != null)
            Text(
              result.reason!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          const SizedBox(height: 18),
          if (result.ocrConfidence != null ||
              result.faceMatchScore != null ||
              result.nameMatchScore != null)
            _ScoreCard(
              ocr: result.ocrConfidence,
              face: result.faceMatchScore,
              name: result.nameMatchScore,
            ),
          const Spacer(),
          if (result.isRejected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VxrTokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Try again',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: VxrTokens.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: VxrTokens.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final double? ocr;
  final double? face;
  final double? name;
  const _ScoreCard({this.ocr, this.face, this.name});

  String _fmt(double? v) => v == null ? '—' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _row('ID readability', _fmt(ocr)),
          const SizedBox(height: 6),
          _row('Face match', _fmt(face)),
          const SizedBox(height: 6),
          _row('Name match', _fmt(name)),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Row(
        children: [
          Text(k,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const Spacer(),
          Text(v,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────
// Pending-state info screen
// ─────────────────────────────────────────────────────────────────

/// Read-only screen shown when the user already has a verification
/// submission sitting in 'manual_review'. Resubmission is blocked until
/// an admin finalizes the previous attempt, so this screen explains the
/// state and shows the AI scores from the last submission.
class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  static const _coral = VxrTokens.accent;
  static const _amber = VxrTokens.warning;
  static const _bg = VxrTokens.bg;

  bool _loading = true;
  Map<String, dynamic>? _row;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await getLatestVerification();
    if (!mounted) return;
    setState(() {
      _row = row;
      _loading = false;
    });
  }

  double? _num(String key) {
    final v = _row?[key];
    if (v is num) return v.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reason = _row?['decision_reason']?.toString();
    final hasScores = _num('ocr_confidence') != null ||
        _num('face_match_score') != null ||
        _num('name_match_score') != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _coral,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Verification Pending',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _coral))
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    const Icon(Icons.hourglass_top_rounded,
                        size: 80, color: _amber),
                    const SizedBox(height: 14),
                    const Text(
                      'Awaiting admin review',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _amber),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your identity submission has been received and our '
                      'AI checks have completed. Some details were borderline, '
                      'so an admin needs to take a final look before approval. '
                      'You will be notified once the review is complete — no '
                      'further action is needed from you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 18),
                    if (hasScores)
                      _ScoreCard(
                        ocr: _num('ocr_confidence'),
                        face: _num('face_match_score'),
                        name: _num('name_match_score'),
                      ),
                    if (reason != null && reason.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notes',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(reason,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Gate helpers (preserved API — callers unchanged)
// ─────────────────────────────────────────────────────────────────

/// Convenience wrapper: returns true if the user can proceed with
/// listing creation.
///
/// - Already approved        → returns true immediately.
/// - Submission pending      → shows an informational dialog, returns false.
/// - Not submitted / rejected → pushes [VerificationScreen], returns the
///   approval status when the screen pops.
Future<bool> ensureVerifiedToCreateListing(BuildContext context) async {
  if (await isCurrentUserVerified()) return true;

  if (await isUserVerificationPending()) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _pendingDialog(
          ctx,
          'create listings',
        ),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final approved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const VerificationScreen()),
  );
  return approved ?? false;
}

/// Tenant gate for submitting a rental application.
Future<bool> ensureVerifiedToApply(BuildContext context) async {
  if (await isCurrentUserVerified()) return true;

  if (await isUserVerificationPending()) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _pendingDialog(
          ctx,
          'apply for listings',
        ),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final approved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const VerificationScreen()),
  );
  return approved ?? false;
}

Widget _pendingDialog(BuildContext context, String action) {
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    title: const Row(
      children: [
        Icon(Icons.hourglass_top_rounded, color: VxrTokens.accent),
        SizedBox(width: 8),
        Text('Verification Pending'),
      ],
    ),
    content: Text(
      'Your identity submission is currently being reviewed by an admin. '
      'You will be able to $action once it is approved.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK',
            style: TextStyle(color: VxrTokens.accent)),
      ),
    ],
  );
}
