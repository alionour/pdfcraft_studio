import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_compare_service.dart';

void main() {
  group('PageCompareSummary model', () {
    test('instantiates and verifies page count matching flag', () {
      const summary = PageCompareSummary(
        docAPageCount: 5,
        docBPageCount: 5,
        isPageCountMatching: true,
        mismatchedPages: [],
      );

      expect(summary.docAPageCount, 5);
      expect(summary.docBPageCount, 5);
      expect(summary.isPageCountMatching, true);
      expect(summary.mismatchedPages, isEmpty);
    });

    test('detects page count mismatch in summary model', () {
      const summary = PageCompareSummary(
        docAPageCount: 4,
        docBPageCount: 6,
        isPageCountMatching: false,
        mismatchedPages: [5, 6],
      );

      expect(summary.isPageCountMatching, false);
      expect(summary.mismatchedPages, containsAll([5, 6]));
    });
  });
}
