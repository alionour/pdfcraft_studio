import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_splitter_service.dart';

void main() {
  group('PdfSplitterService - formatSplitFileName', () {
    test('formats split filenames with chunk index and suffix', () {
      final name = PdfSplitterService.formatSplitFileName(
        inputPdfPath: 'C:\\docs\\report.pdf',
        chunkIndex: 2,
        suffix: 'p2',
      );
      expect(name, 'report_part2_p2.pdf');
    });
  });

  group('PdfSplitterService - calculateChunkCount', () {
    test('calculates single page chunk count accurately', () {
      final count = PdfSplitterService.calculateChunkCount(
        totalPages: 5,
        mode: SplitMode.singlePages,
      );
      expect(count, 5);
    });

    test('calculates chunk count for 2 pages per chunk', () {
      final count = PdfSplitterService.calculateChunkCount(
        totalPages: 5,
        mode: SplitMode.chunkEveryN,
        pagesPerChunk: 2,
      );
      expect(count, 3);
    });
  });
}
