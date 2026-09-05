import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_repair_diagnostic_service.dart';

void main() {
  group('PdfRepairDiagnosticService - diagnosePdfBytes', () {
    test('diagnoses healthy PDF with 100% score', () {
      const validPdfText = '''%PDF-1.7
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [] /Count 0 >>
endobj
xref
0 3
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
trailer
<< /Size 3 /Root 1 0 R >>
startxref
115
%%EOF''';

      final bytes = Uint8List.fromList(latin1.encode(validPdfText));
      final report = PdfRepairDiagnosticService.diagnosePdfBytes(bytes);

      expect(report.healthScore, equals(100));
      expect(report.hasValidHeader, isTrue);
      expect(report.hasValidEof, isTrue);
      expect(report.hasValidTrailer, isTrue);
      expect(report.isClean, isTrue);
      expect(report.objectCount, equals(2));
      expect(report.pdfVersion, equals('1.7'));
    });

    test('detects empty file as critical', () {
      final report = PdfRepairDiagnosticService.diagnosePdfBytes(Uint8List(0));
      expect(report.healthScore, equals(0));
      expect(report.hasValidHeader, isFalse);
      expect(report.issues.any((i) => i.code == 'EMPTY_FILE'), isTrue);
      expect(report.isRepairable, isFalse);
    });

    test('detects leading garbage bytes before %PDF- header', () {
      const damagedText = 'BOM_GARBAGE_BYTES%PDF-1.5\n1 0 obj\n<< /Root 1 0 R >>\nendobj\ntrailer\n<<>>\n%%EOF';
      final bytes = Uint8List.fromList(latin1.encode(damagedText));
      final report = PdfRepairDiagnosticService.diagnosePdfBytes(bytes);

      expect(report.issues.any((i) => i.code == 'CORRUPTED_HEADER_OFFSET'), isTrue);
      expect(report.hasValidHeader, isTrue);
      expect(report.healthScore, lessThan(100));
    });

    test('detects missing %%EOF marker', () {
      const truncatedPdf = '%PDF-1.4\n1 0 obj\n<< /Root 1 0 R >>\nendobj\ntrailer\n<<>>';
      final bytes = Uint8List.fromList(latin1.encode(truncatedPdf));
      final report = PdfRepairDiagnosticService.diagnosePdfBytes(bytes);

      expect(report.hasValidEof, isFalse);
      expect(report.issues.any((i) => i.code == 'MISSING_EOF'), isTrue);
    });

    test('detects unbalanced object tags', () {
      const unbalancedPdf = '%PDF-1.4\n1 0 obj\n2 0 obj\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF';
      final bytes = Uint8List.fromList(latin1.encode(unbalancedPdf));
      final report = PdfRepairDiagnosticService.diagnosePdfBytes(bytes);

      expect(report.issues.any((i) => i.code == 'UNBALANCED_OBJECTS'), isTrue);
    });
  });

  group('PdfRepairDiagnosticService - repairPdfBytes', () {
    test('strips leading garbage bytes before %PDF-', () {
      const dirty = 'HTTP/1.1 200 OK\r\n\r\n%PDF-1.4\n1 0 obj\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF';
      final dirtyBytes = Uint8List.fromList(latin1.encode(dirty));

      final repairedBytes = PdfRepairDiagnosticService.repairPdfBytes(dirtyBytes);
      final repairedText = latin1.decode(repairedBytes);

      expect(repairedText.startsWith('%PDF-1.4'), isTrue);
      expect(repairedText.endsWith('%%EOF\n') || repairedText.endsWith('%%EOF'), isTrue);
    });

    test('appends %%EOF if missing', () {
      const noEof = '%PDF-1.4\n1 0 obj\nendobj\ntrailer\n<< /Root 1 0 R >>';
      final bytes = Uint8List.fromList(latin1.encode(noEof));

      final repairedBytes = PdfRepairDiagnosticService.repairPdfBytes(bytes);
      final repairedText = latin1.decode(repairedBytes);

      expect(repairedText.contains('%%EOF'), isTrue);
    });
  });

  group('PdfRepairDiagnosticService - formatRepairedFileName', () {
    test('formats filename with _repaired suffix and extension', () {
      const input = r'C:\Downloads\invoice_damaged.pdf';
      final output = PdfRepairDiagnosticService.formatRepairedFileName(input);
      expect(output, contains('invoice_damaged_repaired.pdf'));
    });

    test('formats filename for path without extension', () {
      const input = r'C:\Temp\recovered_chunk';
      final output = PdfRepairDiagnosticService.formatRepairedFileName(input);
      expect(output, contains('recovered_chunk_repaired.pdf'));
    });
  });
}
