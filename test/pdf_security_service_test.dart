import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter_app/services/pdf_security_service.dart';

void main() {
  group('WatermarkOptions', () {
    test('has correct default values', () {
      final options = WatermarkOptions();
      expect(options.isText, isTrue);
      expect(options.text, 'CONFIDENTIAL');
      expect(options.fontSize, 48);
      expect(options.opacity, 0.3);
      expect(options.rotationAngleDegree, 45);
    });

    test('creates image watermark options via createImageWatermark factory', () {
      final options = WatermarkOptions.createImageWatermark(
        imagePath: 'C:\\images\\logo.png',
        opacity: 0.5,
      );

      expect(options.isText, isFalse);
      expect(options.imagePath, 'C:\\images\\logo.png');
      expect(options.opacity, 0.5);
      expect(options.rotationAngleDegree, 0);
    });

    test('converts degrees to radians accurately', () {
      final rad0 = WatermarkOptions.degreesToRadians(0);
      final rad180 = WatermarkOptions.degreesToRadians(180);
      final rad90 = WatermarkOptions.degreesToRadians(90);

      expect(rad0, 0.0);
      expect(rad180, closeTo(3.14159, 0.001));
      expect(rad90, closeTo(1.57079, 0.001));
    });

    test('copyWith updates specified fields correctly', () {
      final initial = WatermarkOptions();
      final updated = initial.copyWith(
        text: 'DRAFT',
        fontSize: 32,
        opacity: 0.5,
        color: PdfColors.red,
      );

      expect(updated.text, 'DRAFT');
      expect(updated.fontSize, 32);
      expect(updated.opacity, 0.5);
      expect(updated.color, PdfColors.red);
      expect(updated.rotationAngleDegree, initial.rotationAngleDegree);
    });

    test('textPresets contains standard document watermarks', () {
      expect(WatermarkOptions.textPresets, contains('CONFIDENTIAL'));
      expect(WatermarkOptions.textPresets, contains('DRAFT'));
      expect(WatermarkOptions.textPresets, contains('APPROVED'));
    });
  });
}
