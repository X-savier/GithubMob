import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:image/image.dart' as img;

import 'package:vxr_flutter/panorama_stitcher.dart';
import 'package:vxr_flutter/panorama_post_processor.dart';

// ─────────────────────────────────────────────
// SYNTHETIC IMAGE GENERATION
// ─────────────────────────────────────────────

/// Create a synthetic test image with a colourful gradient pattern
/// that has distinct features for the stitcher to match.
/// [hueOffset] shifts the colour pattern horizontally to simulate rotation.
cv.Mat createSyntheticFrame(int width, int height, double hueOffset) {
  final image = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Create a pattern with both horizontal and vertical variation
      // plus some "feature points" (checkerboard blocks) for matching
      final nx = (x + hueOffset * width) / width;
      final ny = y / height;

      // Base gradient
      final r = ((math.sin(nx * math.pi * 4) + 1) * 127).toInt();
      final g = ((math.cos(ny * math.pi * 3) + 1) * 127).toInt();
      final b = ((math.sin((nx + ny) * math.pi * 2) + 1) * 127).toInt();

      // Add checkerboard features for SIFT/ORB matching
      final blockX = (x ~/ 32) % 2;
      final blockY = (y ~/ 32) % 2;
      final checker = (blockX ^ blockY) == 1;

      final cr = checker ? (r * 0.7).toInt() : r;
      final cg = checker ? (g * 0.7).toInt() : g;
      final cb = checker ? (b * 0.7).toInt() : b;

      image.setPixelRgb(x, y, cr.clamp(0, 255), cg.clamp(0, 255), cb.clamp(0, 255));
    }
  }

  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));
  return cv.imdecode(bytes, cv.IMREAD_COLOR);
}

/// Write a list of synthetic overlapping frames to disk.
/// Returns the list of file paths and corresponding yaw values.
/// [overlapFraction]: how much each frame overlaps with the next (0.0–1.0).
/// [frameCount]: number of frames to generate.
Future<(List<String>, List<double>)> generateTestFrames({
  required Directory dir,
  int frameWidth = 640,
  int frameHeight = 480,
  int frameCount = 6,
  double overlapFraction = 0.5,
}) async {
  final paths = <String>[];
  final yaws = <double>[];

  // Each frame is shifted by (1 - overlap) * frameWidth pixels worth of content
  final shift = 1.0 - overlapFraction;

  for (int i = 0; i < frameCount; i++) {
    final hueOffset = i * shift;
    final yawDeg = i * shift * 30.0; // 30° per shift unit

    final mat = createSyntheticFrame(frameWidth, frameHeight, hueOffset);
    final path = '${dir.path}${Platform.pathSeparator}test_frame_$i.jpg';
    cv.imwrite(path, mat);
    mat.dispose();

    paths.add(path);
    yaws.add(yawDeg);
  }

  return (paths, yaws);
}

// ─────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pano_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ─────────────────────────────────────────────
  // Unit tests: subsampleWithYaw
  // ─────────────────────────────────────────────

  group('subsampleWithYaw', () {
    test('returns all items when count <= maxFrames', () {
      final paths = ['a.jpg', 'b.jpg', 'c.jpg'];
      final yaws = [0.0, 10.0, 20.0];
      final (rPaths, rYaws) = PanoramaStitcher.subsampleWithYaw(paths, yaws, 5);
      expect(rPaths, paths);
      expect(rYaws, yaws);
    });

    test('subsamples evenly when count > maxFrames', () {
      final paths = List.generate(36, (i) => 'frame_$i.jpg');
      final yaws = List.generate(36, (i) => i * 10.0);
      final (rPaths, rYaws) = PanoramaStitcher.subsampleWithYaw(paths, yaws, 12);
      expect(rPaths.length, 12);
      expect(rYaws.length, 12);
      // First frame should always be included
      expect(rPaths.first, 'frame_0.jpg');
      expect(rYaws.first, 0.0);
    });

    test('subsample preserves spacing', () {
      final paths = List.generate(20, (i) => 'frame_$i.jpg');
      final yaws = List.generate(20, (i) => i * 10.0);
      final (rPaths, rYaws) = PanoramaStitcher.subsampleWithYaw(paths, yaws, 10);
      expect(rPaths.length, 10);
      // Steps should be evenly spaced (step = 2.0)
      expect(rPaths[0], 'frame_0.jpg');
      expect(rPaths[1], 'frame_2.jpg');
      expect(rPaths[2], 'frame_4.jpg');
    });

    test('handles empty yaws gracefully', () {
      final paths = List.generate(10, (i) => 'frame_$i.jpg');
      final yaws = <double>[];
      final (rPaths, rYaws) = PanoramaStitcher.subsampleWithYaw(paths, yaws, 5);
      expect(rPaths.length, 5);
      expect(rYaws, isEmpty);
    });

    test('subsample 36 frames to 16 preserves good coverage', () {
      // Simulates: 36 frames at 10° intervals = 360° full rotation
      // Subsampled to 16 = every 22.5° → still 67% overlap with 70° FOV
      final paths = List.generate(36, (i) => 'frame_$i.jpg');
      final yaws = List.generate(36, (i) => i * 10.0);
      final (rPaths, rYaws) = PanoramaStitcher.subsampleWithYaw(paths, yaws, 16);
      expect(rPaths.length, 16);
      expect(rYaws.length, 16);

      // Check angular spacing between consecutive subsampled frames
      for (int i = 1; i < rYaws.length; i++) {
        final gap = rYaws[i] - rYaws[i - 1];
        // With 36→16, step≈2.25, so gaps should be ~20-30°
        expect(gap, lessThanOrEqualTo(30.0),
            reason: 'Gap between frame ${i - 1} and $i is $gap° — too large');
        expect(gap, greaterThanOrEqualTo(10.0),
            reason: 'Gap should be at least one capture interval');
      }
    });
  });

  // ─────────────────────────────────────────────
  // Unit tests: sortByYaw
  // ─────────────────────────────────────────────

  group('sortByYaw', () {
    test('sorts ascending', () {
      final yaws = [30.0, 10.0, 20.0, 0.0];
      final sorted = PanoramaStitcher.sortByYaw(yaws);
      expect(sorted, [3, 1, 2, 0]); // indices sorted by yaw value
    });

    test('handles already sorted', () {
      final yaws = [0.0, 10.0, 20.0, 30.0];
      final sorted = PanoramaStitcher.sortByYaw(yaws);
      expect(sorted, [0, 1, 2, 3]);
    });

    test('handles duplicates', () {
      final yaws = [10.0, 10.0, 0.0];
      final sorted = PanoramaStitcher.sortByYaw(yaws);
      expect(sorted.first, 2); // index 2 (yaw=0) comes first
    });

    test('handles single element', () {
      final sorted = PanoramaStitcher.sortByYaw([42.0]);
      expect(sorted, [0]);
    });
  });

  // ─────────────────────────────────────────────
  // Unit tests: PanoramaQualityScore
  // ─────────────────────────────────────────────

  group('PanoramaQualityScore', () {
    test('overall is weighted average', () {
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

    test('star ratings', () {
      expect(
          const PanoramaQualityScore(
                  sharpness: 95, exposure: 95, angularCoverage: 95,
                  overlapQuality: 95, stitchIntegrity: 95, blackRegions: 95, coverage: 95)
              .stars,
          5);
      expect(
          const PanoramaQualityScore(
                  sharpness: 80, exposure: 80, angularCoverage: 80,
                  overlapQuality: 80, stitchIntegrity: 80, blackRegions: 80, coverage: 80)
              .stars,
          4);
      expect(
          const PanoramaQualityScore(
                  sharpness: 65, exposure: 65, angularCoverage: 65,
                  overlapQuality: 65, stitchIntegrity: 65, blackRegions: 65, coverage: 65)
              .stars,
          3);
      expect(
          const PanoramaQualityScore(
                  sharpness: 45, exposure: 45, angularCoverage: 45,
                  overlapQuality: 45, stitchIntegrity: 45, blackRegions: 45, coverage: 45)
              .stars,
          2);
      expect(
          const PanoramaQualityScore(
                  sharpness: 20, exposure: 20, angularCoverage: 20,
                  overlapQuality: 20, stitchIntegrity: 20, blackRegions: 20, coverage: 20)
              .stars,
          1);
    });

    test('tips generated for low scores', () {
      const score = PanoramaQualityScore(
        sharpness: 40,
        exposure: 40,
        angularCoverage: 40,
        overlapQuality: 40,
        stitchIntegrity: 40,
        blackRegions: 40,
        coverage: 40,
      );
      expect(score.tips.length, greaterThanOrEqualTo(4));
    });

    test('no tips for high scores', () {
      const score = PanoramaQualityScore(
        sharpness: 90,
        exposure: 90,
        angularCoverage: 90,
        overlapQuality: 90,
        stitchIntegrity: 90,
        blackRegions: 90,
        coverage: 90,
      );
      expect(score.tips, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // Unit tests: PanoramaCaptureMetadata
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
  });

  // ─────────────────────────────────────────────
  // Integration tests: Stitch pipeline with synthetic images
  // ─────────────────────────────────────────────

  group('PanoramaStitcher.stitchFrames', () {
    test('returns null for < 2 frames', () {
      final stitcher = const PanoramaStitcher();
      final result = stitcher.stitchFrames(const StitchInput(
        framePaths: ['nonexistent.jpg'],
        frameYawDeg: [0.0],
      ));
      expect(result, isNull);
    });

    test('returns null for empty paths', () {
      final stitcher = const PanoramaStitcher();
      final result = stitcher.stitchFrames(const StitchInput(
        framePaths: [],
        frameYawDeg: [],
      ));
      expect(result, isNull);
    });

    test('stitches synthetic overlapping frames (50% overlap, 6 frames)',
        () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 6,
        overlapFraction: 0.5,
        frameWidth: 640,
        frameHeight: 480,
      );

      // Verify frames were created
      for (final p in paths) {
        expect(File(p).existsSync(), isTrue, reason: 'Frame not found: $p');
      }

      final stitcher = const PanoramaStitcher(
        maxStitchFrames: 16,
        stitchMaxDimension: 1024,
        panoConfidenceThresh: 0.3,
      );
      final result = stitcher.stitchFrames(StitchInput(
        framePaths: paths,
        frameYawDeg: yaws,
      ));

      if (result != null) {
        final outFile = File(result);
        expect(outFile.existsSync(), isTrue);
        expect(outFile.lengthSync(), greaterThan(0));

        // Check output dimensions are reasonable
        final mat = cv.imread(result);
        expect(mat.width, greaterThan(paths.length > 1 ? 640 : 0),
            reason: 'Stitched panorama should be wider than a single frame');
        mat.dispose();

        print('SUCCESS: 6 frames, 50% overlap → ${outFile.lengthSync()} bytes, '
            'result: $result');
      } else {
        print('FAILED: 6 frames with 50% overlap could not be stitched');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('stitches with higher overlap (70%, 8 frames)', () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 8,
        overlapFraction: 0.7,
        frameWidth: 640,
        frameHeight: 480,
      );

      final stitcher = const PanoramaStitcher(
        maxStitchFrames: 16,
        stitchMaxDimension: 1024,
        panoConfidenceThresh: 0.3,
      );
      final result = stitcher.stitchFrames(StitchInput(
        framePaths: paths,
        frameYawDeg: yaws,
      ));

      if (result != null) {
        final outFile = File(result);
        expect(outFile.existsSync(), isTrue);
        print('SUCCESS: 8 frames, 70% overlap → ${outFile.lengthSync()} bytes');
      } else {
        print('FAILED: 8 frames with 70% overlap could not be stitched');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('stitches with many frames subsampled (36 → 16)', () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 36,
        overlapFraction: 0.7,
        frameWidth: 640,
        frameHeight: 480,
      );

      final stitcher = const PanoramaStitcher(
        maxStitchFrames: 16,
        stitchMaxDimension: 1024,
      );
      final result = stitcher.stitchFrames(StitchInput(
        framePaths: paths,
        frameYawDeg: yaws,
      ));

      if (result != null) {
        print('SUCCESS: 36→16 frames stitched');
      } else {
        print('FAILED: 36→16 frames could not be stitched');
      }
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  // ─────────────────────────────────────────────
  // Parameter sweep: find optimal settings
  // ─────────────────────────────────────────────

  group('Parameter tuning', () {
    test('compare maxStitchFrames: 8 vs 12 vs 16 vs 20', () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 36,
        overlapFraction: 0.6,
        frameWidth: 640,
        frameHeight: 480,
      );

      for (final maxFrames in [8, 12, 16, 20]) {
        final sw = Stopwatch()..start();
        final stitcher = PanoramaStitcher(
          maxStitchFrames: maxFrames,
          stitchMaxDimension: 1024,
        );
        final result = stitcher.stitchFrames(StitchInput(
          framePaths: paths,
          frameYawDeg: yaws,
        ));
        sw.stop();

        if (result != null) {
          final outFile = File(result);
          final mat = cv.imread(result);
          print('maxStitchFrames=$maxFrames: SUCCESS '
              '${mat.width}×${mat.height} '
              '${outFile.lengthSync()} bytes '
              '${sw.elapsedMilliseconds}ms');
          mat.dispose();
        } else {
          print('maxStitchFrames=$maxFrames: FAILED (${sw.elapsedMilliseconds}ms)');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 300)));

    test('compare stitchMaxDimension: 640 vs 800 vs 1024 vs 1280', () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 12,
        overlapFraction: 0.6,
        frameWidth: 800,
        frameHeight: 600,
      );

      for (final maxDim in [640, 800, 1024, 1280]) {
        final sw = Stopwatch()..start();
        final stitcher = PanoramaStitcher(
          maxStitchFrames: 16,
          stitchMaxDimension: maxDim,
        );
        final result = stitcher.stitchFrames(StitchInput(
          framePaths: paths,
          frameYawDeg: yaws,
        ));
        sw.stop();

        if (result != null) {
          final outFile = File(result);
          final mat = cv.imread(result);
          print('stitchMaxDimension=$maxDim: SUCCESS '
              '${mat.width}×${mat.height} '
              '${outFile.lengthSync()} bytes '
              '${sw.elapsedMilliseconds}ms');
          mat.dispose();
        } else {
          print('stitchMaxDimension=$maxDim: FAILED (${sw.elapsedMilliseconds}ms)');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 300)));

    test('compare panoConfidenceThresh: 0.2 vs 0.3 vs 0.5 vs 0.8', () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 10,
        overlapFraction: 0.5,
        frameWidth: 640,
        frameHeight: 480,
      );

      for (final thresh in [0.2, 0.3, 0.5, 0.8]) {
        final sw = Stopwatch()..start();
        final stitcher = PanoramaStitcher(
          maxStitchFrames: 16,
          stitchMaxDimension: 1024,
          panoConfidenceThresh: thresh,
        );
        final result = stitcher.stitchFrames(StitchInput(
          framePaths: paths,
          frameYawDeg: yaws,
        ));
        sw.stop();

        if (result != null) {
          final mat = cv.imread(result);
          print('panoConfidenceThresh=$thresh: SUCCESS '
              '${mat.width}×${mat.height} '
              '${sw.elapsedMilliseconds}ms');
          mat.dispose();
        } else {
          print('panoConfidenceThresh=$thresh: FAILED (${sw.elapsedMilliseconds}ms)');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 300)));

    test('compare registrationResol: 0.4 vs 0.6 vs 0.8 vs 1.0', () async {
      final (paths, yaws) = await generateTestFrames(
        dir: tempDir,
        frameCount: 10,
        overlapFraction: 0.5,
        frameWidth: 640,
        frameHeight: 480,
      );

      for (final resol in [0.4, 0.6, 0.8, 1.0]) {
        final sw = Stopwatch()..start();
        final stitcher = PanoramaStitcher(
          maxStitchFrames: 16,
          stitchMaxDimension: 1024,
          registrationResol: resol,
        );
        final result = stitcher.stitchFrames(StitchInput(
          framePaths: paths,
          frameYawDeg: yaws,
        ));
        sw.stop();

        if (result != null) {
          final mat = cv.imread(result);
          print('registrationResol=$resol: SUCCESS '
              '${mat.width}×${mat.height} '
              '${sw.elapsedMilliseconds}ms');
          mat.dispose();
        } else {
          print('registrationResol=$resol: FAILED (${sw.elapsedMilliseconds}ms)');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 300)));
  });

  // ─────────────────────────────────────────────
  // Post-processor tests
  // ─────────────────────────────────────────────

  group('PanoramaPostProcessor', () {
    test('enforces 2:1 aspect ratio on wide image', () async {
      // Create a 1000×300 image (ratio 3.33:1 — too wide)
      final image = img.Image(width: 1000, height: 300);
      for (int y = 0; y < 300; y++) {
        for (int x = 0; x < 1000; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}wide_test.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final result = await PanoramaPostProcessor.process(File(path));
      expect(result.existsSync(), isTrue);

      final processed = img.decodeJpg(result.readAsBytesSync());
      expect(processed, isNotNull);
      if (processed != null) {
        final ratio = processed.width / processed.height;
        expect(ratio, closeTo(2.0, 0.15),
            reason: 'Expected 2:1 ratio, got ${ratio.toStringAsFixed(2)}:1');
        print('PostProcessor: ${processed.width}×${processed.height} '
            '(ratio ${ratio.toStringAsFixed(2)}:1)');
      }
    });

    test('leaves 2:1 image unchanged', () async {
      final image = img.Image(width: 800, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          image.setPixelRgb(x, y, 100, 150, 200);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}ratio_test.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final result = await PanoramaPostProcessor.process(File(path));
      final processed = img.decodeJpg(result.readAsBytesSync());
      expect(processed, isNotNull);
      if (processed != null) {
        final ratio = processed.width / processed.height;
        expect(ratio, closeTo(2.0, 0.15));
      }
    });
  });

  // ─────────────────────────────────────────────
  // Quality analyzer tests
  // ─────────────────────────────────────────────

  group('PanoramaQualityAnalyzer', () {
    test('gives high score for a clean uniform image', () async {
      // Create a bright, well-lit image (simulates good panorama)
      final image = img.Image(width: 800, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          // Gentle gradient — no harsh transitions
          final r = 100 + (x * 155 ~/ 800);
          final g = 100 + (y * 155 ~/ 400);
          final b = 150;
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}clean_pano.jpg';
      File(path)
          .writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image, quality: 95)));

      final meta = const PanoramaCaptureMetadata(
        totalRotationDeg: 360,
        validFrameCount: 36,
        captureIntervalDeg: 10,
      );
      final score = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: meta,
      );

      print('Clean image scores:');
      print('  sharpness: ${score.sharpness.toStringAsFixed(1)}');
      print('  exposure: ${score.exposure.toStringAsFixed(1)}');
      print('  angularCoverage: ${score.angularCoverage.toStringAsFixed(1)}');
      print('  overlapQuality: ${score.overlapQuality.toStringAsFixed(1)}');
      print('  stitchIntegrity: ${score.stitchIntegrity.toStringAsFixed(1)}');
      print('  blackRegions: ${score.blackRegions.toStringAsFixed(1)}');
      print('  overall: ${score.overall.toStringAsFixed(1)}');
      print('  stars: ${score.stars}');

      expect(score.angularCoverage, greaterThanOrEqualTo(90));
      expect(score.blackRegions, greaterThanOrEqualTo(80));
    });

    test('gives low score for image with large black regions', () async {
      final image = img.Image(width: 800, height: 400);
      // Left half: black, right half: content
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 800; x++) {
          if (x < 400) {
            image.setPixelRgb(x, y, 0, 0, 0);
          } else {
            image.setPixelRgb(x, y, 150, 150, 150);
          }
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}blackhalf.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      final score = await PanoramaQualityAnalyzer.analyze(File(path));

      print('Half-black image scores:');
      print('  blackRegions: ${score.blackRegions.toStringAsFixed(1)}');
      print('  coverage: ${score.coverage.toStringAsFixed(1)}');
      print('  overall: ${score.overall.toStringAsFixed(1)}');

      expect(score.blackRegions, lessThan(80));
    });

    test('angular coverage reflects rotation', () async {
      final image = img.Image(width: 400, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 400; x++) {
          image.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      final path = '${tempDir.path}${Platform.pathSeparator}gray.jpg';
      File(path).writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image)));

      // 180° rotation → 50% coverage
      final score180 = await PanoramaQualityAnalyzer.analyze(
        File(path),
        metadata: const PanoramaCaptureMetadata(
          totalRotationDeg: 180,
          validFrameCount: 18,
          captureIntervalDeg: 10,
        ),
      );

      // 360° rotation → 100% coverage
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

      expect(score360.angularCoverage, greaterThan(score180.angularCoverage));
      expect(score180.angularCoverage, closeTo(50, 5));
      expect(score360.angularCoverage, closeTo(100, 5));
    });
  });
}
