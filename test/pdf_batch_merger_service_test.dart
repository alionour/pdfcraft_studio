import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_batch_merger_service.dart';

void main() {
  group('PdfBatchMergerService - formatMergedFileName', () {
    test('formats merged filename correctly for files with extension', () {
      final name = PdfBatchMergerService.formatMergedFileName('/path/to/report.pdf');
      expect(name, equals('report_merged.pdf'));
    });

    test('formats merged filename correctly for files without extension', () {
      final name = PdfBatchMergerService.formatMergedFileName('/path/to/report');
      expect(name, equals('report_merged.pdf'));
    });
  });

  group('PdfBatchMergerService - calculateTotalPages', () {
    test('returns 0 for empty list of pdf paths', () async {
      final total = await PdfBatchMergerService.calculateTotalPages([]);
      expect(total, equals(0));
    });
  });
}
