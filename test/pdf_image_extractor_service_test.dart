import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_image_extractor_service.dart';

void main() {
  group('PdfImageExtractorService - formatImageName', () {
    test('formats PNG image names accurately', () {
      final name = PdfImageExtractorService.formatImageName(
        pdfName: 'report',
        pageNumber: 5,
        extension: 'png',
      );
      expect(name, 'report_extracted_page_005.png');
    });

    test('formats JPEG image names accurately', () {
      final name = PdfImageExtractorService.formatImageName(
        pdfName: 'document',
        pageNumber: 12,
        extension: '.jpeg',
      );
      expect(name, 'document_extracted_page_012.jpeg');
    });
  });
}
