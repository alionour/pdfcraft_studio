import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/pdf_accessibility_service.dart';

void main() {
  group('PdfAccessibilityService - applyAccessibilityPreset', () {
    test('applies soft amber preset transformation correctly', () {
      final sample = img.Image(width: 5, height: 5);
      sample.setPixelRgb(0, 0, 200, 200, 200);

      final processed = PdfAccessibilityService.applyAccessibilityPreset(sample, AccessibilityPreset.softAmber);

      expect(processed.width, 5);
      expect(processed.height, 5);
    });

    test('applies high contrast mono preset', () {
      final sample = img.Image(width: 5, height: 5);
      sample.setPixelRgb(0, 0, 100, 150, 200);

      final processed = PdfAccessibilityService.applyAccessibilityPreset(sample, AccessibilityPreset.highContrastMono);

      expect(processed.width, 5);
      expect(processed.height, 5);
    });

    test('applies legibility boost preset', () {
      final sample = img.Image(width: 5, height: 5);
      sample.setPixelRgb(0, 0, 120, 120, 120);

      final processed = PdfAccessibilityService.applyAccessibilityPreset(sample, AccessibilityPreset.legibilityBoost);

      expect(processed.width, 5);
      expect(processed.height, 5);
    });
  });
}
