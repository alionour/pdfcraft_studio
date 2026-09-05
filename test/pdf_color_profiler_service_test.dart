import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/pdf_color_profiler_service.dart';

void main() {
  group('PdfColorProfilerService - analyzeColorCoverage', () {
    test('accurately identifies pure color image', () {
      final image = img.Image(width: 4, height: 4);
      for (final pixel in image) {
        pixel.setRgba(255, 0, 0, 255); // Pure red
      }

      final report = PdfColorProfilerService.analyzeColorCoverage(image);
      expect(report.colorPercentage, equals(100.0));
      expect(report.monochromePercentage, equals(0.0));
      expect(report.isPredominantlyMonochrome, isFalse);
      expect(report.inkSavingPotential, greaterThan(30.0));
      expect(report.recommendation, contains('High color content'));
    });

    test('accurately identifies pure monochrome grayscale image', () {
      final image = img.Image(width: 4, height: 4);
      for (int i = 0; i < 16; i++) {
        final val = (i * 15).clamp(0, 255);
        final pixel = image.getPixel(i % 4, i ~/ 4);
        pixel.setRgba(val, val, val, 255); // Pure neutral gray
      }

      final report = PdfColorProfilerService.analyzeColorCoverage(image);
      expect(report.colorPercentage, equals(0.0));
      expect(report.monochromePercentage, equals(100.0));
      expect(report.isPredominantlyMonochrome, isTrue);
      expect(report.recommendation, contains('Already primarily monochrome'));
    });

    test('handles empty image without crashing', () {
      final image = img.Image(width: 0, height: 0);
      final report = PdfColorProfilerService.analyzeColorCoverage(image);
      expect(report.colorPercentage, equals(0.0));
      expect(report.monochromePercentage, equals(100.0));
    });
  });

  group('PdfColorProfilerService - convertImageToGrayscale', () {
    test('applies ITU-R BT.601 luminance conversion correctly', () {
      final src = img.Image(width: 1, height: 1);
      src.setPixelRgba(0, 0, 255, 0, 0, 255); // Pure Red (255, 0, 0)

      final dest = PdfColorProfilerService.convertImageToGrayscale(
        src,
        GrayscaleAlgorithm.luminance,
      );

      final p = dest.getPixel(0, 0);
      // 0.299 * 255 = 76.245 -> 76
      expect(p.r.toInt(), equals(76));
      expect(p.g.toInt(), equals(76));
      expect(p.b.toInt(), equals(76));
      expect(p.a.toInt(), equals(255));
    });

    test('applies desaturate conversion correctly', () {
      final src = img.Image(width: 1, height: 1);
      src.setPixelRgba(0, 0, 255, 0, 0, 255); // Pure Red (255, 0, 0)

      final dest = PdfColorProfilerService.convertImageToGrayscale(
        src,
        GrayscaleAlgorithm.desaturate,
      );

      final p = dest.getPixel(0, 0);
      // (255 + 0) / 2 = 128
      expect(p.r.toInt(), equals(128));
      expect(p.g.toInt(), equals(128));
      expect(p.b.toInt(), equals(128));
    });

    test('applies highContrastMono thresholding correctly', () {
      final src = img.Image(width: 2, height: 1);
      src.setPixelRgba(0, 0, 200, 200, 200, 255); // Lum = 200 (> 140 -> White)
      src.setPixelRgba(1, 0, 50, 50, 50, 255); // Lum = 50 (< 140 -> Black)

      final dest = PdfColorProfilerService.convertImageToGrayscale(
        src,
        GrayscaleAlgorithm.highContrastMono,
      );

      final pWhite = dest.getPixel(0, 0);
      expect(pWhite.r.toInt(), equals(255));
      expect(pWhite.g.toInt(), equals(255));

      final pBlack = dest.getPixel(1, 0);
      expect(pBlack.r.toInt(), equals(0));
      expect(pBlack.g.toInt(), equals(0));
    });

    test('preserves deep black text in inkSaver mode while lightening backgrounds', () {
      final src = img.Image(width: 2, height: 1);
      src.setPixelRgba(0, 0, 20, 20, 20, 255); // Deep text black (< 40)
      src.setPixelRgba(1, 0, 100, 100, 100, 255); // Background gray (> 40)

      final dest = PdfColorProfilerService.convertImageToGrayscale(
        src,
        GrayscaleAlgorithm.inkSaver,
        inkSaveFactor: 0.5,
      );

      final pText = dest.getPixel(0, 0);
      // Text preserved at original luminance
      expect(pText.r.toInt(), equals(20));

      final pBg = dest.getPixel(1, 0);
      // Background lightened: 100 + (155 * 0.5) = ~178
      expect(pBg.r.toInt(), greaterThan(150));
    });
  });

  group('PdfColorProfilerService - formatColorOptimizedFileName', () {
    test('formats filename with algorithm suffix and extension', () {
      const input = r'C:\PrintJobs\presentation_deck.pdf';
      final output = PdfColorProfilerService.formatColorOptimizedFileName(
        input,
        GrayscaleAlgorithm.inkSaver,
      );
      expect(output, contains('presentation_deck_inksaver.pdf'));
    });

    test('formats filename for input without extension', () {
      const input = r'C:\Temp\draft_report';
      final output = PdfColorProfilerService.formatColorOptimizedFileName(
        input,
        GrayscaleAlgorithm.luminance,
      );
      expect(output, contains('draft_report_luminance.pdf'));
    });
  });
}
