import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:vxr_flutter/panorama_post_processor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pano_unit_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ─────────────────────────────────────────────
  // PanoramaQualityScore
  // ─────────────────────────────────────────────

  group('PanoramaQualityScore', () {
    test('overall is correct weighted average', () {
      const score = PanoramaQualityScore(
        sharpness: 80,
        exposure: 70,
        angularCoverage: 90,
        overlapQuality: 85,
        stitchIntegrity: 75,
        blackRegions: 95,
        coverage: 100,
      );
      // 80*0.15 + 70*0.10 + 90*0.20 + 85*0.15 + 75*0.20 + 95*0.20
      final expected =
          80 * 0.15 + 70 * 0.10 + 90 * 0.20 + 85 * 0.15 + 75 * 0.20 + 95 * 0.20;
      expect(score.overall, closeTo(expected, 0.01));
    });

    test('5 stars for >= 90 overall', () {
      const score = PanoramaQualityScore(
        sharpness: 95, exposure: 95, angularCoverage: 95,
        overlapQuality: 95, stitchIntegrity: 95, blackRegions: 95, coverage: 95,
      );
      expect(score.stars, 5);
      expect(score.label, 'Excellent');
    });

    test('4 stars for >= 75 overall', () {
      const score = PanoramaQualityScore(
        sharpness: 80, exposure: 80, angularCoverage: 80,
        overlapQuality: 80, stitchIntegrity: 80, blackRegions: 80, coverage: 80,
      );
      expect(score.stars, 4);
      expect(score.label, 'Good');
    });

    test('3 stars for >= 60 overall', () {
      const score = PanoramaQualityScore(
        sharpness: 65, exposure: 65, angularCoverage: 65,
        overlapQuality: 65, stitchIntegrity: 65, blackRegions: 65, coverage: 65,
      );
      expect(score.stars, 3);
      expect(score.label, 'Fair');
    });

    test('2 stars for >= 40 overall', () {
      const score = PanoramaQualityScore(
        sharpness: 45, exposure: 45, angularCoverage: 45,
        overlapQuality: 45, stitchIntegrity: 45, blackRegions: 45, coverage: 45,
      );
      expect(score.stars, 2);
      expect(score.label, 'Poor');
    });

    test('1 star for < 40 overall', () {
      const score = PanoramaQualityScore(
        sharpness: 20, exposure: 20, angularCoverage: 20,
        overlapQuality: 20, stitchIntegrity: 20, blackRegions: 20, coverage: 20,
      );
      expect(score.stars, 1);
      expect(score.label, 'Very Poor');
    });

    test('tips for low angularCoverage', () {
      const score = PanoramaQualityScore(
        sharpness: 90, exposure: 90, angularCoverage: 40,
        overlapQuality: 90, stitchIntegrity: 90, blackRegions: 90, coverage: 90,
      );
      expect(score.tips.any((t) => t.contains('360°')), isTrue);
    });

    test('tips for low blackRegions', () {
      const score = PanoramaQualityScore(
        sharpness: 90, exposure: 90, angularCoverage: 90,
        overlapQuality: 90, stitchIntegrity: 90, blackRegions: 40, coverage: 90,
      );
      expect(score.tips.any((t) => t.contains('blank/black')), isTrue);
    });

    test('tips for low stitchIntegrity', () {
      const score = PanoramaQualityScore(
        sharpness: 90, exposure: 90, angularCoverage: 90,
        overlapQuality: 90, stitchIntegrity: 40, blackRegions: 90, coverage: 90,
      );
      expect(score.tips.any((t) => t.contains('seams')), isTrue);
    });

    test('tips for low overlapQuality', () {
      const score = PanoramaQualityScore(
        sharpness: 90, exposure: 90, angularCoverage: 90,
        overlapQuality: 40, stitchIntegrity: 90, blackRegions: 90, coverage: 90,
      );
      expect(score.tips.any((t) => t.contains('overlap')), isTrue);
    });

    test('tips for low sharpness', () {
      const score = PanoramaQualityScore(
        sharpness: 40, exposure: 90, angularCoverage: 90,
        overlapQuality: 90, stitchIntegrity: 90, blackRegions: 90, coverage: 90,
      );
      expect(score.tips.any((t) => t.contains('blurry')), isTrue);
    });

    test('tips for low exposure', () {
      const score = PanoramaQualityScore(
        sharpness: 90, exposure: 40, angularCoverage: 90,
        overlapQuality: 90, stitchIntegrity: 90, blackRegions: 90, coverage: 90,
      );
      expect(score.tips.any((t) => t.contains('lighting')), isTrue);
    });

    test('no tips for all high scores', () {
      const score = PanoramaQualityScore(
        sharpness: 90, exposure: 90, angularCoverage: 90,
        overlapQuality: 90, stitchIntegrity: 90, blackRegions: 90, coverage: 90,
      );
      expect(score.tips, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // PanoramaCaptureMetadata
  // ─────────────────────────────────────────────

  group('PanoramaCaptureMetadata', () {
    test('default targetRotationDeg is 360', () {
      const meta = PanoramaCaptureMetadata(
        totalRotationDeg: 180,
        validFrameCount: 10,
        captureIntervalDeg: 10,
      );
      expect(meta.targetRotationDeg, 360.0);
    });

    test('custom targetRotationDeg', () {
      const meta = PanoramaCaptureMetadata(
        totalRotationDeg: 180,
        validFrameCount: 10,
        captureIntervalDeg: 10,
        targetRotationDeg: 180,
      );
      expect(meta.targetRotationDeg, 180.0);
    });
  });

  // ─────────────────────────────────────────────
  // PanoramaQualityAnalyzer
  // ─────────────────────────────────────────────

  group('PanoramaQualityAnalyzer', () {
    test('clean uniform image gets high exposure + black region scores',
        () async {
      final image = img.Image(width: 800, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          final r = 100 + (x * 155 ~/ 800);
          final g = 100 + (y * 155 ~/ 400);
          image.setPixelRgb(x, y, r, g, 150);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}clean.jpg';
      File(path).writeAsBytesSync(
          Uint8List.fromList(img.encodeJpg(image, quality: 95)));

      final score = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: const PanoramaCaptureMetadata(
          totalRotationDeg: 360,
          validFrameCount: 36,
          captureIntervalDeg: 10,
        ),
      );

      print('Clean image:');
      print('  sharpness=${score.sharpness.toStringAsFixed(1)}');
      print('  exposure=${score.exposure.toStringAsFixed(1)}');
      print('  angularCoverage=${score.angularCoverage.toStringAsFixed(1)}');
      print('  overlapQuality=${score.overlapQuality.toStringAsFixed(1)}');
      print('  stitchIntegrity=${score.stitchIntegrity.toStringAsFixed(1)}');
      print('  blackRegions=${score.blackRegions.toStringAsFixed(1)}');
      print('  overall=${score.overall.toStringAsFixed(1)} stars=${score.stars}');

      expect(score.angularCoverage, closeTo(100, 5));
      expect(score.blackRegions, greaterThanOrEqualTo(80));
      expect(score.exposure, greaterThanOrEqualTo(50));
    });

    test('half-black image gets low black region score', () async {
      final image = img.Image(width: 800, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          if (x < 400) {
            image.setPixelRgb(x, y, 0, 0, 0);
          } else {
            image.setPixelRgb(x, y, 150, 150, 150);
          }
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}halfblack.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final score = await PanoramaQualityAnalyzer.analyze(File(path));

      print('Half-black image:');
      print('  blackRegions=${score.blackRegions.toStringAsFixed(1)}');
      print('  coverage=${score.coverage.toStringAsFixed(1)}');
      print('  overall=${score.overall.toStringAsFixed(1)}');

      expect(score.blackRegions, lessThan(60));
    });

    test('angular coverage: 180° → ~50, 360° → 100', () async {
      final image = img.Image(width: 400, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 400; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}gray.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final score180 = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: const PanoramaCaptureMetadata(
          totalRotationDeg: 180,
          validFrameCount: 18,
          captureIntervalDeg: 10,
        ),
      );

      final score360 = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: const PanoramaCaptureMetadata(
          totalRotationDeg: 360,
          validFrameCount: 36,
          captureIntervalDeg: 10,
        ),
      );

      print('Angular coverage: 180°=${score180.angularCoverage.toStringAsFixed(1)}, '
          '360°=${score360.angularCoverage.toStringAsFixed(1)}');

      expect(score180.angularCoverage, closeTo(50, 5));
      expect(score360.angularCoverage, closeTo(100, 5));
      expect(score360.angularCoverage, greaterThan(score180.angularCoverage));
    });

    test('overlap quality: 10° interval (good) vs 30° interval (poor)',
        () async {
      final image = img.Image(width: 400, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 400; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}overlap_test.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      // 10° intervals with 36 frames → ~86% overlap (great)
      final scoreGood = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: const PanoramaCaptureMetadata(
          totalRotationDeg: 360,
          validFrameCount: 36,
          captureIntervalDeg: 10,
        ),
      );

      // 30° intervals with 12 frames → ~57% overlap (marginal)
      final scoreBad = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: const PanoramaCaptureMetadata(
          totalRotationDeg: 360,
          validFrameCount: 12,
          captureIntervalDeg: 30,
        ),
      );

      print('Overlap quality: 10°/${scoreGood.overlapQuality.toStringAsFixed(1)} '
          'vs 30°/${scoreBad.overlapQuality.toStringAsFixed(1)}');

      expect(scoreGood.overlapQuality, greaterThan(scoreBad.overlapQuality),
          reason: '10° interval should have better overlap than 30°');
    });

    test('image with strong vertical seams gets low stitch integrity', () async {
      final image = img.Image(width: 800, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          // Every 100 pixels, add a sharp vertical brightness jump (simulates seam)
          if (x % 100 < 2) {
            image.setPixelRgb(x, y, 255, 255, 255);
          } else {
            image.setPixelRgb(x, y, 80, 80, 80);
          }
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}seamy.jpg';
      File(path).writeAsBytesSync(
          Uint8List.fromList(img.encodeJpg(image, quality: 95)));

      final score = await PanoramaQualityAnalyzer.analyze(File(path));

      print('Seamy image:');
      print('  stitchIntegrity=${score.stitchIntegrity.toStringAsFixed(1)}');
      print('  overall=${score.overall.toStringAsFixed(1)}');

      // Strong vertical seams should be detected
      expect(score.stitchIntegrity, lessThan(90),
          reason: 'Strong vertical seams should lower stitch integrity');
    });

    test('blurry image gets low sharpness score', () async {
      // Create a very blurry (uniform) image
      final image = img.Image(width: 400, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 400; x++) {
          image.setPixelRgb(x, y, 128, 128, 128); // perfectly uniform = 0 Laplacian
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}blurry.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final score = await PanoramaQualityAnalyzer.analyze(File(path));
      print('Blurry image sharpness: ${score.sharpness.toStringAsFixed(1)}');
      expect(score.sharpness, lessThan(30),
          reason: 'A uniform image should score very low on sharpness');
    });
  });

  // ─────────────────────────────────────────────
  // PanoramaPostProcessor
  // ─────────────────────────────────────────────

  group('PanoramaPostProcessor', () {
    test('enforces 2:1 aspect ratio on too-wide image', () async {
      final image = img.Image(width: 1000, height: 300);
      for (int y = 0; y < 300; y++) {
        for (int x = 0; x < 1000; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}wide.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final result = await PanoramaPostProcessor.process(File(path));
      expect(result.existsSync(), isTrue);

      final processed = img.decodeJpg(result.readAsBytesSync());
      expect(processed, isNotNull);
      final ratio = processed!.width / processed.height;
      print('Wide input: 1000×300 → ${processed.width}×${processed.height} '
          '(ratio ${ratio.toStringAsFixed(2)}:1)');
      expect(ratio, closeTo(2.0, 0.15));
    });

    test('enforces 2:1 aspect ratio on too-tall image', () async {
      final image = img.Image(width: 600, height: 600);
      for (int y = 0; y < 600; y++) {
        for (int x = 0; x < 600; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}tall.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final result = await PanoramaPostProcessor.process(File(path));
      final processed = img.decodeJpg(result.readAsBytesSync());
      expect(processed, isNotNull);
      final ratio = processed!.width / processed.height;
      print('Tall input: 600×600 → ${processed.width}×${processed.height} '
          '(ratio ${ratio.toStringAsFixed(2)}:1)');
      expect(ratio, closeTo(2.0, 0.15));
    });

    test('leaves 2:1 image mostly unchanged', () async {
      final image = img.Image(width: 800, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          image.setPixelRgb(x, y, 100, 150, 200);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}good_ratio.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final result = await PanoramaPostProcessor.process(File(path));
      final processed = img.decodeJpg(result.readAsBytesSync());
      expect(processed, isNotNull);
      final ratio = processed!.width / processed.height;
      expect(ratio, closeTo(2.0, 0.15));
    });

    test('downscales very large images', () async {
      // Create a 4096×2048 image (larger than 2048 limit)
      final image = img.Image(width: 4096, height: 2048);
      for (int y = 0; y < 2048; y += 4) {
        for (int x = 0; x < 4096; x += 4) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}huge.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final result = await PanoramaPostProcessor.process(File(path));
      final processed = img.decodeJpg(result.readAsBytesSync());
      expect(processed, isNotNull);
      expect(processed!.width, lessThanOrEqualTo(2048));
      print('Large input: 4096×2048 → ${processed.width}×${processed.height}');
    });
  });

  // ─────────────────────────────────────────────
  // Subsample logic verification (pure math, no native deps)
  // ─────────────────────────────────────────────

  group('Subsample coverage analysis', () {
    test('36 frames at 10° subsampled to various sizes', () {
      const estimatedFovDeg = 70.0;

      for (final maxFrames in [8, 12, 16, 20, 36]) {
        final totalFrames = 36;
        final effectiveFrames =
            totalFrames <= maxFrames ? totalFrames : maxFrames;

        // With 36 frames at 10° = 360° total rotation
        // Subsampled to N frames → step = 360/N degrees between frames
        final angularStep = 360.0 / effectiveFrames;
        final overlapPercent =
            ((estimatedFovDeg - angularStep) / estimatedFovDeg * 100)
                .clamp(0, 100);

        print('maxFrames=$maxFrames: '
            '${effectiveFrames} frames used, '
            '${angularStep.toStringAsFixed(1)}° between frames, '
            '${overlapPercent.toStringAsFixed(0)}% overlap');

        // Minimum 40% overlap needed for reliable stitching
        if (maxFrames >= 12) {
          expect(overlapPercent, greaterThanOrEqualTo(40),
              reason:
                  'maxFrames=$maxFrames should maintain >=40% overlap');
        }
      }
    });

    test('capture interval vs overlap quality', () {
      const estimatedFovDeg = 70.0;

      for (final interval in [5.0, 10.0, 15.0, 20.0, 30.0]) {
        final overlapPercent =
            ((estimatedFovDeg - interval) / estimatedFovDeg * 100).clamp(0, 100);
        final framesPerFullRotation = (360 / interval).ceil();

        print('interval=${interval.toInt()}°: '
            '${framesPerFullRotation} frames for 360°, '
            '${overlapPercent.toStringAsFixed(0)}% overlap');
      }
    });

    test('subsample verification: 36→16 preserves coverage', () {
      final paths = List.generate(36, (i) => 'frame_$i.jpg');
      final yaws = List.generate(36, (i) => i * 10.0);
      const maxFrames = 16;

      final step = paths.length / maxFrames;
      final sampledIndices =
          List.generate(maxFrames, (i) => (i * step).floor());
      final sampledYaws = sampledIndices.map((i) => yaws[i]).toList();

      // Check that the gaps between consecutive sampled frames are reasonable
      double maxGap = 0;
      for (int i = 1; i < sampledYaws.length; i++) {
        final gap = sampledYaws[i] - sampledYaws[i - 1];
        if (gap > maxGap) maxGap = gap;
      }

      print('36→$maxFrames: max angular gap = ${maxGap.toStringAsFixed(1)}°');
      expect(maxGap, lessThanOrEqualTo(30),
          reason: 'Max gap between subsampled frames should be ≤ 30°');

      // With 70° FOV and ≤30° gap → ≥57% overlap → stitchable
      final overlapPercent = ((70 - maxGap) / 70 * 100);
      print('  → minimum overlap = ${overlapPercent.toStringAsFixed(0)}%');
      expect(overlapPercent, greaterThanOrEqualTo(50));
    });
  });
}
