import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_header_footer_service.dart';

void main() {
  group('PdfHeaderFooterService - formatHeaderFooterFileName', () {
    test('formats header/footer filename correctly for files with extension', () {
      final name = PdfHeaderFooterService.formatHeaderFooterFileName('/path/to/doc.pdf');
      expect(name, equals('doc_headers.pdf'));
    });

    test('formats header/footer filename correctly for files without extension', () {
      final name = PdfHeaderFooterService.formatHeaderFooterFileName('/path/to/doc');
      expect(name, equals('doc_headers.pdf'));
    });
  });

  group('PdfHeaderFooterService - formatText template variable replacement', () {
    test('replaces {page}, {total}, and {pdf_name} accurately', () {
      final formatted = PdfHeaderFooterService.formatText(
        template: 'Doc: {pdf_name} | Page {page} of {total}',
        currentPage: 3,
        totalPages: 10,
        pdfName: 'report_2026',
      );
      expect(formatted, equals('Doc: report_2026 | Page 3 of 10'));
    });
  });

  group('HeaderFooterConfig model', () {
    test('copyWith updates properties accurately', () {
      const config = HeaderFooterConfig();
      final updated = config.copyWith(headerText: 'Confidential Header', alignment: HeaderFooterAlignment.left);
      expect(updated.headerText, equals('Confidential Header'));
      expect(updated.alignment, equals(HeaderFooterAlignment.left));
      expect(updated.footerText, equals('Page {page} of {total}'));
    });
  });
}
