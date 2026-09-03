import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_table_extractor_service.dart';

void main() {
  group('PdfTableExtractorService - formatExtractedTableFileName', () {
    test('formats CSV filename correctly for input path with extension', () {
      final name = PdfTableExtractorService.formatExtractedTableFileName('/path/to/invoice.pdf', 'csv');
      expect(name, equals('invoice_extracted_tables.csv'));
    });

    test('formats JSON filename correctly for input path without extension', () {
      final name = PdfTableExtractorService.formatExtractedTableFileName('/path/to/invoice', 'json');
      expect(name, equals('invoice_extracted_tables.json'));
    });
  });

  group('PdfTableExtractorService - exportToCsv', () {
    test('formats rows into valid CSV string', () {
      final rows = [
        ['ID', 'Name', 'Amount'],
        ['1', 'Product A', '10.50'],
        ['2', 'Product B', '20.00'],
      ];
      final csv = PdfTableExtractorService.exportToCsv(rows);
      expect(csv, contains('ID,Name,Amount'));
      expect(csv, contains('1,Product A,10.50'));
    });
  });

  group('PdfTableExtractorService - exportToJson', () {
    test('formats rows into valid JSON string', () {
      final rows = [
        ['ID', 'Name'],
        ['101', 'Item X'],
      ];
      final jsonStr = PdfTableExtractorService.exportToJson(rows);
      expect(jsonStr, contains('"ID": "101"'));
      expect(jsonStr, contains('"Name": "Item X"'));
    });
  });
}
