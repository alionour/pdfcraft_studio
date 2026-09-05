import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_page_label_service.dart';

void main() {
  group('PdfPageLabelService - Converters & Helpers', () {
    test('toRoman converts integers to correct Roman numerals', () {
      expect(PdfPageLabelService.toRoman(1), 'I');
      expect(PdfPageLabelService.toRoman(4), 'IV');
      expect(PdfPageLabelService.toRoman(9), 'IX');
      expect(PdfPageLabelService.toRoman(14), 'XIV');
      expect(PdfPageLabelService.toRoman(40), 'XL');
      expect(PdfPageLabelService.toRoman(99), 'XCIX');
      expect(PdfPageLabelService.toRoman(2026), 'MMXXVI');

      expect(PdfPageLabelService.toRoman(1, lowercase: true), 'i');
      expect(PdfPageLabelService.toRoman(4, lowercase: true), 'iv');
      expect(PdfPageLabelService.toRoman(14, lowercase: true), 'xiv');
    });

    test('toAlpha converts integers to alphabetical sequences', () {
      expect(PdfPageLabelService.toAlpha(1), 'A');
      expect(PdfPageLabelService.toAlpha(2), 'B');
      expect(PdfPageLabelService.toAlpha(26), 'Z');
      expect(PdfPageLabelService.toAlpha(27), 'AA');
      expect(PdfPageLabelService.toAlpha(53), 'AAA');

      expect(PdfPageLabelService.toAlpha(1, lowercase: true), 'a');
      expect(PdfPageLabelService.toAlpha(26, lowercase: true), 'z');
      expect(PdfPageLabelService.toAlpha(27, lowercase: true), 'aa');
    });

    test('PageLabelRange formats labels across various numbering styles and prefixes', () {
      final arabicRange = const PageLabelRange(
        startPageIndex: 0,
        style: PageNumberingStyle.arabic,
        prefix: 'Page ',
        startNumber: 1,
      );
      expect(arabicRange.formatLabel(0), 'Page 1');
      expect(arabicRange.formatLabel(4), 'Page 5');

      final romanLowerRange = const PageLabelRange(
        startPageIndex: 0,
        style: PageNumberingStyle.romanLower,
        prefix: '',
        startNumber: 1,
      );
      expect(romanLowerRange.formatLabel(0), 'i');
      expect(romanLowerRange.formatLabel(3), 'iv');

      final appendixRange = const PageLabelRange(
        startPageIndex: 10,
        style: PageNumberingStyle.alphaUpper,
        prefix: 'App-',
        startNumber: 1,
      );
      expect(appendixRange.formatLabel(10), 'App-A');
      expect(appendixRange.formatLabel(11), 'App-B');

      final coverRange = const PageLabelRange(
        startPageIndex: 0,
        style: PageNumberingStyle.none,
        prefix: 'Cover',
      );
      expect(coverRange.formatLabel(0), 'Cover');
    });

    test('getLabelForPage evaluates the active range for multi-section documents', () {
      final ranges = [
        const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.romanLower, startNumber: 1), // 0..3: i..iv
        const PageLabelRange(startPageIndex: 4, style: PageNumberingStyle.arabic, startNumber: 1),     // 4..9: 1..6
        const PageLabelRange(startPageIndex: 10, style: PageNumberingStyle.alphaUpper, prefix: 'A-', startNumber: 1), // 10..: A-A, A-B
      ];

      expect(PdfPageLabelService.getLabelForPage(0, ranges), 'i');
      expect(PdfPageLabelService.getLabelForPage(3, ranges), 'iv');
      expect(PdfPageLabelService.getLabelForPage(4, ranges), '1');
      expect(PdfPageLabelService.getLabelForPage(9, ranges), '6');
      expect(PdfPageLabelService.getLabelForPage(10, ranges), 'A-A');
      expect(PdfPageLabelService.getLabelForPage(11, ranges), 'A-B');
    });
  });

  group('PdfPageLabelService - PDF Injection & Round-Trip', () {
    late Uint8List dummyPdfBytes;

    setUp(() {
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
endobj
xref
0 4
0000000000 65535 f 
0000000010 00000 n 
0000000060 00000 n 
0000000115 00000 n 
trailer
<< /Size 4 /Root 1 0 R >>
startxref
185
%%EOF
''';
      dummyPdfBytes = Uint8List.fromList(latin1.encode(pdfContent));
    });

    test('applyPageLabels builds PageLabels dictionary and parsePageLabels recovers it', () {
      final inputRanges = [
        const PageLabelRange(
          startPageIndex: 0,
          style: PageNumberingStyle.romanLower,
          prefix: '',
          startNumber: 1,
        ),
        const PageLabelRange(
          startPageIndex: 4,
          style: PageNumberingStyle.arabic,
          prefix: '',
          startNumber: 1,
        ),
        const PageLabelRange(
          startPageIndex: 15,
          style: PageNumberingStyle.alphaUpper,
          prefix: 'Appendix-',
          startNumber: 1,
        ),
      ];

      final updatedPdf = PdfPageLabelService.applyPageLabels(dummyPdfBytes, inputRanges);
      expect(updatedPdf.length, greaterThan(dummyPdfBytes.length));

      final parsedRanges = PdfPageLabelService.parsePageLabels(updatedPdf);
      expect(parsedRanges.length, 3);

      expect(parsedRanges[0].startPageIndex, 0);
      expect(parsedRanges[0].style, PageNumberingStyle.romanLower);

      expect(parsedRanges[1].startPageIndex, 4);
      expect(parsedRanges[1].style, PageNumberingStyle.arabic);

      expect(parsedRanges[2].startPageIndex, 15);
      expect(parsedRanges[2].style, PageNumberingStyle.alphaUpper);
      expect(parsedRanges[2].prefix, 'Appendix-');
    });

    test('resetPageLabels strips /PageLabels dictionary', () {
      final ranges = [
        const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.romanLower),
      ];
      final pdfWithLabels = PdfPageLabelService.applyPageLabels(dummyPdfBytes, ranges);
      expect(PdfPageLabelService.parsePageLabels(pdfWithLabels).length, 1);

      final resetPdf = PdfPageLabelService.resetPageLabels(pdfWithLabels);
      expect(PdfPageLabelService.parsePageLabels(resetPdf), isEmpty);
    });

    test('exportLabelsMappingCsv and exportLabelsMappingJson generate structured reports', () {
      final ranges = [
        const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.romanLower, startNumber: 1),
        const PageLabelRange(startPageIndex: 2, style: PageNumberingStyle.arabic, startNumber: 1),
      ];

      final csv = PdfPageLabelService.exportLabelsMappingCsv(4, ranges, documentName: 'thesis.pdf');
      expect(csv, contains('thesis.pdf'));
      expect(csv, contains('1,"i"'));
      expect(csv, contains('2,"ii"'));
      expect(csv, contains('3,"1"'));
      expect(csv, contains('4,"2"'));

      final json = PdfPageLabelService.exportLabelsMappingJson(4, ranges, documentName: 'thesis.pdf');
      expect(json, contains('"documentName": "thesis.pdf"'));
      expect(json, contains('"totalPages": 4'));
      expect(json, contains('"label": "i"'));
      expect(json, contains('"label": "1"'));
    });
  });
}
