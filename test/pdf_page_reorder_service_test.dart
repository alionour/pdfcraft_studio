import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_page_reorder_service.dart';

void main() {
  group('PdfPageReorderService - normalizeRotation', () {
    test('normalizes rotation angles accurately', () {
      expect(PdfPageReorderService.normalizeRotation(0), equals(0));
      expect(PdfPageReorderService.normalizeRotation(90), equals(90));
      expect(PdfPageReorderService.normalizeRotation(360), equals(0));
      expect(PdfPageReorderService.normalizeRotation(-90), equals(270));
    });
  });

  group('PdfPageReorderService - getActivePages', () {
    test('filters out deleted pages', () {
      final items = [
        const PageOrderItem(originalPageIndex: 1, isDeleted: false),
        const PageOrderItem(originalPageIndex: 2, isDeleted: true),
        const PageOrderItem(originalPageIndex: 3, isDeleted: false),
      ];

      final active = PdfPageReorderService.getActivePages(items);
      expect(active.length, equals(2));
      expect(active[0].originalPageIndex, equals(1));
      expect(active[1].originalPageIndex, equals(3));
    });
  });

  group('PdfPageReorderService - Shortcuts & Filters', () {
    test('reverses page order items accurately', () {
      final items = [
        const PageOrderItem(originalPageIndex: 1),
        const PageOrderItem(originalPageIndex: 2),
        const PageOrderItem(originalPageIndex: 3),
      ];

      final reversed = PdfPageReorderService.reversePageOrder(items);
      expect(reversed.first.originalPageIndex, equals(3));
      expect(reversed.last.originalPageIndex, equals(1));
    });

    test('filters odd and even pages correctly', () {
      final items = [
        const PageOrderItem(originalPageIndex: 1),
        const PageOrderItem(originalPageIndex: 2),
        const PageOrderItem(originalPageIndex: 3),
        const PageOrderItem(originalPageIndex: 4),
      ];

      final odds = PdfPageReorderService.filterOddPages(items);
      final evens = PdfPageReorderService.filterEvenPages(items);

      expect(odds.map((e) => e.originalPageIndex), equals([1, 3]));
      expect(evens.map((e) => e.originalPageIndex), equals([2, 4]));
    });
  });
}
