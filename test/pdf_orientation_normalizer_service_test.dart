import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_orientation_normalizer_service.dart';

void main() {
  group('PdfOrientationNormalizerService - formatNormalizedFileName', () {
    test('formats normalized filename correctly for files with extension', () {
      final name = PdfOrientationNormalizerService.formatNormalizedFileName('/path/to/scan.pdf');
      expect(name, equals('scan_normalized.pdf'));
    });

    test('formats normalized filename correctly for files without extension', () {
      final name = PdfOrientationNormalizerService.formatNormalizedFileName('/path/to/scan');
      expect(name, equals('scan_normalized.pdf'));
    });
  });

  group('PdfOrientationNormalizerService - resolvePageFormat', () {
    test('resolves A4 portrait format correctly', () {
      final format = PdfOrientationNormalizerService.resolvePageFormat(TargetPageSize.a4, TargetOrientation.portrait);
      expect(format.width, lessThan(format.height));
    });

    test('resolves A4 landscape format correctly', () {
      final format = PdfOrientationNormalizerService.resolvePageFormat(TargetPageSize.a4, TargetOrientation.landscape);
      expect(format.width, greaterThan(format.height));
    });

    test('isLandscapeAspect detects page aspect ratio correctly', () {
      expect(PdfOrientationNormalizerService.isLandscapeAspect(width: 800, height: 600), isTrue);
      expect(PdfOrientationNormalizerService.isLandscapeAspect(width: 600, height: 800), isFalse);
    });
  });
}
