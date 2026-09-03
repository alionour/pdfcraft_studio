import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_metadata_service.dart';

void main() {
  group('PdfMetadataService - formatBytes', () {
    test('formats bytes under 1 KB', () {
      expect(PdfMetadataService.formatBytes(512), '512 B');
    });

    test('formats bytes in kilobytes', () {
      expect(PdfMetadataService.formatBytes(2048), '2.0 KB');
      expect(PdfMetadataService.formatBytes(15360), '15.0 KB');
    });

    test('formats bytes in megabytes', () {
      expect(PdfMetadataService.formatBytes(1048576), '1.00 MB');
      expect(PdfMetadataService.formatBytes(5242880), '5.00 MB');
    });
  });

  group('PdfMetadataInfo model', () {
    test('copyWith replaces specified values while maintaining others', () {
      const info = PdfMetadataInfo(
        title: 'Original Title',
        author: 'Original Author',
        totalPages: 10,
        pageSizeInfo: 'A4',
        filePath: '/test/sample.pdf',
        fileSizeBytes: 1024,
      );

      final updated = info.copyWith(title: 'New Title', author: 'New Author');

      expect(updated.title, 'New Title');
      expect(updated.author, 'New Author');
      expect(updated.totalPages, 10);
      expect(updated.filePath, '/test/sample.pdf');
    });
  });
}
