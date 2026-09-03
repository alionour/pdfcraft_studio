import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_layout_service.dart';

void main() {
  group('PdfLayoutService - calculateSheetCount', () {
    test('calculates 2-Up sheet counts correctly', () {
      expect(PdfLayoutService.calculateSheetCount(1, NUpMode.twoUp), 1);
      expect(PdfLayoutService.calculateSheetCount(2, NUpMode.twoUp), 1);
      expect(PdfLayoutService.calculateSheetCount(3, NUpMode.twoUp), 2);
      expect(PdfLayoutService.calculateSheetCount(10, NUpMode.twoUp), 5);
    });

    test('calculates 4-Up sheet counts correctly', () {
      expect(PdfLayoutService.calculateSheetCount(1, NUpMode.fourUp), 1);
      expect(PdfLayoutService.calculateSheetCount(4, NUpMode.fourUp), 1);
      expect(PdfLayoutService.calculateSheetCount(5, NUpMode.fourUp), 2);
      expect(PdfLayoutService.calculateSheetCount(12, NUpMode.fourUp), 3);
    });
  });
}
