import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_font_inspector_service.dart';

void main() {
  group('PdfFontInspectorService - Clean & Subset Detection', () {
    test('cleanBaseFont removes leading slashes and subset prefixes', () {
      expect(PdfFontInspectorService.cleanBaseFont('BCDFEE+Arial-BoldMT'), 'Arial-BoldMT');
      expect(PdfFontInspectorService.cleanBaseFont('/BCDFEE+TimesNewRoman'), 'TimesNewRoman');
      expect(PdfFontInspectorService.cleanBaseFont('/Helvetica'), 'Helvetica');
      expect(PdfFontInspectorService.cleanBaseFont('Courier'), 'Courier');
    });

    test('checkIsSubset correctly identifies PDF subset naming patterns', () {
      expect(PdfFontInspectorService.checkIsSubset('BCDFEE+Arial'), isTrue);
      expect(PdfFontInspectorService.checkIsSubset('/ZXYWVU+Roboto-Regular'), isTrue);
      expect(PdfFontInspectorService.checkIsSubset('Arial'), isFalse);
      expect(PdfFontInspectorService.checkIsSubset('TimesNewRomanPSMT'), isFalse);
      expect(PdfFontInspectorService.checkIsSubset('123456+Font'), isFalse);
    });
  });

  group('PdfFontInspectorService - PDF Stream Inspection', () {
    late Uint8List mockPdfWithFonts;

    setUp(() {
      // PDF containing embedded subset font, standard font without embedding, and composite font with ToUnicode
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 10 0 R /F2 20 0 R /F3 30 0 R >> >> >>
endobj

% Font 1: Embedded Subset TrueType
10 0 obj
<<
  /Type /Font
  /Subtype /TrueType
  /BaseFont /BCDFEE+Inter-Regular
  /Encoding /WinAnsiEncoding
  /FontDescriptor 11 0 R
  /ToUnicode 13 0 R
>>
endobj
11 0 obj
<<
  /Type /FontDescriptor
  /FontName /BCDFEE+Inter-Regular
  /FontFile2 12 0 R
>>
endobj
12 0 obj
<< /Length 100 >>
stream
rawfontdatabytes
endstream
endobj
13 0 obj
<< /Length 50 >>
stream
tounicodemapbytes
endstream
endobj

% Font 2: Un-embedded ArialMT (Critical Preflight Issue)
20 0 obj
<<
  /Type /Font
  /Subtype /TrueType
  /BaseFont /ArialMT
  /Encoding /WinAnsiEncoding
>>
endobj

% Font 3: Type0 CIDFont with ToUnicode
30 0 obj
<<
  /Type /Font
  /Subtype /Type0
  /BaseFont /NotoSansSC-Regular
  /Encoding /Identity-H
  /ToUnicode 31 0 R
  /FontDescriptor 32 0 R
>>
endobj
31 0 obj
<< /Length 40 >>
stream
tounicodemap
endstream
endobj
32 0 obj
<<
  /Type /FontDescriptor
  /FontFile3 33 0 R
>>
endobj
33 0 obj
<< /Length 60 >>
stream
cffbytes
endstream
endobj

xref
0 34
trailer
<< /Size 34 /Root 1 0 R >>
startxref
500
%%EOF
''';
      mockPdfWithFonts = Uint8List.fromList(latin1.encode(pdfContent));
    });

    test('inspectFonts discovers all fonts, embedding status, and preflight issues', () {
      final report = PdfFontInspectorService.inspectFonts(mockPdfWithFonts);

      expect(report.totalFonts, 3);
      expect(report.embeddedCount, 2);
      expect(report.missingCount, 1);
      expect(report.subsetCount, 1);
      expect(report.toUnicodeCompliantCount, 2);

      // Verify font 1 (Inter subset)
      final inter = report.fonts.firstWhere((f) => f.baseFont == 'Inter-Regular');
      expect(inter.isEmbedded, isTrue);
      expect(inter.isSubset, isTrue);
      expect(inter.hasToUnicode, isTrue);
      expect(inter.encoding, 'WinAnsiEncoding');

      // Verify font 2 (ArialMT missing)
      final arial = report.fonts.firstWhere((f) => f.baseFont == 'ArialMT');
      expect(arial.isEmbedded, isFalse);
      expect(arial.isSubset, isFalse);

      // Verify font 3 (NotoSansSC)
      final noto = report.fonts.firstWhere((f) => f.baseFont == 'NotoSansSC-Regular');
      expect(noto.isEmbedded, isTrue);
      expect(noto.subtype, 'Type0');
      expect(noto.encoding, 'Identity-H');

      // Verify preflight issues & score
      expect(report.issues.any((i) => i.contains("ArialMT")), isTrue);
      expect(report.complianceScore, greaterThan(60.0));
      expect(report.complianceScore, lessThan(100.0));
    });

    test('exportCsvReport and exportJsonReport generate structured diagnostic reports', () {
      final report = PdfFontInspectorService.inspectFonts(mockPdfWithFonts);

      final csv = PdfFontInspectorService.exportCsvReport(report, documentName: 'spec.pdf');
      expect(csv, contains('spec.pdf'));
      expect(csv, contains('Inter-Regular'));
      expect(csv, contains('ArialMT'));
      expect(csv, contains('NotoSansSC-Regular'));
      expect(csv, contains('# [!] Critical: Font \'ArialMT\' is NOT embedded'));

      final json = PdfFontInspectorService.exportJsonReport(report, documentName: 'spec.pdf');
      expect(json, contains('"documentName": "spec.pdf"'));
      expect(json, contains('"totalFonts": 3'));
      expect(json, contains('"embeddedCount": 2'));
    });
  });
}
