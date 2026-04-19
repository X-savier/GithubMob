import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────
// CAPTURE METADATA (passed from capture screen)
// ─────────────────────────────────────────────

/// Metadata collected during the panoramic sweep, used by the quality
/// analyzer to evaluate angular coverage and frame overlap.
class PanoramaCaptureMetadata {
  /// Total angular rotation measured by the gyroscope (degrees).
  final double totalRotationDeg;

  /// Number of frames that were actually saved to disk.
  final int validFrameCount;

  /// Capture interval in degrees between auto-snaps.
  final double captureIntervalDeg;

  /// Expected full rotation target (typically 360°).
  final double targetRotationDeg;

  const PanoramaCaptureMetadata({
    required this.totalRotationDeg,
    required this.validFrameCount,
    required this.captureIntervalDeg,
    this.targetRotationDeg = 360.0,
  });
}

// ─────────────────────────────────────────────
// QUALITY SCORE MODEL
// ─────────────────────────────────────────────

class PanoramaQualityScore {
  final double sharpness;        // 0–100: image clarity
  final double exposure;         // 0–100: lighting uniformity
  final double coverage;         // 0–100: non-black pixel ratio
  final double angularCoverage;  // 0–100: how close to 360° the sweep was
  final double overlapQuality;   // 0–100: estimated overlap between frames
  final double stitchIntegrity;  // 0–100: seam quality / artifact detection
  final double blackRegions;     // 0–100: absence of large black patches

  const PanoramaQualityScore({
    required this.sharpness,
    required this.exposure,
    required this.coverage,
    this.angularCoverage = 100,
    this.overlapQuality = 100,
    this.stitchIntegrity = 100,
    this.blackRegions = 100,
  });

  double get overall =>
      (sharpness * 0.15) +
      (exposure * 0.10) +
      (angularCoverage * 0.20) +
      (overlapQuality * 0.15) +
      (stitchIntegrity * 0.20) +
      (blackRegions * 0.20);

  int get stars {
    final s = overall;
    if (s >= 90) return 5;
    if (s >= 75) return 4;
    if (s >= 60) return 3;
    if (s >= 40) return 2;
    return 1;
  }

  String get label {
    final s = stars;
    if (s >= 5) return 'Excellent';
    if (s >= 4) return 'Good';
    if (s >= 3) return 'Fair';
    if (s >= 2) return 'Poor';
    return 'Very Poor';
  }

  List<String> get tips {
    final t = <String>[];
    if (angularCoverage < 60) {
      t.add(
          'Only ${angularCoverage.round()}% of a full 360° was captured — '
          'try completing the full rotation.');
    }
    if (blackRegions < 60) {
      t.add(
          'Large blank/black areas detected in the panorama — '
          'ensure consistent overlap while rotating.');
    }
    if (stitchIntegrity < 60) {
      t.add(
          'Visible seams or misalignment detected — '
          'rotate more slowly and keep the device level.');
    }
    if (overlapQuality < 60) {
      t.add(
          'Low overlap between consecutive frames — '
          'rotate more slowly so adjacent photos share more content.');
    }
    if (sharpness < 60) {
      t.add('Panorama looks blurry — try rotating more slowly and steadily.');
    }
    if (exposure < 60) {
      t.add(
          'Uneven lighting detected — try capturing in more consistent lighting.');
    }
    return t;
  }
}

// ─────────────────────────────────────────────
// POST-PROCESSOR
// ─────────────────────────────────────────────

class PanoramaPostProcessor {
  /// Enhance the stitched panorama: enforce 2:1 equirectangular ratio
  /// and export as high-quality JPEG.
  /// Returns the path to the enhanced image file.
  /// Designed to be memory-safe on mobile devices.
  static Future<File> process(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final enhanced = await compute(_processInIsolate, bytes);

    // If processing returned the same bytes, just return original file
    if (identical(enhanced, bytes)) return inputFile;

    final outPath =
        '${inputFile.parent.path}/pano_enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(enhanced);
    return outFile;
  }

  /// Runs on a separate isolate so the UI stays responsive.
  /// Kept minimal to avoid OOM on mobile: no convolution, no large buffers.
  static Uint8List _processInIsolate(Uint8List bytes) {
    // Decode at reduced size to avoid OOM.
    // The stitched panorama can be 8000+ px wide; decode to max 2048 wide.
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null) return bytes;

    final info = decoder.startDecode(bytes);
    if (info == null) return bytes;

    final origW = info.width;

    // If already small enough, decode at full size; otherwise resize on decode
    img.Image? image;
    if (origW <= 4096) {
      image = decoder.decode(bytes);
    } else {
      // Decode full then resize — but first check if it's dangerously large
      // (> 8000px wide = ~192MB raw). For very large images, decode and
      // immediately resize to keep peak memory lower.
      image = decoder.decode(bytes);
      if (image != null && image.width > 4096) {
        final targetW = 4096;
        final targetH = (image.height * targetW / image.width).round();
        image = img.copyResize(image,
            width: targetW,
            height: targetH,
            interpolation: img.Interpolation.average);
      }
    }

    if (image == null) return bytes;

    // Enforce equirectangular 2:1 aspect ratio
    image = _enforce2to1(image);

    // Encode as high-quality JPEG (no sharpening — saves memory)
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  static img.Image _enforce2to1(img.Image image) {
    final w = image.width;
    final h = image.height;
    final ratio = w / h;

    // Already within tolerance
    if ((ratio - 2.0).abs() < 0.1) return image;

    if (ratio > 2.0) {
      // Too wide → crop horizontally (center-crop)
      final newW = h * 2;
      final x = (w - newW) ~/ 2;
      return img.copyCrop(image, x: x, y: 0, width: newW, height: h);
    } else {
      // Too tall → crop vertically (center-crop)
      final newH = w ~/ 2;
      final y = (h - newH) ~/ 2;
      return img.copyCrop(image, x: 0, y: y, width: w, height: newH);
    }
  }
}

// ─────────────────────────────────────────────
// QUALITY ANALYZER
// ─────────────────────────────────────────────

/// Data bundle sent to the analysis isolate.
class _AnalysisInput {
  final Uint8List imageBytes;
  final PanoramaCaptureMetadata? metadata;

  _AnalysisInput(this.imageBytes, this.metadata);
}

class PanoramaQualityAnalyzer {
  /// Analyze the panorama and return quality scores.
  /// [metadata] provides capture-session context (rotation, frame count).
  static Future<PanoramaQualityScore> analyze(
    File file, {
    PanoramaCaptureMetadata? metadata,
  }) async {
    final bytes = await file.readAsBytes();
    return compute(_analyzeInIsolate, _AnalysisInput(bytes, metadata));
  }

  static PanoramaQualityScore _analyzeInIsolate(_AnalysisInput input) {
    final decoded = img.decodeJpg(input.imageBytes);
    if (decoded == null) {
      return const PanoramaQualityScore(
        sharpness: 50,
        exposure: 50,
        coverage: 50,
        angularCoverage: 50,
        overlapQuality: 50,
        stitchIntegrity: 50,
        blackRegions: 50,
      );
    }

    // Resize to 600px wide for analysis (fast, low memory)
    final image = decoded.width > 600
        ? img.copyResize(decoded,
            width: 600, interpolation: img.Interpolation.average)
        : decoded;

    final meta = input.metadata;

    return PanoramaQualityScore(
      sharpness: _measureSharpness(image),
      exposure: _measureExposureUniformity(image),
      coverage: _measureCoverage(image),
      angularCoverage: _measureAngularCoverage(meta),
      overlapQuality: _measureOverlapQuality(image, meta),
      stitchIntegrity: _measureStitchIntegrity(image),
      blackRegions: _measureBlackRegions(image),
    );
  }

  // ─── Angular Coverage ──────────────────────

  /// Evaluate how close to 360° the sweep actually achieved.
  /// 360° → 100, 180° → 50, etc. Bonus if slightly over 360° (wrap overlap).
  static double _measureAngularCoverage(PanoramaCaptureMetadata? meta) {
    if (meta == null) return 75; // no metadata → assume decent coverage
    final ratio = meta.totalRotationDeg / meta.targetRotationDeg;
    // 100% at 360°, linearly scaled. Allow up to 110% for wrap-around bonus.
    return (ratio * 100).clamp(0, 100).toDouble();
  }

  // ─── Overlap Quality ───────────────────────

  /// Estimate overlap between consecutive frames from capture metadata
  /// and image aspect ratio. At 10° intervals with a ~70° FOV, each
  /// pair should overlap ~86%. Lower intervals or wider spacing reduce
  /// overlap and hurt stitch quality.
  ///
  /// Also checks the stitched panorama for horizontal gradient consistency
  /// — poor overlap produces visible brightness jumps at stitch boundaries.
  static double _measureOverlapQuality(
      img.Image image, PanoramaCaptureMetadata? meta) {
    double score = 100;

    // Part 1: Estimate from capture metadata (50% weight)
    if (meta != null && meta.validFrameCount > 1) {
      // Approximate horizontal FOV of a phone camera: ~70°
      const estimatedFovDeg = 70.0;
      final actualIntervalDeg =
          meta.totalRotationDeg / (meta.validFrameCount - 1);
      // Overlap ratio: (FOV - interval) / FOV
      final overlapRatio =
          ((estimatedFovDeg - actualIntervalDeg) / estimatedFovDeg)
              .clamp(0.0, 1.0);
      // 85%+ overlap → 100, 30% overlap → 0
      final metaScore =
          ((overlapRatio - 0.30) / 0.55 * 100).clamp(0, 100).toDouble();
      score = metaScore;
    }

    // Part 2: Check for brightness jumps in horizontal strips (50% weight)
    final w = image.width;
    final h = image.height;
    if (w < 10) return score;

    // Sample 3 horizontal rows through the middle third of the image
    final rows = [h ~/ 3, h ~/ 2, (2 * h) ~/ 3];
    int jumpCount = 0;

    for (final row in rows) {
      double? prevLum;
      for (int x = 0; x < w; x += 2) {
        final lum = image.getPixel(x, row).luminance.toDouble();
        if (prevLum != null) {
          final diff = (lum - prevLum).abs();
          if (diff > 0.08) {
            jumpCount++;
          }
        }
        prevLum = lum;
      }
    }

    // Normalise: many big jumps → low score
    final jumpRate = jumpCount / (w / 2 * 3);
    final seamScore =
        ((0.15 - jumpRate) / 0.15 * 100).clamp(0, 100).toDouble();

    // Blend metadata-based and image-based scores
    if (meta != null) {
      return (score * 0.5 + seamScore * 0.5);
    }
    return seamScore;
  }

  // ─── Stitch Integrity ──────────────────────

  /// Detect stitching artifacts: ghosting, misaligned edges, and seams.
  ///
  /// Strategy: divide the image into vertical columns and measure edge
  /// consistency. Ghosting/misalignment creates strong vertical edge
  /// patterns at stitch boundaries that differ sharply from natural edges.
  static double _measureStitchIntegrity(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w < 20 || h < 20) return 100;

    // Convert to grayscale luminance for edge detection
    // Compute horizontal gradient magnitude (Sobel-like) at sampled points
    final columnEdgeStrength = <double>[];
    const step = 4; // sample every 4th column

    for (int x = 1; x < w - 1; x += step) {
      double edgeSum = 0;
      int count = 0;
      for (int y = 1; y < h - 1; y += 4) {
        final left = image.getPixel(x - 1, y).luminance.toDouble();
        final right = image.getPixel(x + 1, y).luminance.toDouble();
        edgeSum += (right - left).abs();
        count++;
      }
      columnEdgeStrength.add(count > 0 ? edgeSum / count : 0);
    }

    if (columnEdgeStrength.length < 3) return 100;

    // Compute mean and std-dev of column edge strengths
    final mean =
        columnEdgeStrength.reduce((a, b) => a + b) / columnEdgeStrength.length;
    final variance = columnEdgeStrength
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        columnEdgeStrength.length;
    final stdDev = math.sqrt(variance);

    // Count columns with edge strength > mean + 2*stdDev (spike = seam)
    final threshold = mean + 2 * stdDev;
    int spikeCount = 0;
    for (final e in columnEdgeStrength) {
      if (e > threshold && e > 0.05) spikeCount++;
    }

    // Normalise: 0 spikes → 100, many spikes → low score
    final spikeRatio = spikeCount / columnEdgeStrength.length;
    return ((0.10 - spikeRatio) / 0.10 * 100).clamp(0, 100).toDouble();
  }

  // ─── Black Region Detection ────────────────

  /// Detect large contiguous black/empty regions in the output panorama.
  /// These indicate gaps where the stitcher couldn't fill in content.
  ///
  /// Uses a grid-based approach: divide into cells and flag cells that
  /// are predominantly black. Clusters of black cells reduce the score.
  static double _measureBlackRegions(img.Image image) {
    final w = image.width;
    final h = image.height;
    const gx = 16, gy = 8; // 16×8 grid = 128 cells
    final cellW = w ~/ gx;
    final cellH = h ~/ gy;
    if (cellW < 2 || cellH < 2) return 100;

    int blackCellCount = 0;
    int totalCells = 0;
    // Track which cells are black for cluster detection
    final blackGrid = List.generate(gy, (_) => List.filled(gx, false));

    for (int row = 0; row < gy; row++) {
      for (int col = 0; col < gx; col++) {
        int darkPixels = 0;
        int total = 0;
        final sx = col * cellW;
        final sy = row * cellH;

        for (int y = sy; y < sy + cellH && y < h; y += 2) {
          for (int x = sx; x < sx + cellW && x < w; x += 2) {
            if (image.getPixel(x, y).luminance < 0.04) darkPixels++;
            total++;
          }
        }

        totalCells++;
        // Cell is "black" if > 80% of sampled pixels are near-black
        if (total > 0 && darkPixels / total > 0.80) {
          blackCellCount++;
          blackGrid[row][col] = true;
        }
      }
    }

    if (totalCells == 0) return 100;

    // Find the largest cluster of black cells (BFS flood fill)
    int largestCluster = 0;
    final visited = List.generate(gy, (_) => List.filled(gx, false));
    for (int r = 0; r < gy; r++) {
      for (int c = 0; c < gx; c++) {
        if (blackGrid[r][c] && !visited[r][c]) {
          // BFS
          int clusterSize = 0;
          final queue = <(int, int)>[(r, c)];
          visited[r][c] = true;
          while (queue.isNotEmpty) {
            final (cr, cc) = queue.removeAt(0);
            clusterSize++;
            for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
              final nr = cr + dr, nc = cc + dc;
              if (nr >= 0 &&
                  nr < gy &&
                  nc >= 0 &&
                  nc < gx &&
                  blackGrid[nr][nc] &&
                  !visited[nr][nc]) {
                visited[nr][nc] = true;
                queue.add((nr, nc));
              }
            }
          }
          if (clusterSize > largestCluster) largestCluster = clusterSize;
        }
      }
    }

    // Score based on both total black cells and largest cluster size
    final blackRatio = blackCellCount / totalCells;
    final clusterRatio = largestCluster / totalCells;

    // Weight cluster ratio more heavily — scattered dark pixels are OK
    // (could be dark scene), but a large contiguous black patch is a gap.
    final rawScore = 1.0 - (blackRatio * 0.3 + clusterRatio * 0.7);
    // Scale: 0% black → 100, 15%+ clustered black → 0
    return (rawScore / 0.85 * 100).clamp(0, 100).toDouble();
  }

  // ─── Original Metrics ─────────────────────

  /// Laplacian-variance sharpness metric (sampled every 2nd pixel).
  static double _measureSharpness(img.Image image) {
    final w = image.width;
    final h = image.height;
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < h - 1; y += 2) {
      for (int x = 1; x < w - 1; x += 2) {
        final c = image.getPixel(x, y).luminance.toDouble();
        final t = image.getPixel(x, y - 1).luminance.toDouble();
        final b = image.getPixel(x, y + 1).luminance.toDouble();
        final l = image.getPixel(x - 1, y).luminance.toDouble();
        final r = image.getPixel(x + 1, y).luminance.toDouble();
        final lap = (4 * c - t - b - l - r).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    // Empirical: variance <20 → very blurry, >400 → very sharp
    return ((variance - 20) / 380 * 100).clamp(0, 100).toDouble();
  }

  /// Grid-based exposure uniformity (8×4 cells).
  /// Lower standard deviation of cell brightness → more uniform.
  static double _measureExposureUniformity(img.Image image) {
    final w = image.width;
    final h = image.height;
    const gx = 8, gy = 4;
    final cellW = w ~/ gx;
    final cellH = h ~/ gy;
    final cells = <double>[];

    for (int row = 0; row < gy; row++) {
      for (int col = 0; col < gx; col++) {
        double s = 0;
        int n = 0;
        final sx = col * cellW;
        final sy = row * cellH;
        for (int y = sy; y < sy + cellH && y < h; y += 4) {
          for (int x = sx; x < sx + cellW && x < w; x += 4) {
            s += image.getPixel(x, y).luminance.toDouble();
            n++;
          }
        }
        if (n > 0) cells.add(s / n);
      }
    }

    if (cells.isEmpty) return 50;
    final mean = cells.reduce((a, b) => a + b) / cells.length;
    final variance =
        cells.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            cells.length;
    final stdDev = math.sqrt(variance);
    // std-dev <8 → 100, >55 → 0
    return ((55 - stdDev) / 47 * 100).clamp(0, 100).toDouble();
  }

  /// Coverage: percentage of non-black pixels.
  /// Large dark patches indicate gaps in the panorama.
  static double _measureCoverage(img.Image image) {
    final w = image.width;
    final h = image.height;
    int dark = 0, total = 0;

    for (int y = 0; y < h; y += 3) {
      for (int x = 0; x < w; x += 3) {
        if (image.getPixel(x, y).luminance < 12) dark++;
        total++;
      }
    }

    if (total == 0) return 100;
    final darkRatio = dark / total;
    // 0% dark → 100, ≥5% dark → 0
    return ((0.05 - darkRatio) / 0.05 * 100).clamp(0, 100).toDouble();
  }
}
