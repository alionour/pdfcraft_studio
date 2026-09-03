import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_watermark_background_service.dart';

void main() {
  group('PdfWatermarkBackgroundService - formatWatermarkedFileName', () {
    test('formats watermarked filename correctly for files with extension', () {
      final name = PdfWatermarkBackgroundService.formatWatermarkedFileName('/path/to/contract.pdf');
      expect(name, equals('contract_watermarked.pdf'));
    });

    test('formats watermarked filename correctly for files without extension', () {
      final name = PdfWatermarkBackgroundService.formatWatermarkedFileName('/path/to/contract');
      expect(name, equals('contract_watermarked.pdf'));
    });
  });

  group('WatermarkConfig model', () {
    test('instantiates with default values', () {
      const config = WatermarkConfig();
      expect(config.text, equals('CONFIDENTIAL'));
      expect(config.opacity, equals(0.3));
      expect(config.fontSize, equals(48.0));
      expect(config.angleDegrees, equals(45.0));
    });

    test('resolves background color presets accurately', () {
      final sepia = WatermarkConfig.getBackgroundColor(BackgroundTintPreset.sepiaWarm);
      final green = WatermarkConfig.getBackgroundColor(BackgroundTintPreset.eyeCareGreen);
      final dark = WatermarkConfig.getBackgroundColor(BackgroundTintPreset.darkMode);

      expect(sepia.value, equals(const Color(0x1DFBF0D9).value));
      expect(green.value, equals(const Color(0x1DC7EDCC).value));
      expect(dark.value, equals(const Color(0x1D121212).value));
    });

    test('copyWith updates fields correctly', () {
      const config = WatermarkConfig();
      final updated = config.copyWith(
        text: 'DRAFT',
        opacity: 0.5,
        backgroundColor: Colors.yellow,
      );

      expect(updated.text, equals('DRAFT'));
      expect(updated.opacity, equals(0.5));
      expect(updated.backgroundColor, equals(Colors.yellow));
      expect(updated.fontSize, equals(48.0));
    });
  });
}
