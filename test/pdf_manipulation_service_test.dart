import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_manipulation_service.dart';

void main() {
  group('PdfManipulationService - normalizeRotationAngle', () {
    test('normalizes standard positive angles correctly', () {
      expect(PdfManipulationService.normalizeRotationAngle(0), 0);
      expect(PdfManipulationService.normalizeRotationAngle(90), 90);
      expect(PdfManipulationService.normalizeRotationAngle(180), 180);
      expect(PdfManipulationService.normalizeRotationAngle(270), 270);
      expect(PdfManipulationService.normalizeRotationAngle(360), 0);
    });

    test('normalizes negative angles correctly', () {
      expect(PdfManipulationService.normalizeRotationAngle(-90), 270);
      expect(PdfManipulationService.normalizeRotationAngle(-180), 180);
      expect(PdfManipulationService.normalizeRotationAngle(-270), 90);
    });

    test('normalizes arbitrary angles to nearest 90-degree step', () {
      expect(PdfManipulationService.normalizeRotationAngle(30), 0);
      expect(PdfManipulationService.normalizeRotationAngle(85), 90);
      expect(PdfManipulationService.normalizeRotationAngle(200), 180);
    });
  });

  group('PdfManipulationService - rotatePage helper methods', () {
    test('rotates page item clockwise through 360 degrees', () {
      final item = PageItemInfo(originalIndex: 0, pdfPath: 'test.pdf', rotationAngle: 0);

      PdfManipulationService.rotatePageClockwise(item);
      expect(item.rotationAngle, 90);

      PdfManipulationService.rotatePageClockwise(item);
      expect(item.rotationAngle, 180);

      PdfManipulationService.rotatePageClockwise(item);
      expect(item.rotationAngle, 270);

      PdfManipulationService.rotatePageClockwise(item);
      expect(item.rotationAngle, 0);
    });

    test('rotates page item counter-clockwise through 360 degrees', () {
      final item = PageItemInfo(originalIndex: 0, pdfPath: 'test.pdf', rotationAngle: 0);

      PdfManipulationService.rotatePageCounterClockwise(item);
      expect(item.rotationAngle, 270);

      PdfManipulationService.rotatePageCounterClockwise(item);
      expect(item.rotationAngle, 180);

      PdfManipulationService.rotatePageCounterClockwise(item);
      expect(item.rotationAngle, 90);

      PdfManipulationService.rotatePageCounterClockwise(item);
      expect(item.rotationAngle, 0);
    });
  });
}
