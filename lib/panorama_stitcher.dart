import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Data bundle sent to the stitch isolate via [compute].
class StitchInput {
  final List<String> framePaths;
  final List<double> frameYawDeg;

  const StitchInput({
    required this.framePaths,
    required this.frameYawDeg,
  });
}

/// Sequential pairwise panorama stitcher based on the Sense-Panorama method.
///
/// Reference: Yaseen et al., "Automatic Sequential Stitching of High-Resolution
/// Panorama for Android Devices Using Precapture Feature Detection and the
/// Orientation Sensor," Sensors 2023, 23(2), 879.
///
/// Key design choices for mobile performance:
/// 1. **Sequential pairwise** — matches only consecutive frame pairs O(n).
/// 2. **AKAZE features** — faster than SIFT on mobile with good accuracy.
/// 3. **RANSAC homography** — robust outlier rejection for each pair.
/// 4. **Incremental canvas build** — avoids allocating one huge canvas
///    for gradient blending; instead warps and blends pair-by-pair.
class PanoramaStitcher {
  /// Maximum frames to use for stitching.
  final int maxStitchFrames;

  /// Max pixel dimension (longest side) for images fed to the stitcher.
  final int stitchMaxDimension;

  /// Minimum number of RANSAC inlier matches required for a valid pair.
  final int minInlierMatches;

  /// RANSAC reprojection threshold (pixels) for findHomography.
  final double ransacThreshold;

  /// Lowe's ratio test threshold for filtering feature matches.
  final double loweRatioThresh;

  /// Maximum features to detect per image.
  final int maxFeatures;

  /// Target yaw spacing (degrees) for motion-based frame selection.
  /// Should match the capture screen's captureIntervalDeg.
  final double idealStepDeg;

  /// Camera horizontal field of view (degrees) used to convert Δyaw into
  /// expected pixel translation. 65° is a typical phone back-camera HFOV
  /// at 4:3; close enough for a match-filter prior.
  final double hfovDeg;

  const PanoramaStitcher({
    this.maxStitchFrames = 36,
    this.stitchMaxDimension = 600,
    this.minInlierMatches = 8,
    this.ransacThreshold = 5.0,
    this.loweRatioThresh = 0.75,
    this.maxFeatures = 1000,
    this.idealStepDeg = 10.0,
    this.hfovDeg = 65.0,
  });

  /// Subsample [paths] to at most [maxFrames] entries, evenly spaced.
  static (List<String>, List<double>) subsampleWithYaw(
      List<String> paths, List<double> yaws, int maxFrames) {
    if (paths.length <= maxFrames) return (paths, yaws);
    final step = (paths.length - 1) / (maxFrames - 1);
    final sampledPaths =
        List.generate(maxFrames, (i) => paths[(i * step).round()]);
    final sampledYaws = yaws.length >= paths.length
        ? List.generate(maxFrames, (i) => yaws[(i * step).round()])
        : <double>[];
    return (sampledPaths, sampledYaws);
  }

  /// Sort indices by their yaw values (ascending).
  static List<int> sortByYaw(List<double> yaws) {
    final indices = List.generate(yaws.length, (i) => i);
    indices.sort((a, b) => yaws[a].compareTo(yaws[b]));
    return indices;
  }

  /// Greedy motion-based frame selector. Sorts (path, yaw) by yaw, then
  /// keeps each frame only if it advances at least [idealStepDeg] from the
  /// last kept yaw — drops near-duplicates from pauses without losing
  /// coverage on segments where the user panned smoothly.
  ///
  /// Falls back to [subsampleWithYaw] if yaws are unusable (length
  /// mismatch or all zero) or if the greedy result has < 2 frames.
  /// Output is yaw-sorted, so the caller can skip a separate sort pass.
  static (List<String>, List<double>) motionBasedSelectFrames(
    List<String> paths,
    List<double> yaws, {
    required double idealStepDeg,
    required int maxFrames,
  }) {
    if (yaws.length != paths.length || yaws.every((y) => y == 0.0)) {
      return subsampleWithYaw(paths, yaws, maxFrames);
    }

    final sortedIdx = sortByYaw(yaws);
    final sortedPaths = sortedIdx.map((i) => paths[i]).toList();
    final sortedYaws = sortedIdx.map((i) => yaws[i]).toList();

    List<int> greedyKeep(double step) {
      final kept = <int>[0];
      for (int i = 1; i < sortedYaws.length; i++) {
        if (sortedYaws[i] - sortedYaws[kept.last] >= step) kept.add(i);
      }
      return kept;
    }

    var kept = greedyKeep(idealStepDeg);

    // If we still have too many, widen the step based on actual span.
    if (kept.length > maxFrames) {
      final span = sortedYaws.last - sortedYaws.first;
      final widened = span / (maxFrames - 1);
      kept = greedyKeep(widened);
    }

    if (kept.length < 2) {
      return subsampleWithYaw(paths, yaws, maxFrames);
    }

    final outPaths = kept.map((i) => sortedPaths[i]).toList();
    final outYaws = kept.map((i) => sortedYaws[i]).toList();

    // Median Δyaw for diagnostics.
    final deltas = <double>[
      for (int i = 1; i < outYaws.length; i++) outYaws[i] - outYaws[i - 1],
    ]..sort();
    final medianDelta =
        deltas.isEmpty ? 0.0 : deltas[deltas.length ~/ 2];
    debugPrint('[Panorama] Motion-select: kept ${kept.length}/${paths.length}'
        ' (median Δyaw = ${medianDelta.toStringAsFixed(1)}°)');

    return (outPaths, outYaws);
  }

  /// Validate a sorted yaw sequence. Returns whether the sequence is
  /// usable at all (`ok`) and whether it's clean enough to seed the
  /// homography prior (`useYawPrior`). On any soft failure we still try
  /// to stitch — features alone may rescue the run — but we drop the
  /// yaw-driven guidance.
  static ({bool ok, bool useYawPrior, String reason}) _validateYawSequence(
      List<double> yaws, int frameCount) {
    if (yaws.length != frameCount || yaws.length < 2) {
      return (ok: false, useYawPrior: false, reason: 'no yaw data');
    }
    final span = yaws.last - yaws.first;
    if (span < 60.0 || span > 380.0) {
      return (
        ok: true,
        useYawPrior: false,
        reason: 'span ${span.toStringAsFixed(1)}° out of range',
      );
    }
    double maxGap = 0.0;
    int maxGapIdx = 0;
    int dupCount = 0;
    for (int i = 1; i < yaws.length; i++) {
      final d = yaws[i] - yaws[i - 1];
      if (d > maxGap) {
        maxGap = d;
        maxGapIdx = i;
      }
      if (d < 0.5) dupCount++;
    }
    if (maxGap > 30.0) {
      return (
        ok: true,
        useYawPrior: false,
        reason: 'yaw gap ${maxGap.toStringAsFixed(1)}° at index $maxGapIdx',
      );
    }
    if (dupCount > yaws.length * 0.2) {
      return (
        ok: true,
        useYawPrior: false,
        reason: 'too many near-duplicate yaws ($dupCount)',
      );
    }
    return (
      ok: true,
      useYawPrior: true,
      reason: 'span=${span.toStringAsFixed(1)}° maxGap=${maxGap.toStringAsFixed(1)}°',
    );
  }

  /// 1D constant-position Kalman smoother on a sorted yaw sequence.
  /// Removes residual gyro noise that survived the capture-side EMA.
  /// Output is monotonic non-decreasing (the sort already guarantees the
  /// raw input is, but the filtered estimate is clamped just in case).
  ///
  /// processVar / measVar in degrees². Steady-state gain ≈ 0.4 with the
  /// defaults — trims jitter without flattening real motion.
  static List<double> _kalmanSmoothYaws(List<double> yaws,
      {double processVar = 0.5, double measVar = 2.0}) {
    if (yaws.length < 3) return List.of(yaws);
    final out = List<double>.filled(yaws.length, 0.0);
    double x = yaws.first;
    double p = measVar;
    out[0] = x;
    for (int i = 1; i < yaws.length; i++) {
      p = p + processVar;
      final k = p / (p + measVar);
      x = x + k * (yaws[i] - x);
      p = (1 - k) * p;
      if (x < out[i - 1]) x = out[i - 1];
      out[i] = x;
    }
    return out;
  }

  /// Load an image and downscale its longest side to [stitchMaxDimension].
  cv.Mat? _loadAndDownscale(String path) {
    var img = cv.imread(path);
    if (img.isEmpty) return null;

    final longest = math.max(img.width, img.height);
    if (longest > stitchMaxDimension) {
      final scale = stitchMaxDimension / longest;
      final resized = cv.resize(
          img, ((img.width * scale).round(), (img.height * scale).round()));
      img.dispose();
      img = resized;
    }
    return img;
  }

  /// Detect AKAZE keypoints and compute descriptors.
  /// AKAZE is much faster than SIFT on mobile with good matching quality.
  static (cv.VecKeyPoint, cv.Mat)? _detectFeatures(
      cv.Mat image, int maxFeatures) {
    final akaze = cv.AKAZE.create();
    final gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
    final (kps, desc) = akaze.detectAndCompute(gray, cv.Mat.empty());
    gray.dispose();
    akaze.dispose();
    if (kps.length < 4) {
      desc.dispose();
      return null;
    }
    return (kps, desc);
  }

  /// Match descriptors using BFMatcher + Lowe's ratio test.
  List<cv.DMatch> _matchFeatures(cv.Mat desc1, cv.Mat desc2) {
    final matcher = cv.BFMatcher.create(type: cv.NORM_HAMMING, crossCheck: false);
    final knnMatches = matcher.knnMatch(desc1, desc2, 2);
    matcher.dispose();

    final good = <cv.DMatch>[];
    for (final pair in knnMatches) {
      if (pair.length >= 2) {
        final m = pair[0];
        final n = pair[1];
        if (m.distance < loweRatioThresh * n.distance) {
          good.add(m);
        }
      }
    }
    return good;
  }

  /// Yaw-seeded variant of [_findPairHomography]. Filters [matches] to
  /// those whose horizontal displacement is consistent with the gyroscope
  /// prior, then runs the standard RANSAC fit on the filtered set. Falls
  /// back to the unfiltered call if too few matches survive — the prior
  /// is a guide, not a hard requirement.
  ///
  /// Sign convention: kps1 are panorama (dst) points, kps2 are next-frame
  /// (src) points. A positive Δyaw (rotated right) means content in the
  /// next frame appears shifted left in panorama coords, so for a true
  /// match dst.x − src.x ≈ −expectedTxPx.
  cv.Mat? _findPairHomographyWithYaw(
    cv.VecKeyPoint kps1,
    cv.VecKeyPoint kps2,
    List<cv.DMatch> matches, {
    required double deltaYawDeg,
    required int imageWidth,
  }) {
    final hfovRad = hfovDeg * math.pi / 180.0;
    final focalPx = imageWidth / (2.0 * math.tan(hfovRad / 2.0));
    final deltaYawRad = deltaYawDeg * math.pi / 180.0;
    final expectedTxPx = focalPx * math.tan(deltaYawRad);
    final tolerance = math.max(30.0, 0.4 * expectedTxPx.abs());

    final filtered = <cv.DMatch>[];
    for (final m in matches) {
      final p1 = kps1[m.queryIdx];
      final p2 = kps2[m.trainIdx];
      final dx = p1.x - p2.x;
      if ((dx - (-expectedTxPx)).abs() <= tolerance) filtered.add(m);
    }

    debugPrint('[Panorama] Yaw-prior filter: ${matches.length} → '
        '${filtered.length} matches (expected tx='
        '${expectedTxPx.toStringAsFixed(0)}px '
        '±${tolerance.toStringAsFixed(0)}px)');

    if (filtered.length < minInlierMatches) {
      return _findPairHomography(kps1, kps2, matches);
    }
    return _findPairHomography(kps1, kps2, filtered);
  }

  /// Find homography between two images using matched keypoints + RANSAC.
  cv.Mat? _findPairHomography(
    cv.VecKeyPoint kps1,
    cv.VecKeyPoint kps2,
    List<cv.DMatch> matches,
  ) {
    if (matches.length < minInlierMatches) return null;

    // Build point arrays: src = next frame points, dst = panorama points
    final srcPts = <double>[];
    final dstPts = <double>[];
    for (final m in matches) {
      final p1 = kps1[m.queryIdx]; // panorama keypoint
      final p2 = kps2[m.trainIdx]; // next frame keypoint
      srcPts.addAll([p2.x, p2.y]);
      dstPts.addAll([p1.x, p1.y]);
    }

    final srcMat = cv.Mat.fromList(
        matches.length, 1, cv.MatType.CV_32FC2, srcPts);
    final dstMat = cv.Mat.fromList(
        matches.length, 1, cv.MatType.CV_32FC2, dstPts);

    final mask = cv.Mat.empty();
    final H = cv.findHomography(
      srcMat,
      dstMat,
      method: cv.RANSAC,
      ransacReprojThreshold: ransacThreshold,
      mask: mask,
    );

    srcMat.dispose();
    dstMat.dispose();

    if (H.isEmpty) {
      mask.dispose();
      return null;
    }

    // Count inliers from RANSAC mask
    int inliers = 0;
    if (!mask.isEmpty) {
      for (int i = 0; i < mask.rows; i++) {
        if (mask.at<int>(i, 0) != 0) inliers++;
      }
    } else {
      inliers = matches.length; // no mask = assume all inliers
    }
    mask.dispose();

    if (inliers < minInlierMatches) {
      H.dispose();
      return null;
    }

    debugPrint('[Panorama] Homography: ${matches.length} matches, '
        '$inliers RANSAC inliers');
    return H;
  }

  /// Per-channel gain compensation. Computes mean B/G/R for every frame,
  /// then scales each channel independently toward the median-of-means.
  /// Preserves white balance across frames (the previous luminance-only
  /// version produced visible color jumps when light temperature shifted
  /// — warm hallway → cool window — because all three channels were
  /// scaled by the same factor).
  static void _gainCompensate(List<cv.Mat> images) {
    final meansB = <double>[];
    final meansG = <double>[];
    final meansR = <double>[];
    for (final img in images) {
      final m = cv.mean(img); // val1=B, val2=G, val3=R for BGR Mats
      meansB.add(m.val1);
      meansG.add(m.val2);
      meansR.add(m.val3);
    }

    double median(List<double> v) {
      final s = List<double>.from(v)..sort();
      return s[s.length ~/ 2];
    }

    final targetB = median(meansB);
    final targetG = median(meansG);
    final targetR = median(meansR);
    if (targetB < 1.0 || targetG < 1.0 || targetR < 1.0) return;

    for (int i = 0; i < images.length; i++) {
      if (meansB[i] < 1.0 || meansG[i] < 1.0 || meansR[i] < 1.0) continue;
      final sB = (targetB / meansB[i]).clamp(0.5, 2.0);
      final sG = (targetG / meansG[i]).clamp(0.5, 2.0);
      final sR = (targetR / meansR[i]).clamp(0.5, 2.0);
      if ((sB - 1.0).abs() < 0.03 &&
          (sG - 1.0).abs() < 0.03 &&
          (sR - 1.0).abs() < 0.03) {
        continue;
      }

      final channels = cv.split(images[i]);
      final adjB = channels[0].convertTo(channels[0].type, alpha: sB);
      final adjG = channels[1].convertTo(channels[1].type, alpha: sG);
      final adjR = channels[2].convertTo(channels[2].type, alpha: sR);
      for (final c in channels) {
        c.dispose();
      }
      final merged = cv.merge(cv.VecMat.fromList([adjB, adjG, adjR]));
      adjB.dispose();
      adjG.dispose();
      adjR.dispose();
      images[i].dispose();
      images[i] = merged;
    }

    debugPrint('[Panorama] Gain compensation (per-channel): '
        'target B=${targetB.toStringAsFixed(0)} '
        'G=${targetG.toStringAsFixed(0)} '
        'R=${targetR.toStringAsFixed(0)}');
  }

  /// Remove black borders created by perspective warping.
  /// Scans rows and columns to find the content region, then crops.
  static cv.Mat _autoCrop(cv.Mat image) {
    final gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
    final mask = cv.threshold(gray, 10, 255, cv.THRESH_BINARY).$2;
    gray.dispose();

    final minRowContent = image.cols ~/ 4;

    // Find top content row
    int top = 0;
    for (int y = 0; y < image.rows; y++) {
      final row = mask.rowRange(y, y + 1);
      if (cv.countNonZero(row) >= minRowContent) {
        top = y;
        break;
      }
    }

    // Find bottom content row
    int bottom = image.rows - 1;
    for (int y = image.rows - 1; y > top; y--) {
      final row = mask.rowRange(y, y + 1);
      if (cv.countNonZero(row) >= minRowContent) {
        bottom = y;
        break;
      }
    }

    final contentH = bottom - top + 1;
    if (contentH < 50) {
      mask.dispose();
      return image.clone();
    }

    // Find left/right content columns within content rows
    final contentMask = mask.rowRange(top, bottom + 1);
    final minColContent = contentH ~/ 4;

    int left = 0;
    for (int x = 0; x < image.cols; x++) {
      final col = contentMask.colRange(x, x + 1);
      if (cv.countNonZero(col) >= minColContent) {
        left = x;
        break;
      }
    }

    int right = image.cols - 1;
    for (int x = image.cols - 1; x > left; x--) {
      final col = contentMask.colRange(x, x + 1);
      if (cv.countNonZero(col) >= minColContent) {
        right = x;
        break;
      }
    }

    mask.dispose();

    final cropW = right - left + 1;
    final cropH = bottom - top + 1;
    if (cropW < 100 || cropH < 50) return image.clone();

    debugPrint('[Panorama] Auto-crop: '
        '${image.width}×${image.height} → $cropW×$cropH');
    final cropped = image.region(cv.Rect(left, top, cropW, cropH));
    return cropped.clone();
  }

  /// Full stitch pipeline using sequential pairwise stitching.
  String? stitchFrames(StitchInput input) {
    try {
      // Kalman-smooth raw yaws before frame selection. Only useful if
      // yaw count matches frame count; otherwise pass through.
      final smoothedYaws = input.frameYawDeg.length == input.framePaths.length
          ? _kalmanSmoothYaws(input.frameYawDeg)
          : input.frameYawDeg;

      final (sampled, sampledYaw) = motionBasedSelectFrames(
        input.framePaths,
        smoothedYaws,
        idealStepDeg: idealStepDeg,
        maxFrames: maxStitchFrames,
      );

      // motionBasedSelectFrames returns yaw-sorted output, so no extra
      // sort needed when yaws are present. Fallback path (length mismatch)
      // still goes through the original subsample which doesn't sort.
      final List<String> orderedPaths;
      final List<double> orderedYaws;
      if (sampledYaw.length == sampled.length) {
        orderedPaths = sampled;
        orderedYaws = sampledYaw;
      } else {
        orderedPaths = sampled;
        orderedYaws = const <double>[];
        debugPrint('[Panorama] Using capture order (no yaw data)');
      }

      // Yaw sanity check — gates the homography prior. ok=false is rare
      // and just means we treat the run as if no yaws were present.
      final sanity = _validateYawSequence(orderedYaws, orderedPaths.length);
      debugPrint('[Panorama] Yaw sanity: ok=${sanity.ok}'
          ' useYawPrior=${sanity.useYawPrior} ${sanity.reason}');
      final List<double> stitchYaws =
          sanity.ok ? orderedYaws : const <double>[];

      // Load all frames
      final images = <cv.Mat>[];
      for (final path in orderedPaths) {
        final img = _loadAndDownscale(path);
        if (img != null) images.add(img);
      }

      if (images.length < 2) {
        for (final m in images) {
          m.dispose();
        }
        return null;
      }

      debugPrint('[Panorama] Loaded ${images.length} frames '
          '(${images.first.width}×${images.first.height})');

      // Try sequential pairwise stitching (Sense-Panorama method)
      String? result = _sequentialStitch(
        images,
        input,
        yaws: stitchYaws,
        useYawPrior: sanity.useYawPrior,
      );
      if (result != null) return result;

      // Fallback only for small frame sets — OpenCV Stitcher is O(n²)
      // and will timeout on 20+ frames.
      if (orderedPaths.length <= 16) {
        debugPrint('[Panorama] Sequential failed — trying OpenCV Stitcher');
        final fallbackImages = <cv.Mat>[];
        for (final path in orderedPaths) {
          final img = _loadAndDownscale(path);
          if (img != null) fallbackImages.add(img);
        }
        result = _fallbackStitch(fallbackImages, input);
        for (final img in fallbackImages) {
          img.dispose();
        }
        return result;
      } else {
        debugPrint('[Panorama] ${orderedPaths.length} frames — skipping O(n²) fallback');
        return null;
      }
    } catch (e) {
      debugPrint('[Panorama] Stitch error: $e');
      return null;
    }
  }

  /// Sequential pairwise stitching (Sense-Panorama algorithm).
  ///
  /// Incremental approach: stitch frames pair-by-pair into a growing
  /// panorama. Each step only operates on two images (current panorama
  /// + next frame), keeping memory bounded regardless of frame count.
  String? _sequentialStitch(
    List<cv.Mat> images,
    StitchInput input, {
    List<double> yaws = const <double>[],
    bool useYawPrior = false,
  }) {
    // ── 1. Pre-compute features for all frames ──
    final features = <(cv.VecKeyPoint, cv.Mat)?>[];
    for (final img in images) {
      features.add(_detectFeatures(img, maxFeatures));
    }

    final validCount = features.where((f) => f != null).length;
    if (validCount < 2) {
      debugPrint('[Panorama] Only $validCount frames have features');
      _disposeFeatures(features);
      for (final img in images) {
        img.dispose();
      }
      return null;
    }

    debugPrint('[Panorama] Features: $validCount/${images.length} frames');

    // ── 2. Gain compensation ──
    _gainCompensate(images);

    // Yaws are aligned to the original image list. After a successful
    // pair, advance panoYaw by the captured Δyaw (not by the new
    // panorama's pixel width — that drifts as the canvas grows).
    final hasYaws = useYawPrior && yaws.length == images.length;
    double panoYaw = hasYaws ? yaws[0] : 0.0;

    // ── 3. Incremental pairwise stitch ──
    cv.Mat panorama = images[0].clone();
    var panoFeats = _detectFeatures(panorama, maxFeatures);
    int successfulPairs = 0;
    int consecutiveFails = 0;

    for (int i = 1; i < images.length; i++) {
      final nextFeats = features[i];
      if (nextFeats == null || panoFeats == null) {
        debugPrint('[Panorama] Skip frame $i — no features');
        consecutiveFails++;
        if (consecutiveFails > 3) break;
        continue;
      }

      final (panoKps, panoDesc) = panoFeats;
      final (nextKps, nextDesc) = nextFeats;

      final matches = _matchFeatures(panoDesc, nextDesc);
      if (matches.length < minInlierMatches) {
        debugPrint('[Panorama] Frame $i: ${matches.length} matches — skip');
        consecutiveFails++;
        if (consecutiveFails > 3) break;
        continue;
      }

      // With a valid yaw prior, prefilter matches by expected horizontal
      // shift so RANSAC isn't fooled by repetitive-texture outliers.
      final H = hasYaws
          ? _findPairHomographyWithYaw(
              panoKps,
              nextKps,
              matches,
              deltaYawDeg: yaws[i] - panoYaw,
              imageWidth: images[i].cols,
            )
          : _findPairHomography(panoKps, nextKps, matches);
      if (H == null) {
        debugPrint('[Panorama] Frame $i: homography failed');
        consecutiveFails++;
        if (consecutiveFails > 3) break;
        continue;
      }

      final merged = _warpAndBlend(panorama, images[i], H);
      H.dispose();

      if (merged == null) {
        debugPrint('[Panorama] Frame $i: warp/blend failed');
        consecutiveFails++;
        if (consecutiveFails > 3) break;
        continue;
      }

      panorama.dispose();
      panorama = merged;
      successfulPairs++;
      consecutiveFails = 0;
      if (hasYaws) panoYaw = yaws[i];

      // Re-detect features on the new panorama for the next pair
      // Only detect in the right portion where the next frame will overlap
      panoFeats = _detectFeatures(panorama, maxFeatures);

      debugPrint('[Panorama] Frame $i stitched '
          '($successfulPairs done, ${panorama.width}×${panorama.height})');
    }

    _disposeFeatures(features);
    for (final img in images) {
      img.dispose();
    }

    if (successfulPairs < 2) {
      panorama.dispose();
      debugPrint('[Panorama] Sequential: only $successfulPairs pairs');
      return null;
    }

    // ── 4. Auto-crop black borders ──
    final cropped = _autoCrop(panorama);
    panorama.dispose();

    debugPrint('[Panorama] Sequential done: '
        '$successfulPairs pairs, ${cropped.width}×${cropped.height}');

    final outPath = _outputPath(input);
    cv.imwrite(outPath, cropped,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 95]));
    cropped.dispose();
    return outPath;
  }

  /// Warp [src] onto a canvas containing [dst] using homography [H].
  /// Uses gradient-weighted blending for smooth seam transitions.
  static cv.Mat? _warpAndBlend(cv.Mat dst, cv.Mat src, cv.Mat H) {
    final dstH = dst.rows;
    final dstW = dst.cols;
    final srcH = src.rows;
    final srcW = src.cols;

    // Transform corners of src to find bounding box
    final corners = cv.Mat.fromList(4, 1, cv.MatType.CV_64FC2, [
      0.0, 0.0, srcW.toDouble(), 0.0,
      srcW.toDouble(), srcH.toDouble(), 0.0, srcH.toDouble(),
    ]);

    final H64 = H.convertTo(cv.MatType.CV_64FC1);
    final transformed = cv.perspectiveTransform(corners, H64);
    corners.dispose();

    double minX = 0, minY = 0;
    double maxX = dstW.toDouble(), maxY = dstH.toDouble();
    for (int i = 0; i < 4; i++) {
      final x = transformed.at<double>(i, 0);
      final y = transformed.at<double>(i, 1);
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    transformed.dispose();

    final canvasW = (maxX - minX).ceil();
    final canvasH = (maxY - minY).ceil();
    if (canvasW > 10000 || canvasH > 5000 || canvasW <= 0 || canvasH <= 0) {
      H64.dispose();
      debugPrint('[Panorama] Canvas too large: ${canvasW}x$canvasH');
      return null;
    }

    final tx = -minX;
    final ty = -minY;
    final T = cv.Mat.fromList(3, 3, cv.MatType.CV_64FC1, [
      1.0, 0.0, tx, 0.0, 1.0, ty, 0.0, 0.0, 1.0,
    ]);

    // Warp src
    final warpMat = cv.gemm(T, H64, 1.0, cv.Mat.empty(), 0.0);
    H64.dispose();
    final warpedSrc = cv.warpPerspective(
      src, warpMat, (canvasW, canvasH),
      flags: cv.INTER_LINEAR,
      borderMode: cv.BORDER_CONSTANT,
      borderValue: cv.Scalar.black,
    );
    warpMat.dispose();

    // Place dst on canvas
    final dstT = cv.Mat.fromList(2, 3, cv.MatType.CV_64FC1, [
      1.0, 0.0, tx, 0.0, 1.0, ty,
    ]);
    final placedDst = cv.warpAffine(
      dst, dstT, (canvasW, canvasH),
      flags: cv.INTER_LINEAR,
      borderMode: cv.BORDER_CONSTANT,
      borderValue: cv.Scalar.black,
    );
    dstT.dispose();
    T.dispose();

    // Gradient blend in overlap region
    final result = _gradientBlend(placedDst, warpedSrc);
    placedDst.dispose();
    warpedSrc.dispose();
    return result;
  }

  /// Gradient-weighted blend of two images. Uses distance-from-edge
  /// as weight so transitions are smooth at seam boundaries.
  static cv.Mat _gradientBlend(cv.Mat img1, cv.Mat img2) {
    final gray1 = cv.cvtColor(img1, cv.COLOR_BGR2GRAY);
    final gray2 = cv.cvtColor(img2, cv.COLOR_BGR2GRAY);
    final mask1 = cv.threshold(gray1, 1, 255, cv.THRESH_BINARY).$2;
    final mask2 = cv.threshold(gray2, 1, 255, cv.THRESH_BINARY).$2;
    gray1.dispose();
    gray2.dispose();

    final overlap = cv.bitwiseAND(mask1, mask2);
    final hasOverlap = cv.countNonZero(overlap) > 0;

    // Start with img1 as base
    final result = img1.clone();

    // Where only img2 has content, copy img2
    final only2 = cv.bitwiseAND(mask2, cv.bitwiseNOT(mask1));
    img2.copyTo(result, mask: only2);
    only2.dispose();

    if (hasOverlap) {
      // Blur masks to create distance-based weights for smooth transition.
      // Kernel is proportional to canvas width (~1/6 of total) so seam
      // transitions span hundreds of pixels — single-band but absorbs
      // residual color/exposure mismatch much better than a fixed 31×31.
      int k = (img1.cols ~/ 6) | 1; // force odd
      if (k < 31) k = 31;
      if (k > 301) k = 301; // cap to keep gaussianBlur cost bounded
      final sigma = k / 3.0;
      final w1 = cv.gaussianBlur(mask1, (k, k), sigma);
      final w2 = cv.gaussianBlur(mask2, (k, k), sigma);

      // Convert to float for weighted average
      final w1f = w1.convertTo(cv.MatType.CV_32FC1);
      final w2f = w2.convertTo(cv.MatType.CV_32FC1);
      w1.dispose();
      w2.dispose();

      // sum = w1 + w2 (avoid division by zero)
      final wSum = cv.add(w1f, w2f);
      // alpha = w1 / (w1 + w2)
      final alpha1ch = cv.divide(w1f, wSum);
      w1f.dispose();
      w2f.dispose();
      wSum.dispose();

      final alpha3ch = cv.merge(cv.VecMat.fromList([alpha1ch, alpha1ch, alpha1ch]));
      alpha1ch.dispose();

      // blended = img1 * alpha + img2 * (1 - alpha) in overlap
      final img1f = img1.convertTo(cv.MatType.CV_32FC3);
      final img2f = img2.convertTo(cv.MatType.CV_32FC3);

      final ones = cv.Mat.ones(alpha3ch.rows, alpha3ch.cols, cv.MatType.CV_32FC3);
      final beta3ch = cv.subtract(ones, alpha3ch);
      ones.dispose();

      final part1 = cv.multiply(img1f, alpha3ch);
      final part2 = cv.multiply(img2f, beta3ch);
      alpha3ch.dispose();
      beta3ch.dispose();
      img1f.dispose();
      img2f.dispose();

      final blendedF = cv.add(part1, part2);
      part1.dispose();
      part2.dispose();

      final blended = blendedF.convertTo(cv.MatType.CV_8UC3);
      blendedF.dispose();

      blended.copyTo(result, mask: overlap);
      blended.dispose();
    }

    mask1.dispose();
    mask2.dispose();
    overlap.dispose();
    return result;
  }

  /// Fallback: OpenCV high-level Stitcher.
  String? _fallbackStitch(List<cv.Mat> images, StitchInput input) {
    if (images.length < 2) return null;

    final stitcher = cv.Stitcher.create(mode: cv.StitcherMode.PANORAMA);
    stitcher.panoConfidenceThresh = 0.3;
    stitcher.registrationResol = 0.6;
    stitcher.seamEstimationResol = 0.1;
    stitcher.waveCorrection = true;

    var (status, pano) = stitcher.stitch(cv.VecMat.fromList(images));
    debugPrint('[Panorama] Fallback PANORAMA: $status');

    if (status != cv.StitcherStatus.OK || pano.isEmpty) {
      pano.dispose();
      final stitcher2 = cv.Stitcher.create(mode: cv.StitcherMode.SCANS);
      stitcher2.panoConfidenceThresh = 0.3;
      final (s2, p2) = stitcher2.stitch(cv.VecMat.fromList(images));
      debugPrint('[Panorama] Fallback SCANS: $s2');
      status = s2;
      pano = p2;
    }

    if (status != cv.StitcherStatus.OK || pano.isEmpty) {
      pano.dispose();
      return null;
    }

    // Auto-crop black borders from the stitched result
    final cropped = _autoCrop(pano);
    pano.dispose();

    final outPath = _outputPath(input);
    cv.imwrite(outPath, cropped,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 95]));
    cropped.dispose();
    return outPath;
  }

  String _outputPath(StitchInput input) {
    final sep = Platform.pathSeparator;
    final dir = input.framePaths.first
        .substring(0, input.framePaths.first.lastIndexOf(sep));
    return '$dir${sep}pano_stitched_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  void _disposeFeatures(List<(cv.VecKeyPoint, cv.Mat)?> features) {
    for (final f in features) {
      if (f != null) f.$2.dispose();
    }
  }

  /// Convenience for running in an isolate via [compute].
  static String? stitchIsolate(StitchInput input) {
    return const PanoramaStitcher().stitchFrames(input);
  }
}
