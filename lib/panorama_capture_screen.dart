import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'panorama_post_processor.dart';
import 'panorama_stitcher.dart';

const _kPrimary = Color(0xfff36c6c);
const _kCoral = Color(0xFFE8735A);

/// Guided 360° panorama capture screen using camerawesome + sensors_plus.
///
/// Uses gyroscope-driven auto-snap at configurable rotation intervals,
/// with on-device stitching via opencv_dart (Stitcher::PANORAMA mode).
///
/// Returns the stitched panorama [XFile] via Navigator.pop on success,
/// or null if the user cancels or stitching fails.
class PanoramaCaptureScreen extends StatefulWidget {
  /// ── Fix 3: Capture interval (degrees) ──
  /// Rotation between consecutive auto-captures.
  /// Tighter intervals → more frames → more overlap → better stitch quality,
  /// but also longer stitch time. 3° is the recommended floor — below this
  /// the marginal quality gain is outweighed by stitch latency.
  final double captureIntervalDeg;

  /// ── Fix 2: Speed gate threshold (degrees/second) ──
  /// Maximum angular velocity allowed during capture. When exceeded, frames
  /// are skipped to avoid motion blur. 15 deg/s matches a slow, deliberate
  /// wrist rotation and keeps each frame tack-sharp.
  final double maxSpeedDegPerSec;

  const PanoramaCaptureScreen({
    super.key,
    this.captureIntervalDeg = 10.0,
    this.maxSpeedDegPerSec = 15.0,
  });

  @override
  State<PanoramaCaptureScreen> createState() => _PanoramaCaptureScreenState();
}

class _PanoramaCaptureScreenState extends State<PanoramaCaptureScreen>
    with SingleTickerProviderStateMixin {
  // ── Capture management ──
  final List<String> _framePaths = [];
  final List<double> _frameYawDeg = []; // cumulative yaw at each capture
  int _frameCounter = 0;
  String? _tempDirPath;
  bool _sweepStarted = false;
  bool _isCapturing = false;
  bool _stitching = false;
  bool _failed = false;
  bool _enhancing = false;
  int _progress = 0;
  int _captureKey = 0;

  // ── Fix 1: AE/AF lock state ──
  bool _aefLocked = false;

  // ── Fix 2: Speed gate state ──
  bool _movingTooFast = false;

  // ── Fix 3: Gyroscope tracking ──
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  DateTime? _lastGyroTime;
  double _rotationSinceLastCapture = 0.0;
  double _totalRotation = 0.0;

  // EMA-smoothed gyro rates (rad/s). alpha ≈ 0.35 → ~3-sample time
  // constant at 60 Hz; trims handshake noise without visible lag.
  double _yawRateEma = 0.0;
  double _pitchRateEma = 0.0;
  static const double _gyroEmaAlpha = 0.35;

  // Live notifiers driven by gyro/accelerometer events. Painter widgets
  // listen to these so they repaint at sensor rate without triggering
  // a full Scaffold rebuild (which would re-init the camera widget).
  final ValueNotifier<double> _liveYaw = ValueNotifier(0.0);
  final ValueNotifier<double> _liveSinceCapture = ValueNotifier(0.0);
  final ValueNotifier<double> _livePitch = ValueNotifier(0.0);
  final ValueNotifier<double> _liveRoll = ValueNotifier(0.0);

  // ── Direction tracking ──
  // Signed rotation: positive = right (correct), negative = left (wrong)
  double _signedRotation = 0.0;
  bool _wrongDirection = false;

  // Camera reference for programmatic captures
  PhotoCameraState? _photoState;

  // How many frames were actually verified on disk
  int _validFrameCount = 0;
  // Reason shown to user when stitching fails
  String _failReason = '';

  // ── Guided capture: tilt tracking ──
  double _cumulativePitch = 0.0;
  bool _phoneNotLevel = false;

  // ── Orientation detection (pre-capture) ──
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool _phoneUpright = false;

  // ── Capture flash feedback ──
  bool _captureFlash = false;

  // ── Guided dot-by-dot capture ──
  int _nextTargetIndex = 0;
  int get _totalTargets =>
      (_targetRotationDeg / widget.captureIntervalDeg).ceil();

  // ── Pulse animation for guide dot ──
  late AnimationController _pulseController;

  // Full panorama = 360°
  static const double _targetRotationDeg = 360.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startOrientationCheck();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _pulseController.dispose();
    _liveYaw.dispose();
    _liveSinceCapture.dispose();
    _livePitch.dispose();
    _liveRoll.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // ORIENTATION DETECTION (PRE-CAPTURE)
  // ─────────────────────────────────────────────

  void _startOrientationCheck() {
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < 1.0) return;

    // Angle from perfectly upright (Y-axis aligned with gravity)
    final tiltFromUpright = math.acos(
      (event.y.abs() / magnitude).clamp(0.0, 1.0),
    ) * (180.0 / math.pi);

    // Roll = left/right lean of the phone. atan2(x, y) gives signed angle
    // from vertical: 0° when level, positive when leaning right.
    final rollDeg = math.atan2(event.x, event.y) * (180.0 / math.pi);
    _liveRoll.value = rollDeg;

    // Phone is "upright" if within 25° of vertical
    final upright = tiltFromUpright < 25.0;
    if (upright != _phoneUpright) {
      setState(() => _phoneUpright = upright);
    }
  }

  // ─────────────────────────────────────────────
  // FIX 1: LOCK AE/AF BEFORE SWEEP
  // ─────────────────────────────────────────────

  /// Focus on the center of the viewfinder first, then lock exposure
  /// and focus by suppressing further focus/metering calls. This
  /// establishes a consistent baseline for the entire panoramic sweep —
  /// preventing visible exposure banding where frames overlap after
  /// stitching.
  ///
  /// Called once on the very first frame, before the gyroscope sweep
  /// begins. The lock persists for the entire sweep duration and is
  /// released after stitching completes.
  ///
  /// camerawesome 2.x does not expose ExposureMode/FocusMode enums.
  /// Instead we use focusOnPoint() to meter the scene center, then
  /// set the [_aefLocked] flag so that no further metering calls are
  /// issued during the sweep. The platform camera (Camera2 / AVFoundation)
  /// will hold its last AE/AF values until a new tap-to-focus arrives.
  Future<void> _lockAeAf(PhotoCameraState photoState) async {
    if (_aefLocked) return;

    try {
      // Step 1: Focus + meter on the center of the frame.
      // This gives the camera a chance to converge on the best exposure
      // and focus for the current scene before we freeze the values.
      // We need PreviewSize instances for the pixel and flutter sizes.
      // Using a 1×1 normalised coordinate space for the tap point.
      await photoState.focusOnPoint(
        flutterPosition: const Offset(0.5, 0.5),
        pixelPreviewSize: PreviewSize(width: 1.0, height: 1.0),
        flutterPreviewSize: PreviewSize(width: 1.0, height: 1.0),
      );

      // Wait for the AE/AF algorithms to converge. 400 ms is enough for
      // most sensors; on very dark scenes you may need longer.
      await Future.delayed(const Duration(milliseconds: 400));

      // Step 2: Mark as locked — we stop issuing any further
      // focusOnPoint / tap-to-focus calls for the rest of the sweep.
      // The platform camera holds the last AE/AF lock after a
      // tap-to-focus until a new one is requested.
      _aefLocked = true;
      debugPrint('[Panorama] AE/AF locked for sweep');
    } catch (e) {
      // Some devices / OS versions may not support programmatic focus.
      // Continue anyway — the panorama will still work, with potential
      // exposure inconsistencies at stitch boundaries.
      debugPrint('[Panorama] AE/AF lock failed (non-fatal): $e');
    }
  }

  /// Unlock AE/AF after stitching completes so subsequent captures
  /// return to normal auto-metering behaviour.
  void _unlockAeAf() {
    if (!_aefLocked) return;
    _aefLocked = false;
    debugPrint('[Panorama] AE/AF unlocked');
  }

  // ─────────────────────────────────────────────
  // FIX 2 & 3: GYROSCOPE HANDLING
  // ─────────────────────────────────────────────

  /// Start listening to gyroscope events for rotation tracking
  /// and auto-capture triggering.
  void _startGyroscope() {
    _lastGyroTime = DateTime.now();
    _rotationSinceLastCapture = 0.0;
    _totalRotation = 0.0;
    _signedRotation = 0.0;
    _wrongDirection = false;
    _cumulativePitch = 0.0;
    _phoneNotLevel = false;
    _yawRateEma = 0.0;
    _pitchRateEma = 0.0;
    _liveYaw.value = 0.0;
    _liveSinceCapture.value = 0.0;
    _livePitch.value = 0.0;
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onGyroscopeEvent);
  }

  void _onGyroscopeEvent(GyroscopeEvent event) {
    if (!_sweepStarted || _stitching) return;

    final now = DateTime.now();
    final dt = _lastGyroTime != null
        ? (now.difference(_lastGyroTime!).inMicroseconds / 1e6)
        : 0.0;
    _lastGyroTime = now;

    // Skip unreasonably large dt (first event, or app resumed from bg).
    if (dt <= 0 || dt > 0.5) return;

    // ── Fix 2: Speed gate ──
    // Angular velocity magnitude from all three gyro axes (rad/s → deg/s).
    // sqrt(x² + y² + z²) gives the total rotational speed regardless of
    // which axis the phone is rotating around.
    final speedRadPerSec = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final speedDegPerSec = speedRadPerSec * (180.0 / math.pi);

    final tooFast = speedDegPerSec > widget.maxSpeedDegPerSec;
    if (tooFast != _movingTooFast) {
      setState(() => _movingTooFast = tooFast);
    }

    // If moving too fast, skip accumulation — the frame would be blurred.
    if (tooFast) return;

    // EMA on raw rates: removes handshake noise so the integrated yaw
    // we tag onto each frame is clean. Speed gate above intentionally
    // uses raw values for instant reaction; smoothing is for accumulation.
    _yawRateEma = _gyroEmaAlpha * event.y + (1 - _gyroEmaAlpha) * _yawRateEma;
    _pitchRateEma = _gyroEmaAlpha * event.x + (1 - _gyroEmaAlpha) * _pitchRateEma;

    // ── Fix 3: Rotation accumulation ──
    // Integrate smoothed gyro.y (yaw axis in portrait) over time.
    final rotationDeg = (_yawRateEma * dt) * (180.0 / math.pi);
    _rotationSinceLastCapture += rotationDeg.abs();
    _totalRotation += rotationDeg.abs();
    _signedRotation += rotationDeg;

    // Push live values to notifiers — painters listen at 60 Hz without
    // forcing a Scaffold rebuild.
    _liveYaw.value = _totalRotation;
    _liveSinceCapture.value = _rotationSinceLastCapture;

    // Direction check: going left (negative) is wrong direction
    final goingWrong = rotationDeg < -0.3;
    if (goingWrong != _wrongDirection) {
      setState(() => _wrongDirection = goingWrong);
    }

    // Track vertical tilt — warn if phone is not level
    final pitchDeg = (_pitchRateEma * dt) * (180.0 / math.pi);
    _cumulativePitch += pitchDeg;
    _livePitch.value = _cumulativePitch;
    final notLevel = _cumulativePitch.abs() > 15;
    if (notLevel != _phoneNotLevel) {
      setState(() => _phoneNotLevel = notLevel);
    }

    // Update progress (0–99 during capture, 100 reserved for stitch phase)
    final newProgress =
        ((_totalRotation / _targetRotationDeg) * 100).clamp(0, 99).toInt();
    if (newProgress != _progress) {
      setState(() => _progress = newProgress);
    }

    // ── Target-based capture: snap when reaching the next dot position ──
    if (_nextTargetIndex <= _totalTargets) {
      final nextAngle = _nextTargetIndex * widget.captureIntervalDeg;
      if (_totalRotation >= nextAngle && !_isCapturing) {
        _nextTargetIndex++;
        _captureFrame();
      }
    }

    // Auto-finish when full rotation is reached
    if (_totalRotation >= _targetRotationDeg) {
      _finishCapture();
    }
  }

  // ─────────────────────────────────────────────
  // CAPTURE & STITCHING
  // ─────────────────────────────────────────────

  /// Generate the next frame's save path for camerawesome's pathBuilder.
  Future<SingleCaptureRequest> _buildCapturePath(
      List<Sensor> sensors) async {
    _tempDirPath ??= (await getTemporaryDirectory()).path;
    final path = '$_tempDirPath/pano_frame_${_frameCounter++}.jpg';
    _framePaths.add(path);
    return SingleCaptureRequest(path, sensors.first);
  }

  /// Begin the panoramic sweep: lock AE/AF, snap the first frame,
  /// then start the gyroscope listener.
  Future<void> _startSweep() async {
    if (_sweepStarted) return;
    final state = _photoState;
    if (state == null) return;

    // Fix 1: Lock AE/AF on the initial scene before the sweep
    await _lockAeAf(state);

    // Capture the anchor frame immediately
    await _captureFrame();

    setState(() {
      _sweepStarted = true;
      _nextTargetIndex = 1; // next target after anchor frame
    });
    _startGyroscope();
  }

  /// Capture a single frame via camerawesome.
  Future<void> _captureFrame() async {
    final state = _photoState;
    if (state == null || _stitching || _isCapturing) return;

    _isCapturing = true;
    try {
      final countBefore = _framePaths.length;
      await state.takePhoto();

      // Verify the file was actually written to disk.
      if (_framePaths.length > countBefore) {
        final lastPath = _framePaths.last;
        final file = File(lastPath);
        if (file.existsSync() && file.lengthSync() > 0) {
          _validFrameCount++;
          _frameYawDeg.add(_totalRotation); // record gyro yaw for this frame
          // Reset the per-capture rotation accumulator so the next-target
          // reticle slides back to the right edge instead of parking in
          // the middle.
          _rotationSinceLastCapture = 0.0;
          _liveSinceCapture.value = 0.0;
          HapticFeedback.lightImpact();
          _showCaptureFlash();
          debugPrint(
              '[Panorama] Frame $_validFrameCount saved '
              '(${file.lengthSync()} bytes, yaw=${_totalRotation.toStringAsFixed(1)}°): $lastPath');
        } else {
          _framePaths.removeLast();
          debugPrint('[Panorama] Frame file missing or empty: $lastPath');
        }
      }
    } catch (e) {
      debugPrint('[Panorama] Frame capture failed: $e');
    } finally {
      _isCapturing = false;
    }
  }

  void _showCaptureFlash() {
    setState(() => _captureFlash = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _captureFlash = false);
    });
  }

  /// Stop capturing and begin on-device stitching.
  Future<void> _finishCapture() async {
    if (_stitching) return;

    _gyroSub?.cancel();
    setState(() {
      _sweepStarted = false;
      _stitching = true;
      _progress = 100;
    });

    HapticFeedback.heavyImpact();

    if (_framePaths.length < 2) {
      setState(() {
        _stitching = false;
        _failed = true;
        _failReason = 'Not enough frames were captured '
            '(${_framePaths.length} registered, $_validFrameCount on disk). '
            'Hold the device steady and rotate slowly.';
      });
      return;
    }

    try {
      // Short delay to let the OS flush the last JPEG write to disk.
      await Future.delayed(const Duration(milliseconds: 500));

      // Filter to files that actually exist and are non-empty.
      final validPaths = _framePaths.where((p) {
        final f = File(p);
        return f.existsSync() && f.lengthSync() > 0;
      }).toList();

      debugPrint('[Panorama] Paths registered: ${_framePaths.length}, '
          'valid files on disk: ${validPaths.length}');

      if (validPaths.length < 2) {
        setState(() {
          _stitching = false;
          _failed = true;
          _failReason = 'Only ${validPaths.length} photo(s) were saved to '
              'disk out of ${_framePaths.length} attempted. '
              'The camera may not have had time to save each frame.';
        });
        return;
      }

      // Stitch in an isolate so the UI stays responsive.
      // Timeout after 90 s for large frame sets.
      final stitchInput = StitchInput(
        framePaths: validPaths,
        frameYawDeg: _frameYawDeg.length >= validPaths.length
            ? _frameYawDeg.sublist(0, validPaths.length)
            : _frameYawDeg,
      );
      final resultPath = await compute(PanoramaStitcher.stitchIsolate, stitchInput)
          .timeout(const Duration(seconds: 180));

      // Fix 1: Unlock AE/AF now that stitching is complete
      _unlockAeAf();

      if (resultPath != null && mounted) {
        setState(() {
          _stitching = false;
          _enhancing = true;
        });

        // Quality analysis with capture metadata
        final panoramaFile = File(resultPath);
        final metadata = PanoramaCaptureMetadata(
          totalRotationDeg: _totalRotation,
          validFrameCount: _validFrameCount,
          captureIntervalDeg: widget.captureIntervalDeg,
        );
        final score = await PanoramaQualityAnalyzer.analyze(
          panoramaFile,
          metadata: metadata,
        );

        if (mounted) {
          setState(() => _enhancing = false);
          _showQualityResult(panoramaFile, score);
        }
      } else {
        _unlockAeAf();
        if (mounted) {
          setState(() {
            _stitching = false;
            _failed = true;
            _failReason = 'The stitcher could not align the frames. '
                'Try rotating more slowly with steady hands.';
          });
        }
      }
    } on TimeoutException {
      debugPrint('[Panorama] Stitch timed out after 180 s');
      _unlockAeAf();
      if (mounted) {
        setState(() {
          _stitching = false;
          _failed = true;
          _failReason = 'Stitching took too long and was cancelled. '
              'Try capturing fewer frames by finishing early.';
        });
      }
    } catch (e) {
      debugPrint('[Panorama] Stitching failed: $e');
      _unlockAeAf();
      if (mounted) {
        setState(() {
          _stitching = false;
          _failed = true;
          _failReason = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // QUALITY RESULT (unchanged from original)
  // ─────────────────────────────────────────────

  void _showQualityResult(File enhanced, PanoramaQualityScore score) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _QualityResultSheet(
        score: score,
        onAccept: () {
          Navigator.pop(ctx);
          Navigator.pop(context, XFile(enhanced.path));
        },
        onRetake: () {
          Navigator.pop(ctx);
          _resetCapture();
        },
      ),
    );
  }

  /// Reset all state for a retake attempt.
  void _resetCapture() {
    _framePaths.clear();
    _frameYawDeg.clear();
    _frameCounter = 0;
    _validFrameCount = 0;
    setState(() {
      _captureKey++;
      _failed = false;
      _failReason = '';
      _stitching = false;
      _enhancing = false;
      _sweepStarted = false;
      _progress = 0;
      _movingTooFast = false;
      _wrongDirection = false;
      _phoneNotLevel = false;
      _cumulativePitch = 0.0;
      _aefLocked = false;
      _phoneUpright = false;
      _captureFlash = false;
      _nextTargetIndex = 0;
      _photoState = null;
    });
    _startOrientationCheck();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final screenSize = MediaQuery.of(context).size;
    final isPreCapture =
        !_sweepStarted && !_stitching && !_failed && !_enhancing;

    // Camera preview rectangle dimensions
    final cameraW = screenSize.width * 0.75;
    final cameraH = cameraW * (4.0 / 3.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera layer (clipped to center rectangle) ──
          if (!_failed && !_stitching && !_enhancing)
            Center(
              child: Container(
                width: cameraW,
                height: cameraH,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_captureKey),
                  child: CameraAwesomeBuilder.custom(
                    saveConfig: SaveConfig.photo(
                      pathBuilder: _buildCapturePath,
                    ),
                    sensorConfig: SensorConfig.single(
                      sensor: Sensor.position(SensorPosition.back),
                      flashMode: FlashMode.none,
                      aspectRatio: CameraAspectRatios.ratio_4_3,
                    ),
                    builder: _buildCameraUI,
                  ),
                ),
              ),
            ),

          // ── 3D cylindrical dot grid (trajectory guide + captured coverage) ──
          if (!_stitching && !_failed && !_enhancing && _photoState != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _liveYaw,
                  builder: (_, liveYaw, _) {
                    return CustomPaint(
                      painter: _CylindricalDotGridPainter(
                        progress: _sweepStarted
                            ? liveYaw / _targetRotationDeg
                            : 0.0,
                        cameraRect: Rect.fromCenter(
                          center: Offset(screenSize.width / 2,
                              screenSize.height / 2),
                          width: cameraW,
                          height: cameraH,
                        ),
                        isWrongDirection: _wrongDirection,
                        sweepActive: _sweepStarted,
                        frameYaws: _frameYawDeg,
                        totalTargetDeg: _targetRotationDeg,
                        nextTargetAngle: _sweepStarted
                            ? _nextTargetIndex * widget.captureIntervalDeg
                            : null,
                        captureIntervalDeg: widget.captureIntervalDeg,
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Camera border (always visible when camera ready) ──
          if (!_failed && !_stitching && !_enhancing && _photoState != null)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: cameraW,
                  height: cameraH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),

          // ── Center eye target (during sweep) ──
          if (_sweepStarted && !_stitching && !_failed)
            Center(
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(56, 56),
                  painter: _EyeTargetPainter(),
                ),
              ),
            ),

          // ── Animated direction pulse INSIDE camera rect, left edge ──
          if (_sweepStarted && !_stitching && !_failed)
            Positioned(
              top: screenSize.height / 2 - 16,
              left: screenSize.width / 2 - cameraW / 2 + 14,
              child: IgnorePointer(
                child: _DirectionPulse(wrongDirection: _wrongDirection),
              ),
            ),

          // ── Sliding next-target reticle (right edge → center) ──
          if (_sweepStarted && !_stitching && !_failed)
            Positioned(
              top: screenSize.height / 2 - 16,
              left: screenSize.width / 2 - cameraW / 2,
              child: IgnorePointer(
                child: _NextTargetReticle(
                  sinceCapture: _liveSinceCapture,
                  intervalDeg: widget.captureIntervalDeg,
                  cameraWidth: cameraW,
                  wrongDirection: _wrongDirection,
                ),
              ),
            ),

          // ── Ghost-frame guide drifting from right edge to center ──
          if (_sweepStarted && !_stitching && !_failed)
            Center(
              child: IgnorePointer(
                child: _GhostFrameGuide(
                  sinceCapture: _liveSinceCapture,
                  intervalDeg: widget.captureIntervalDeg,
                  cameraWidth: cameraW,
                  cameraHeight: cameraH,
                  wrongDirection: _wrongDirection,
                ),
              ),
            ),

          // ── Tilting horizon line across the camera viewport ──
          if (_sweepStarted && !_stitching && !_failed)
            Positioned(
              top: screenSize.height / 2 - 12,
              left: screenSize.width / 2 - cameraW / 2,
              child: IgnorePointer(
                child: _HorizonLine(roll: _liveRoll, width: cameraW),
              ),
            ),

          // ── Live progress gauge (top of screen, replaces empty bar) ──
          if (_sweepStarted && !_stitching && !_failed)
            Positioned(
              top: pad.top + 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: _HorizontalProgressGauge(
                  yaw: _liveYaw,
                  capturedYaws: _frameYawDeg,
                  targetDeg: _targetRotationDeg,
                  wrongDirection: _wrongDirection,
                ),
              ),
            ),

          // ── Live tilt/level bubble (under progress gauge) ──
          if (_sweepStarted && !_stitching && !_failed)
            Positioned(
              top: pad.top + 70,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: _TiltBubble(roll: _liveRoll),
                ),
              ),
            ),

          // ── Capture flash ──
          if (_captureFlash)
            IgnorePointer(
              child:
                  Container(color: Colors.white.withValues(alpha: 0.5)),
            ),

          // ── Speed gate warning ──
          if (_movingTooFast && _sweepStarted)
            Positioned(
              top: pad.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Too fast — slow down',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Tilt warning ──
          if (_phoneNotLevel && _sweepStarted)
            Positioned(
              top: pad.top + (_movingTooFast ? 100 : 60),
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Keep phone level',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Top bar ──
          Positioned(
            top: pad.top + 8,
            left: 10,
            right: 10,
            child: Row(
              children: [
                // Status dot during sweep
                if (_sweepStarted && !_stitching && !_failed)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _wrongDirection
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                const Spacer(),
                // Close button
                if (!_stitching && !_enhancing)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),
                      child: Icon(Icons.close,
                          color: Colors.grey.shade600, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          // ── Pre-capture: orientation check overlay ──
          if (isPreCapture && _photoState != null)
            _buildUprightOverlay(cameraW, cameraH),

          // ── Pre-capture bottom button (not upright = red, shown always) ──
          if (isPreCapture && _photoState != null && !_phoneUpright)
            Positioned(
              bottom: pad.bottom + 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 4),
                    color: _kCoral,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 30),
                ),
              ),
            ),

          // ── Captured frame thumbnail + count (during sweep) ──
          if (_sweepStarted && _framePaths.isNotEmpty &&
              !_stitching && !_failed)
            Positioned(
              bottom: pad.bottom + 104,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.file(
                          File(_framePaths.last),
                          width: 36,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 72,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_validFrameCount / ${_totalTargets + 1}',
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom bar (during sweep) ──
          if (_sweepStarted && !_stitching && !_failed)
            Positioned(
              bottom: pad.bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 56),
                  const Spacer(),
                  // Finish Early button
                  GestureDetector(
                    onTap: _validFrameCount >= 2
                        ? _finishCapture
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _validFrameCount >= 2
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade400,
                            boxShadow: [
                              if (_validFrameCount >= 2)
                                BoxShadow(
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.check,
                                color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Finish',
                          style: GoogleFonts.inter(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Undo button
                  GestureDetector(
                    onTap: _resetCapture,
                    child: const Icon(Icons.undo,
                        color: Colors.black54, size: 28),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

          // ── Stitching overlay ──
          if (_stitching) _buildStitchingOverlay(),

          // ── Enhancing overlay ──
          if (_enhancing) _buildEnhancingOverlay(),

          // ── Failure state ──
          if (_failed) _buildFailedState(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CAMERA UI BUILDER
  // ─────────────────────────────────────────────

  Widget _buildCameraUI(CameraState state, AnalysisPreview preview) {
    state.when(
      onPhotoMode: (photoState) {
        if (_photoState != photoState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _photoState != photoState) {
              setState(() => _photoState = photoState);
            }
          });
        }
      },
    );

    if (state is PreparingCameraState) {
      return _buildCameraLoading();
    }

    return const SizedBox.expand();
  }

  // ─────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────

  Widget _buildUprightOverlay(double cameraW, double cameraH) {
    if (!_phoneUpright) {
      // Phone is NOT upright — show instruction overlay on camera rect
      return Center(
        child: Container(
          width: cameraW,
          height: cameraH,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Green phone illustration (matching reference)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.screen_rotation_alt,
                    color: const Color(0xFF4CAF50), size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                'Hold your phone upright in',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'portrait mode',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone IS upright — show ready state with start button
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 30,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PRESS TO START',
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Icon(Icons.keyboard_arrow_down,
              color: Colors.black54, size: 24),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _startSweep,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 4),
                color: const Color(0xFF4CAF50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt,
                  color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchingOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: _kCoral,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Stitching panorama...',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_framePaths.length} frames captured — combining now',
              style:
                  GoogleFonts.inter(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancingOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: _kCoral,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Analyzing quality...',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Checking your panorama',
              style:
                  GoogleFonts.inter(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLoading() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
                color: _kCoral, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style:
                  GoogleFonts.inter(color: Colors.black45, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 56, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              Text(
                'Stitching Failed',
                style: GoogleFonts.outfit(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _failReason.isNotEmpty
                    ? _failReason
                    : 'The photos could not be combined into a panorama.\n'
                        'Try again with more overlap between photos and\n'
                        'keep the camera steady while rotating.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.black45,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black54,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter()),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _resetCapture,
                    icon: const Icon(Icons.refresh, size: 18),
                    label:
                        Text('Try Again', style: GoogleFonts.inter()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kCoral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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

// ─────────────────────────────────────────────
// CYLINDRICAL DOT GRID PAINTER (3D Perspective)
// ─────────────────────────────────────────────

/// Draws a full-width cylindrical dot grid with true 3D perspective.
/// The grid represents the inside of a panoramic cylinder projected
/// onto the screen. Rows converge toward the horizontal center at edges
/// (vanishing-point perspective), dots shrink and fade with distance,
/// and the captured portion is highlighted.
class _CylindricalDotGridPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Rect cameraRect;
  final bool isWrongDirection;
  final bool sweepActive;
  final List<double> frameYaws;
  final double totalTargetDeg;
  final double? nextTargetAngle;
  final double captureIntervalDeg;

  _CylindricalDotGridPainter({
    required this.progress,
    required this.cameraRect,
    required this.isWrongDirection,
    this.sweepActive = false,
    this.frameYaws = const [],
    this.totalTargetDeg = 360.0,
    this.nextTargetAngle,
    this.captureIntervalDeg = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accentColor = isWrongDirection
        ? Colors.red.shade400
        : const Color(0xFF4DD0E1);

    const baseDotSize = 4.5;
    const colSpacing = 19.0;
    const rowCount = 28; // number of dot rows in band

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Vertical extent of the band at the center (camera position)
    final maxHalfH = cameraRect.height / 2 + 120;

    // Perspective angle controls convergence strength
    // Higher = more dramatic convergence at edges
    const maxPerspAngle = math.pi / 2.6; // ~69°

    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Horizontal scroll offset. As the user rotates right, the dot
    // columns slide left — matching the apparent motion of the real
    // world through the camera viewport. Wrap modulo colSpacing so the
    // grid stays uniformly filled across the screen.
    final scrollRaw = -progress * size.width * 2.0;
    final scrollOffset = scrollRaw % colSpacing;

    // ── Draw the dot grid columns ──
    for (double x = -15.0 + scrollOffset;
        x <= size.width + 15.0;
        x += colSpacing) {
      // Normalized distance from center: 0 = center, 1 = edge
      final u = (x - cx) / (size.width / 2);
      final uAbs = u.abs().clamp(0.0, 1.5);

      // Perspective scale: cos curve gives natural 3D convergence
      // Band height shrinks at edges → rows converge toward cy
      final perspScale = math.cos(uAbs * maxPerspAngle);
      if (perspScale <= 0.04) continue;

      // Band half-height at this column
      final halfH = maxHalfH * perspScale;

      // Dot size shrinks with perspective (less aggressively)
      final ds = baseDotSize * perspScale.clamp(0.45, 1.0);

      // Atmospheric fade: gentle opacity decrease at edges
      final edgeFade = (1.0 - uAbs * 0.35).clamp(0.2, 1.0);

      // Determine if this column falls in captured territory
      bool isCaptured = false;
      if (sweepActive && progress > 0.001) {
        // The panorama wraps: right side first, then left side
        // Map progress 0..1 to full 360° around the cylinder
        if (x > cameraRect.right) {
          final rightRange = size.width - cameraRect.right;
          if (rightRange > 0) {
            final frac = (x - cameraRect.right) / rightRange;
            isCaptured = frac <= (progress * 2.0).clamp(0.0, 1.0);
          }
        } else if (x < cameraRect.left && progress > 0.45) {
          final leftFrac = ((cameraRect.left - x) / cameraRect.left).clamp(0.0, 1.0);
          final leftProgress = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
          isCaptured = leftFrac <= leftProgress;
        }
      }

      // Draw rows distributed within the band
      for (int r = 0; r <= rowCount; r++) {
        final v = -1.0 + 2.0 * r / rowCount; // -1 (top) to +1 (bottom)
        final y = cy + v * halfH;

        // Skip dots inside camera rectangle
        if (x > cameraRect.left - 5 && x < cameraRect.right + 5 &&
            y > cameraRect.top - 5 && y < cameraRect.bottom + 5) {
          continue;
        }

        // Skip off-screen
        if (y < -8 || y > size.height + 8) continue;

        if (isCaptured) {
          dotPaint.color = accentColor.withValues(alpha: 0.9 * edgeFade);
        } else {
          // Full trajectory guide — always visible, matching reference brightness
          dotPaint.color = accentColor.withValues(alpha: 0.55 * edgeFade);
        }

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x, y),
            width: ds,
            height: ds,
          ),
          dotPaint,
        );
      }
    }

    // ── Capture position tick marks ──
    // Show small bright marks at each frame capture position
    if (sweepActive && frameYaws.isNotEmpty) {
      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      for (final yaw in frameYaws) {
        final f = (yaw / totalTargetDeg).clamp(0.0, 1.0);
        final tx = _yawToScreenX(f, size);

        if (tx < -5 || tx > size.width + 5) continue;

        // Get the perspective scale at this position
        final tu = ((tx - cx) / (size.width / 2)).abs().clamp(0.0, 1.5);
        final tPersp = math.cos(tu * maxPerspAngle);
        if (tPersp <= 0.04) continue;

        final tickSize = 3.0 * tPersp.clamp(0.3, 1.0);
        canvas.drawCircle(Offset(tx, cy), tickSize, tickPaint);
      }
    }

    // ── Target position markers (capture dots the user aims for) ──
    if (sweepActive) {
      final totalTargets =
          (totalTargetDeg / captureIntervalDeg).ceil();
      for (int t = 0; t <= totalTargets; t++) {
        final angle = t * captureIntervalDeg;
        final f = (angle / totalTargetDeg).clamp(0.0, 1.0);
        final tx = _yawToScreenX(f, size);

        if (tx < -5 || tx > size.width + 5) continue;
        // Skip markers inside camera rect
        if (tx > cameraRect.left + 5 && tx < cameraRect.right - 5) {
          continue;
        }

        final tu =
            ((tx - cx) / (size.width / 2)).abs().clamp(0.0, 1.5);
        final tPersp = math.cos(tu * maxPerspAngle);
        if (tPersp <= 0.04) continue;

        final isCapturedTarget = frameYaws.any(
            (yaw) => (yaw - angle).abs() < captureIntervalDeg * 0.8);
        final isNextTarget = nextTargetAngle != null &&
            (angle - nextTargetAngle!).abs() < 0.5;

        if (isNextTarget) {
          // Next target: bright ring the user is aiming for
          final ringPaint = Paint()
            ..color = const Color(0xFF4DD0E1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * tPersp.clamp(0.5, 1.0);
          canvas.drawCircle(
              Offset(tx, cy), 8 * tPersp.clamp(0.5, 1.0), ringPaint);
          final fillPaint = Paint()
            ..color =
                const Color(0xFF4DD0E1).withValues(alpha: 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
              Offset(tx, cy), 6 * tPersp.clamp(0.5, 1.0), fillPaint);
        } else if (isCapturedTarget) {
          // Captured: solid bright dot
          final capPaint = Paint()
            ..color = accentColor.withValues(
                alpha:
                    0.9 * (1.0 - tu * 0.3).clamp(0.3, 1.0))
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
              Offset(tx, cy), 5 * tPersp.clamp(0.4, 1.0), capPaint);
        } else {
          // Future target: dim dot
          final futurePaint = Paint()
            ..color = accentColor.withValues(
                alpha:
                    0.25 * (1.0 - tu * 0.3).clamp(0.2, 1.0))
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
              Offset(tx, cy), 4 * tPersp.clamp(0.4, 1.0), futurePaint);
        }
      }
    }

    // ── Top/bottom boundary curves ──
    // Draw faint curved lines along the top and bottom edges of the
    // dot band to reinforce the cylindrical perspective shape
    _drawBoundaryCurve(canvas, size, cx, cy, maxHalfH, maxPerspAngle,
        -1.0, accentColor); // top
    _drawBoundaryCurve(canvas, size, cx, cy, maxHalfH, maxPerspAngle,
        1.0, accentColor); // bottom
  }

  /// Maps a yaw fraction (0..1) to a screen X position.
  double _yawToScreenX(double f, Size size) {
    if (f <= 0.5) {
      // Right side: 0% at camera right, 50% at screen right
      return cameraRect.right + f * 2.0 * (size.width - cameraRect.right);
    } else {
      // Left side: 50% at x=0, 100% at camera left
      return (f - 0.5) * 2.0 * cameraRect.left;
    }
  }

  /// Draws a faint curved line along one boundary of the dot band.
  void _drawBoundaryCurve(Canvas canvas, Size size, double cx, double cy,
      double maxHalfH, double maxPerspAngle, double side, Color color) {
    final path = Path();
    bool first = true;

    for (double x = 0; x <= size.width; x += 3.0) {
      final uAbs = ((x - cx) / (size.width / 2)).abs().clamp(0.0, 1.5);
      final perspScale = math.cos(uAbs * maxPerspAngle);
      if (perspScale <= 0.04) continue;

      final y = cy + side * maxHalfH * perspScale;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    final curvePaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(_CylindricalDotGridPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isWrongDirection != isWrongDirection ||
      oldDelegate.sweepActive != sweepActive ||
      oldDelegate.frameYaws.length != frameYaws.length ||
      oldDelegate.nextTargetAngle != nextTargetAngle;
}

// ─────────────────────────────────────────────
// EYE TARGET PAINTER
// ─────────────────────────────────────────────

class _EyeTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring (gray)
    final outerRing = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, 22, outerRing);

    // White fill behind inner dot
    final whiteFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, whiteFill);

    // Inner dark dot
    final innerDot = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, innerDot);

    // Tiny white highlight
    final highlight = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(center.dx - 3, center.dy - 3), 3, highlight);
  }

  @override
  bool shouldRepaint(_EyeTargetPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// QUALITY RESULT BOTTOM SHEET
// ─────────────────────────────────────────────

class _QualityResultSheet extends StatelessWidget {
  final PanoramaQualityScore score;
  final VoidCallback onAccept;
  final VoidCallback onRetake;

  const _QualityResultSheet({
    required this.score,
    required this.onAccept,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final overall = score.overall;
    final tips = score.tips;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < score.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: i < score.stars ? Colors.amber : Colors.white24,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Label
          Text(
            score.label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quality Score: ${overall.round()}%',
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Score bars
          _ScoreBar(
            label: '360° Coverage',
            value: score.angularCoverage,
            icon: Icons.rotate_right,
          ),
          const SizedBox(height: 10),
          _ScoreBar(
            label: 'Stitch Quality',
            value: score.stitchIntegrity,
            icon: Icons.auto_fix_high,
          ),
          const SizedBox(height: 10),
          _ScoreBar(
            label: 'Black Regions',
            value: score.blackRegions,
            icon: Icons.grid_off,
          ),
          const SizedBox(height: 10),
          _ScoreBar(
            label: 'Overlap',
            value: score.overlapQuality,
            icon: Icons.compare,
          ),
          const SizedBox(height: 10),
          _ScoreBar(
            label: 'Sharpness',
            value: score.sharpness,
            icon: Icons.center_focus_strong,
          ),
          const SizedBox(height: 10),
          _ScoreBar(
            label: 'Lighting',
            value: score.exposure,
            icon: Icons.wb_sunny_outlined,
          ),

          // Tips
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.lightbulb_outline,
                            color: Colors.amber, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              if (overall < 75) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('Retake', style: GoogleFonts.inter()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    overall >= 75 ? 'Use Panorama' : 'Use Anyway',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kCoral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE BAR WIDGET
// ─────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = value >= 75
        ? Colors.greenAccent
        : value >= 50
            ? Colors.amber
            : Colors.redAccent;

    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// LIVE MOTION-DRIVEN GUIDANCE WIDGETS
// ─────────────────────────────────────────────

/// Horizontal progress gauge that travels with the user's rotation.
/// Filled portion grows left-to-right as totalYaw approaches 360°; a
/// glowing needle marks current position; small ticks below mark each
/// captured frame's yaw.
class _HorizontalProgressGauge extends StatelessWidget {
  final ValueListenable<double> yaw;
  final List<double> capturedYaws;
  final double targetDeg;
  final bool wrongDirection;
  const _HorizontalProgressGauge({
    required this.yaw,
    required this.capturedYaws,
    required this.targetDeg,
    required this.wrongDirection,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: yaw,
      builder: (_, v, _) {
        return CustomPaint(
          size: const Size.fromHeight(56),
          painter: _ProgressGaugePainter(
            yaw: v,
            targetDeg: targetDeg,
            capturedYaws: capturedYaws,
            wrongDirection: wrongDirection,
          ),
        );
      },
    );
  }
}

class _ProgressGaugePainter extends CustomPainter {
  final double yaw;
  final double targetDeg;
  final List<double> capturedYaws;
  final bool wrongDirection;
  _ProgressGaugePainter({
    required this.yaw,
    required this.targetDeg,
    required this.capturedYaws,
    required this.wrongDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const padX = 24.0;
    final barY = h * 0.5;
    final barW = w - padX * 2;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padX, barY - 6, barW, 12),
      const Radius.circular(6),
    );

    // Track
    canvas.drawRRect(
      barRect,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // Major tick marks every 30°
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    for (int deg = 0; deg <= targetDeg.toInt(); deg += 30) {
      final x = padX + (deg / targetDeg) * barW;
      canvas.drawLine(
        Offset(x, barY - 9),
        Offset(x, barY + 9),
        tickPaint,
      );
    }

    // Filled portion up to current yaw
    final clampedYaw = yaw.clamp(0.0, targetDeg).toDouble();
    final fillW = (clampedYaw / targetDeg) * barW;
    if (fillW > 0) {
      canvas.save();
      canvas.clipRRect(barRect);
      final fillColor = wrongDirection
          ? const Color(0xFFFF6B6B)
          : const Color(0xFFE8735A);
      canvas.drawRect(
        Rect.fromLTWH(padX, barY - 6, fillW, 12),
        Paint()
          ..shader = LinearGradient(
            colors: [
              fillColor.withValues(alpha: 0.8),
              fillColor,
            ],
          ).createShader(Rect.fromLTWH(padX, barY - 6, fillW, 12)),
      );
      canvas.restore();
    }

    // Captured-frame markers
    for (final cy in capturedYaws) {
      final x = padX + (cy.clamp(0.0, targetDeg) / targetDeg) * barW;
      canvas.drawCircle(
        Offset(x, barY + 18),
        2.4,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // Traveling needle at current yaw
    final needleX = padX + (clampedYaw / targetDeg) * barW;
    final needleColor =
        wrongDirection ? const Color(0xFFFF6B6B) : Colors.white;
    canvas.drawCircle(
      Offset(needleX, barY),
      9,
      Paint()..color = needleColor.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      Offset(needleX, barY),
      5,
      Paint()..color = needleColor,
    );

    // Degree label above the needle
    final tp = TextPainter(
      text: TextSpan(
        text: '${clampedYaw.round()}°',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(needleX - tp.width / 2, barY - 28));
  }

  @override
  bool shouldRepaint(covariant _ProgressGaugePainter old) =>
      old.yaw != yaw ||
      old.wrongDirection != wrongDirection ||
      old.capturedYaws.length != capturedYaws.length;
}

/// Live spirit-level bubble. Ball drifts horizontally with phone roll;
/// glows green when within ±2°.
class _TiltBubble extends StatelessWidget {
  final ValueListenable<double> roll;
  const _TiltBubble({required this.roll});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: roll,
      builder: (_, r, _) {
        return CustomPaint(
          size: const Size(120, 18),
          painter: _TiltBubblePainter(rollDeg: r),
        );
      },
    );
  }
}

class _TiltBubblePainter extends CustomPainter {
  final double rollDeg;
  _TiltBubblePainter({required this.rollDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, cy - 5, size.width - 16, 10),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      trackRect,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    // Center marks
    canvas.drawLine(
      Offset(cx, cy - 7),
      Offset(cx, cy + 7),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.0,
    );

    // Ball offset by roll (clamped to ±20° = full track range)
    final norm = (rollDeg / 20.0).clamp(-1.0, 1.0);
    final ballX = cx + norm * (size.width / 2 - 12);
    final isLevel = rollDeg.abs() < 2.0;
    final ballColor =
        isLevel ? const Color(0xFF4CAF50) : Colors.white;
    canvas.drawCircle(
      Offset(ballX, cy),
      isLevel ? 7 : 6,
      Paint()..color = ballColor.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      Offset(ballX, cy),
      isLevel ? 5 : 4,
      Paint()..color = ballColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TiltBubblePainter old) =>
      old.rollDeg != rollDeg;
}

/// Sliding "next target" reticle: starts at the right edge of the camera
/// viewport and slides toward center as the user approaches the next
/// capture interval. Replaces the static dot — the motion gives the user
/// a real sense of "approach the target".
class _NextTargetReticle extends StatelessWidget {
  final ValueListenable<double> sinceCapture;
  final double intervalDeg;
  final double cameraWidth;
  final bool wrongDirection;
  const _NextTargetReticle({
    required this.sinceCapture,
    required this.intervalDeg,
    required this.cameraWidth,
    required this.wrongDirection,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: sinceCapture,
      builder: (_, sc, _) {
        // Progress 0..1 from "just captured" to "about to capture next".
        final t = (sc / intervalDeg).clamp(0.0, 1.0);
        // Reticle starts ~28px from right edge, ends near horizontal center.
        final maxTravel = cameraWidth / 2 - 56;
        final offset = maxTravel * t;
        final scale = 1.0 + 0.3 * t;
        return SizedBox(
          width: cameraWidth,
          height: 32,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 28 + offset,
                child: Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    size: const Size(32, 32),
                    painter: _ReticlePainter(
                      progress: t,
                      wrongDirection: wrongDirection,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final double progress;
  final bool wrongDirection;
  _ReticlePainter({required this.progress, required this.wrongDirection});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final color = wrongDirection
        ? const Color(0xFFFF6B6B)
        : Color.lerp(
            const Color(0xFF4DD0E1),
            const Color(0xFF4CAF50),
            progress,
          )!;

    // Outer ring
    canvas.drawCircle(
      c,
      size.width / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
    // Inner pulse fill (grows with progress)
    canvas.drawCircle(
      c,
      (size.width / 2 - 6) * progress,
      Paint()..color = color.withValues(alpha: 0.45),
    );
    // Crosshair
    final cross = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx - 6, c.dy), Offset(c.dx + 6, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - 6), Offset(c.dx, c.dy + 6), cross);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) =>
      old.progress != progress || old.wrongDirection != wrongDirection;
}

/// Animated direction chevron — pulses outward to cue rotation direction.
class _DirectionPulse extends StatefulWidget {
  final bool wrongDirection;
  const _DirectionPulse({required this.wrongDirection});

  @override
  State<_DirectionPulse> createState() => _DirectionPulseState();
}

class _DirectionPulseState extends State<_DirectionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) => CustomPaint(
        size: const Size(56, 32),
        painter: _DirectionPulsePainter(
          phase: _ctl.value,
          wrongDirection: widget.wrongDirection,
        ),
      ),
    );
  }
}

class _DirectionPulsePainter extends CustomPainter {
  final double phase;
  final bool wrongDirection;
  _DirectionPulsePainter({required this.phase, required this.wrongDirection});

  @override
  void paint(Canvas canvas, Size size) {
    final color = wrongDirection
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF4DD0E1);
    // Three chevrons traveling rightward; each fades as it travels.
    for (int i = 0; i < 3; i++) {
      final p = ((phase + i / 3) % 1.0);
      final x = size.width * p;
      final alpha = (1.0 - p).clamp(0.0, 1.0) * 0.9;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(x, 4)
        ..lineTo(x + 10, size.height / 2)
        ..lineTo(x, size.height - 4);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DirectionPulsePainter old) =>
      old.phase != phase || old.wrongDirection != wrongDirection;
}

/// Long horizon line that crosses the camera viewport and tilts with
/// phone roll. Reads as a "pro app" affordance — at a glance the user
/// knows whether the phone is straight. Glows green when within ±2°.
class _HorizonLine extends StatelessWidget {
  final ValueListenable<double> roll;
  final double width;
  const _HorizonLine({required this.roll, required this.width});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: roll,
      builder: (_, r, _) {
        final isLevel = r.abs() < 2.0;
        final color = isLevel
            ? const Color(0xFF4CAF50)
            : Colors.white.withValues(alpha: 0.7);
        return Transform.rotate(
          angle: r * math.pi / 180.0,
          child: SizedBox(
            width: width,
            height: 24,
            child: CustomPaint(
              painter: _HorizonPainter(color: color, isLevel: isLevel),
            ),
          ),
        );
      },
    );
  }
}

class _HorizonPainter extends CustomPainter {
  final Color color;
  final bool isLevel;
  _HorizonPainter({required this.color, required this.isLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = isLevel ? 1.6 : 1.2
      ..strokeCap = StrokeCap.round;

    // Two short ticks meeting in the middle, leaving a gap so the
    // user's eye lands on the centerline rather than a hard line
    // across the whole frame.
    final gap = 38.0;
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width / 2 - gap, cy),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2 + gap, cy),
      Offset(size.width, cy),
      paint,
    );
    // Center indicator pip
    canvas.drawCircle(
      Offset(size.width / 2, cy),
      isLevel ? 3.5 : 2.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter old) =>
      old.color != color || old.isLevel != isLevel;
}

/// Faint frame outline that drifts from the right edge of the camera
/// viewport toward center as the user approaches the next capture.
/// Bigger visual cue than the reticle for "the next shot is here".
class _GhostFrameGuide extends StatelessWidget {
  final ValueListenable<double> sinceCapture;
  final double intervalDeg;
  final double cameraWidth;
  final double cameraHeight;
  final bool wrongDirection;
  const _GhostFrameGuide({
    required this.sinceCapture,
    required this.intervalDeg,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.wrongDirection,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: sinceCapture,
      builder: (_, sc, _) {
        final t = (sc / intervalDeg).clamp(0.0, 1.0);
        // Ghost is about 60% of viewport size, drifts from far-right
        // (offset = cameraWidth * 0.55) to centered (offset = 0).
        final maxOffset = cameraWidth * 0.55;
        final offsetX = maxOffset * (1.0 - t);
        final ghostW = cameraWidth * 0.6;
        final ghostH = cameraHeight * 0.6;
        final color = wrongDirection
            ? const Color(0xFFFF6B6B)
            : Color.lerp(
                Colors.white.withValues(alpha: 0.35),
                const Color(0xFF4CAF50).withValues(alpha: 0.85),
                t,
              )!;
        return SizedBox(
          width: cameraWidth,
          height: cameraHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(offsetX, 0),
                child: Container(
                  width: ghostW,
                  height: ghostH,
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 2.0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
