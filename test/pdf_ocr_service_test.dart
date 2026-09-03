import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_ocr_service.dart';

void main() {
  group('PdfOcrService - searchTextInPages', () {
    test('finds matching keywords across page texts accurately', () {
      final ocrResult = OcrResult(
        pageTexts: [
          'This is page one with introductory content.',
          'Invoice number INV-99482 is attached for payment.',
          'Thank you for your business.',
        ],
        combinedText: 'Combined',
      );

      final searchResults = PdfOcrService.searchTextInPages(
        result: ocrResult,
        query: 'invoice',
      );

      expect(searchResults.length, 1);
      expect(searchResults.first.pageNumber, 2);
      expect(searchResults.first.matchCount, 1);
      expect(searchResults.first.snippet, contains('INV-99482'));
    });

    test('returns empty list for non-matching queries or empty string', () {
      final ocrResult = OcrResult(
        pageTexts: ['Hello world'],
        combinedText: 'Hello world',
      );

      expect(
        PdfOcrService.searchTextInPages(result: ocrResult, query: 'absent'),
        isEmpty,
      );
      expect(
        PdfOcrService.searchTextInPages(result: ocrResult, query: '  '),
        isEmpty,
      );
    });
  });
}
