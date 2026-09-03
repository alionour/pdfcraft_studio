import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_stamper_service.dart';

void main() {
  group('PdfStamperService - formatStampText', () {
    test('replaces variables {page}, {total}, and {pdf_name}', () {
      final formatted = PdfStamperService.formatStampText(
        template: 'Document: {pdf_name} | Page {page} of {total}',
        currentPage: 3,
        totalPages: 10,
        pdfName: 'AnnualReport',
      );

      expect(formatted, 'Document: AnnualReport | Page 3 of 10');
    });

    test('replaces date variable {date} accurately', () {
      final dt = DateTime(2026, 9, 1);
      final formatted = PdfStamperService.formatStampText(
        template: 'Date: {date} | Page {page}',
        currentPage: 1,
        totalPages: 1,
        pdfName: 'Doc',
        timestamp: dt,
      );

      expect(formatted, 'Date: 2026-09-01 | Page 1');
    });

    test('handles templates without variables', () {
      final formatted = PdfStamperService.formatStampText(
        template: 'CONFIDENTIAL',
        currentPage: 1,
        totalPages: 5,
        pdfName: 'Invoice',
      );

      expect(formatted, 'CONFIDENTIAL');
    });
  });

  group('StampOptions - fromPreset', () {
    test('resolves preset options for page number footer', () {
      final options = StampOptions.fromPreset(StampPreset.pageNumberFooter);
      expect(options.text, 'Page {page} of {total}');
      expect(options.position, StampPosition.footerRight);
    });

    test('resolves preset options for confidential header/footer', () {
      final options = StampOptions.fromPreset(StampPreset.confidentialFooter);
      expect(options.text, 'CONFIDENTIAL - {pdf_name}');
      expect(options.position, StampPosition.footerLeft);
    });
  });

  group('PdfStamperService - parsePageRange', () {
    test('returns all pages for "all" or empty string', () {
      expect(PdfStamperService.parsePageRange('all', 4), [1, 2, 3, 4]);
      expect(PdfStamperService.parsePageRange('', 4), [1, 2, 3, 4]);
    });

    test('parses single pages and ranges correctly', () {
      expect(PdfStamperService.parsePageRange('1', 5), [1]);
      expect(PdfStamperService.parsePageRange('2-4', 5), [2, 3, 4]);
      expect(PdfStamperService.parsePageRange('1, 3, 5', 5), [1, 3, 5]);
    });

    test('filters out invalid or out-of-range numbers', () {
      expect(PdfStamperService.parsePageRange('0, 2-10', 3), [2, 3]);
    });
  });
}
