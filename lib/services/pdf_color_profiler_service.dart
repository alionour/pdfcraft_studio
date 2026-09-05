import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

enum GrayscaleAlgorithm {
  luminance,
  desaturate,
  highContrastMono,
  inkSaver,
}

class ColorCoverageReport {
  final double colorPercentage; // 0.0 to 100.0%
  final double monochromePercentage;
  final double inkSavingPotential;
  final String recommendation;

  const ColorCoverageReport({
    required this.colorPercentage,
    required this.monochromePercentage,
    required this.inkSavingPotential,
    required this.recommendation,
  });

  bool get isPredominantlyMonochrome => monochromePercentage >= 80.0;
}

class PdfColorProfilerService {
  /// Analyzes an image to determine color coverage vs monochrome pixels
  static ColorCoverageReport analyzeColorCoverage(img.Image image) {
    if (image.width == 0 || image.height == 0) {
      return const ColorCoverageReport(
        colorPercentage: 0.0,
        monochromePercentage: 100.0,
        inkSavingPotential: 0.0,
        recommendation: 'Document is empty.',
      );
    }

    int colorPixelCount = 0;
    int monochromePixelCount = 0;
    int darkPixelCount = 0;
    final int totalPixels = image.width * image.height;

    for (final pixel in image) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Check max delta between RGB channels
      final maxChannel = [r, g, b].reduce((curr, next) => curr > next ? curr : next);
      final minChannel = [r, g, b].reduce((curr, next) => curr < next ? curr : next);
      final saturationDelta = maxChannel - minChannel;

      if (saturationDelta > 18) {
        colorPixelCount++;
      } else {
        monochromePixelCount++;
      }

      // Check luminance for ink estimation
      final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
      if (lum < 200) {
        darkPixelCount++;
      }
    }

    final double colorPct = (colorPixelCount / totalPixels) * 100.0;
    final double monoPct = (monochromePixelCount / totalPixels) * 100.0;
    final double darkPct = (darkPixelCount / totalPixels) * 100.0;

    // Ink saving potential based on color and dark background distribution
    final double inkSaving = (colorPct * 0.45) + (darkPct * 0.25);
    final double clampedSaving = inkSaving.clamp(0.0, 65.0);

    String recommendation;
    if (colorPct < 5.0) {
      recommendation = 'Already primarily monochrome. Minor ink savings available.';
    } else if (colorPct > 40.0) {
      recommendation = 'High color content. Grayscale conversion can save significant toner/ink.';
    } else {
      recommendation = 'Moderate color elements. Recommended for print cost reduction.';
    }

    return ColorCoverageReport(
      colorPercentage: double.parse(colorPct.toStringAsFixed(1)),
      monochromePercentage: double.parse(monoPct.toStringAsFixed(1)),
      inkSavingPotential: double.parse(clampedSaving.toStringAsFixed(1)),
      recommendation: recommendation,
    );
  }

  /// Transforms an image based on the selected grayscale / ink saving algorithm
  static img.Image convertImageToGrayscale(
    img.Image src,
    GrayscaleAlgorithm algorithm, {
    double inkSaveFactor = 0.25,
  }) {
    final dest = img.Image(
      width: src.width,
      height: src.height,
      numChannels: src.numChannels,
    );

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        int outR = r;
        int outG = g;
        int outB = b;

        switch (algorithm) {
          case GrayscaleAlgorithm.luminance:
            // Standard ITU-R BT.601
            final lum = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
            outR = lum;
            outG = lum;
            outB = lum;
            break;

          case GrayscaleAlgorithm.desaturate:
            // Average of max and min
            final max = [r, g, b].reduce((c, n) => c > n ? c : n);
            final min = [r, g, b].reduce((c, n) => c < n ? c : n);
            final val = ((max + min) / 2).round().clamp(0, 255);
            outR = val;
            outG = val;
            outB = val;
            break;

          case GrayscaleAlgorithm.highContrastMono:
            final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
            final val = lum > 140 ? 255 : 0;
            outR = val;
            outG = val;
            outB = val;
            break;

          case GrayscaleAlgorithm.inkSaver:
            final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
            // Lighten non-black shades to reduce toner coverage
            int lightened;
            if (lum < 40) {
              // Keep text dark and crisp
              lightened = lum;
            } else {
              lightened = (lum + (255 - lum) * inkSaveFactor).round().clamp(0, 255);
            }
            outR = lightened;
            outG = lightened;
            outB = lightened;
            break;
        }

        dest.setPixelRgba(x, y, outR, outG, outB, a);
      }
    }

    return dest;
  }

  /// Formats output optimized file name
  static String formatColorOptimizedFileName(
    String inputPath,
    GrayscaleAlgorithm algorithm,
  ) {
    final dir = p.dirname(inputPath);
    final ext = p.extension(inputPath);
    final nameWithoutExt = p.basenameWithoutExtension(inputPath);
    final suffix = algorithm.name.toLowerCase();

    if (ext.isEmpty) {
      return p.join(dir, '${nameWithoutExt}_$suffix.pdf');
    }
    return p.join(dir, '${nameWithoutExt}_$suffix$ext');
  }
}
