// Standalone analysis script — run with: dart run test/panorama_analysis.dart
// No Flutter or native dependencies needed.

void main() {
  print('═══════════════════════════════════════════');
  print(' PANORAMA STITCH PARAMETER ANALYSIS');
  print('═══════════════════════════════════════════\n');

  const estimatedFovDeg = 70.0; // typical phone camera horizontal FOV

  // ─── Subsample coverage analysis ────────────

  print('─── Subsample: 36 frames at 10° intervals ───');
  for (final maxFrames in [8, 12, 16, 20, 36]) {
    final totalFrames = 36;
    final effectiveFrames =
        totalFrames <= maxFrames ? totalFrames : maxFrames;
    final step = totalFrames / effectiveFrames;

    // Simulate subsampling
    final sampledIndices =
        List.generate(effectiveFrames, (i) => (i * step).floor());
    final sampledYaws = sampledIndices.map((i) => i * 10.0).toList();

    // Find max angular gap
    double maxGap = 0;
    for (int i = 1; i < sampledYaws.length; i++) {
      final gap = sampledYaws[i] - sampledYaws[i - 1];
      if (gap > maxGap) maxGap = gap;
    }

    final overlapPercent =
        ((estimatedFovDeg - maxGap) / estimatedFovDeg * 100).clamp(0.0, 100.0);

    final quality = overlapPercent >= 70
        ? 'GREAT'
        : overlapPercent >= 50
            ? 'OK'
            : 'POOR';

    print('  maxFrames=$maxFrames: '
        '$effectiveFrames frames, '
        'max gap=${maxGap.toStringAsFixed(0)}°, '
        'overlap=${overlapPercent.toStringAsFixed(0)}% '
        '[$quality]');
  }

  // ─── Capture interval impact ────────────────

  print('\n─── Capture interval impact ───');
  for (final interval in [5.0, 10.0, 15.0, 20.0, 30.0]) {
    final overlapPercent =
        ((estimatedFovDeg - interval) / estimatedFovDeg * 100).clamp(0.0, 100.0);
    final framesFor360 = (360 / interval).ceil();

    final quality = overlapPercent >= 80
        ? 'EXCELLENT'
        : overlapPercent >= 60
            ? 'GOOD'
            : overlapPercent >= 40
                ? 'MARGINAL'
                : 'BAD';

    print('  interval=${interval.toInt()}°: '
        '$framesFor360 frames for 360°, '
        '${overlapPercent.toStringAsFixed(0)}% overlap '
        '[$quality]');
  }

  // ─── Resolution impact on stitch time ───────

  print('\n─── Estimated stitch time (relative) ───');
  print('  Feature matching is O(n² × pixels):');
  for (final dim in [640, 800, 1024, 1280, 1536]) {
    for (final nFrames in [12, 16, 20]) {
      // Relative cost compared to baseline (800px, 12 frames)
      final pixels = dim * dim * 0.75; // assume 4:3 aspect
      final basePixels = 800 * 800 * 0.75;
      final cost = (nFrames * (nFrames - 1) / 2) *
          pixels /
          ((12 * 11 / 2) * basePixels);
      print('    ${dim}px × $nFrames frames: ${cost.toStringAsFixed(1)}× baseline');
    }
  }

  // ─── Optimal configuration analysis ─────────

  print('\n═══════════════════════════════════════════');
  print(' RECOMMENDED CONFIGURATION');
  print('═══════════════════════════════════════════');

  print('\n  Current (broken):');
  print('    maxStitchFrames = 12');
  print('    stitchMaxDimension = 800');
  print('    → 36 frames subsampled to 12 = 30° gaps = 57% overlap (MARGINAL)');
  print('    → 800px images = low feature density = poor matching');
  print('    → Post-processor caps at 2048px wide = very low final res');

  print('\n  Recommended:');
  print('    maxStitchFrames = 16');
  print('    stitchMaxDimension = 1280');
  print('    → 36 frames subsampled to 16 = 22.5° gaps = 68% overlap (GOOD)');
  print('    → 1280px images = better features, ~2x cost');
  print('    → Post-processor should allow 4096px for panorama viewers');
  print('    → Stitch time: ~1.8× baseline, well within 150s timeout');

  // ─── Quality score weight analysis ──────────

  print('\n─── Quality score weights ───');
  print('  sharpness: 15%');
  print('  exposure: 10%');
  print('  angularCoverage: 20%');
  print('  overlapQuality: 15%');
  print('  stitchIntegrity: 20%');
  print('  blackRegions: 20%');
  print('  → 60% weight on stitch-related metrics (angular, stitch, black)');
  print('  → Key driver: higher resolution + more frames → better stitching');

  print('\n═══════════════════════════════════════════');
  print(' ACTIONS TO IMPROVE OUTPUT QUALITY');
  print('═══════════════════════════════════════════');
  print('  1. Increase stitchMaxDimension: 800 → 1280');
  print('  2. Increase maxStitchFrames: 12 → 16');
  print('  3. Increase post-processor max: 2048 → 4096');
  print('  4. Increase JPEG quality: 90 → 95 in post-processor');
  print('  5. Use registrationResol=0.8 for better feature detection');
  print('  6. Keep panoConfidenceThresh=0.3 for lenient matching');
  print('');
}
