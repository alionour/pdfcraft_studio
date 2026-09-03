import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_margin_crop_service.dart';

void main() {
  group('MarginCropConfig - mmToPoints', () {
    test('converts 25.4 mm to 72 points accurately', () {
      final pts = MarginCropConfig.mmToPoints(25.4);
      expect(pts, closeTo(72.0, 0.1));
    });

    test('calculates point offsets for margins correctly', () {
      const config = MarginCropConfig(
        topMm: 10.0,
        bottomMm: 10.0,
        leftMm: 20.0,
        rightMm: 20.0,
      );

      expect(config.topPt, closeTo(28.34, 0.1));
      expect(config.leftPt, closeTo(56.69, 0.1));
    });
  });
}
