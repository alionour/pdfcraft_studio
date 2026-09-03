import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_bookmark_service.dart';

void main() {
  group('PdfBookmarkService - sanitizeBookmarks', () {
    test('filters out out-of-range pages and sorts chronologically', () {
      final list = [
        const PdfBookmarkNode(title: 'Chapter 3', pageNumber: 8),
        const PdfBookmarkNode(title: 'Intro', pageNumber: 1),
        const PdfBookmarkNode(title: 'Invalid High', pageNumber: 99),
        const PdfBookmarkNode(title: 'Invalid Low', pageNumber: 0),
        const PdfBookmarkNode(title: '', pageNumber: 4), // Empty title
      ];

      final clean = PdfBookmarkService.sanitizeBookmarks(list, 10);

      expect(clean.length, 2);
      expect(clean[0].title, 'Intro');
      expect(clean[0].pageNumber, 1);
      expect(clean[1].title, 'Chapter 3');
      expect(clean[1].pageNumber, 8);
    });

    test('PdfBookmarkNode copyWith works as expected', () {
      const original = PdfBookmarkNode(title: 'Section A', pageNumber: 2);
      final updated = original.copyWith(title: 'Section A Updated');

      expect(updated.title, 'Section A Updated');
      expect(updated.pageNumber, 2);
    });
  });
}
