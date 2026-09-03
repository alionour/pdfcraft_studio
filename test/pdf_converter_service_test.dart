import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_converter_service.dart';

void main() {
  group('PdfConverterService - parsePageRange', () {
    test('returns all pages when range is "all" or empty', () {
      expect(PdfConverterService.parsePageRange('all', 5), [0, 1, 2, 3, 4]);
      expect(PdfConverterService.parsePageRange('', 5), [0, 1, 2, 3, 4]);
      expect(PdfConverterService.parsePageRange('   ', 3), [0, 1, 2]);
    });

    test('parses single page numbers correctly', () {
      expect(PdfConverterService.parsePageRange('1', 5), [0]);
      expect(PdfConverterService.parsePageRange('3', 5), [2]);
      expect(PdfConverterService.parsePageRange('1, 3, 5', 5), [0, 2, 4]);
    });

    test('parses page ranges correctly', () {
      expect(PdfConverterService.parsePageRange('1-3', 5), [0, 1, 2]);
      expect(PdfConverterService.parsePageRange('2-4', 5), [1, 2, 3]);
      expect(PdfConverterService.parsePageRange('1-2, 4-5', 5), [0, 1, 3, 4]);
    });

    test('handles out of bounds page numbers gracefully', () {
      expect(PdfConverterService.parsePageRange('0, 10', 5), [0, 1, 2, 3, 4]);
      expect(PdfConverterService.parsePageRange('1-10', 3), [0, 1, 2]);
    });
  });

  group('PdfConverterService - formatFileName', () {
    test('formats default pattern correctly', () {
      final name = PdfConverterService.formatFileName(
        pattern: '{pdf_name}_page_{page}',
        pdfName: 'sample',
        pageNumber: 2,
        totalPages: 10,
        dpi: 300,
        format: 'png',
      );
      expect(name, 'sample_page_2.png');
    });

    test('formats custom pattern with padded pages and dpi', () {
      final name = PdfConverterService.formatFileName(
        pattern: '{pdf_name}_DPI{dpi}_P{page_padded}_of_{total_pages}',
        pdfName: 'invoice',
        pageNumber: 3,
        totalPages: 100,
        dpi: 150,
        format: 'jpeg',
      );
      expect(name, 'invoice_DPI150_P003_of_100.jpeg');
    });

    test('appends extension if missing in pattern', () {
      final name = PdfConverterService.formatFileName(
        pattern: 'custom_{pdf_name}_{page}',
        pdfName: 'report',
        pageNumber: 1,
        totalPages: 1,
        dpi: 72,
        format: 'png',
      );
      expect(name, 'custom_report_1.png');
    });
  });
}
