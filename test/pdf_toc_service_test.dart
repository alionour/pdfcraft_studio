import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_toc_service.dart';

void main() {
  group('PdfTocService - generateTocTextReport', () {
    test('formats Table of Contents text report accurately', () {
      const entries = [
        TocEntry(title: 'Introduction', pageNumber: 1, level: 1),
        TocEntry(title: 'Overview', pageNumber: 2, level: 2),
        TocEntry(title: 'Conclusion', pageNumber: 10, level: 1),
      ];

      final report = PdfTocService.generateTocTextReport(
        pdfName: 'SampleDoc',
        entries: entries,
      );

      expect(report, contains('Table of Contents: SampleDoc'));
      expect(report, contains('Introduction'));
      expect(report, contains('Page 1'));
      expect(report, contains('Page 10'));
    });

    test('handles empty entries gracefully', () {
      final report = PdfTocService.generateTocTextReport(
        pdfName: 'EmptyDoc',
        entries: [],
      );

      expect(report, contains('No table of contents entries found.'));
    });
  });

  group('PdfTocService - analyzeTocStats', () {
    test('calculates correct TOC stats for entry list', () {
      const entries = [
        TocEntry(title: 'Chapter 1', pageNumber: 1, level: 1),
        TocEntry(title: 'Section 1.1', pageNumber: 3, level: 2),
        TocEntry(title: 'Subsection 1.1.1', pageNumber: 4, level: 3),
      ];

      final stats = PdfTocService.analyzeTocStats(entries);
      expect(stats['totalEntries'], 3);
      expect(stats['maxLevel'], 3);
      expect(stats['firstPage'], 1);
      expect(stats['lastPage'], 4);
    });

    test('handles empty entry list stats', () {
      final stats = PdfTocService.analyzeTocStats([]);
      expect(stats['totalEntries'], 0);
      expect(stats['maxLevel'], 0);
    });
  });
}
