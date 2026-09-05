import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_bates_numbering_service.dart';

void main() {
  group('PdfBatesNumberingService - formatBatesNumber', () {
    test('formats default Bates string with 6-digit padding and EXHIBIT- prefix', () {
      const config = BatesConfig();
      final result = PdfBatesNumberingService.formatBatesNumber(0, config);
      expect(result, equals('EXHIBIT-000001'));
    });

    test('formats Bates string with custom prefix, suffix, and 4-digit padding', () {
      const config = BatesConfig(
        prefix: 'DOJ-SEC-',
        suffix: '-CONFIDENTIAL',
        startNumber: 42,
        paddingDigits: 4,
      );
      final result = PdfBatesNumberingService.formatBatesNumber(0, config);
      expect(result, equals('DOJ-SEC-0042-CONFIDENTIAL'));
    });

    test('increments sequentially with page offset', () {
      const config = BatesConfig(
        prefix: 'DOC-',
        startNumber: 100,
        paddingDigits: 5,
      );
      expect(PdfBatesNumberingService.formatBatesNumber(0, config), equals('DOC-00100'));
      expect(PdfBatesNumberingService.formatBatesNumber(1, config), equals('DOC-00101'));
      expect(PdfBatesNumberingService.formatBatesNumber(15, config), equals('DOC-00115'));
    });
  });

  group('PdfBatesNumberingService - generateBatesIndex', () {
    test('generates sequential records for all pages', () {
      const config = BatesConfig(prefix: 'CASE101-', startNumber: 1, paddingDigits: 3);
      final records = PdfBatesNumberingService.generateBatesIndex(3, config);

      expect(records.length, equals(3));
      expect(records[0].pageNumber, equals(1));
      expect(records[0].batesNumber, equals('CASE101-001'));
      expect(records[1].pageNumber, equals(2));
      expect(records[1].batesNumber, equals('CASE101-002'));
      expect(records[2].pageNumber, equals(3));
      expect(records[2].batesNumber, equals('CASE101-003'));
    });

    test('returns empty list for 0 or negative page counts', () {
      const config = BatesConfig();
      expect(PdfBatesNumberingService.generateBatesIndex(0, config), isEmpty);
      expect(PdfBatesNumberingService.generateBatesIndex(-5, config), isEmpty);
    });
  });

  group('PdfBatesNumberingService - exportAuditLogCsv', () {
    test('generates valid CSV header and rows', () {
      const config = BatesConfig(prefix: 'EXHIBIT-', startNumber: 1, paddingDigits: 4);
      final records = PdfBatesNumberingService.generateBatesIndex(2, config);
      final csv = PdfBatesNumberingService.exportAuditLogCsv(records, 'deposition_test.pdf');

      expect(csv, contains('Page Number,Bates Number,Document Name,Timestamp'));
      expect(csv, contains('1,"EXHIBIT-0001","deposition_test.pdf"'));
      expect(csv, contains('2,"EXHIBIT-0002","deposition_test.pdf"'));
    });

    test('escapes quotes in document names', () {
      const config = BatesConfig(prefix: 'EX-', startNumber: 1, paddingDigits: 3);
      final records = PdfBatesNumberingService.generateBatesIndex(1, config);
      final csv = PdfBatesNumberingService.exportAuditLogCsv(records, 'Smith "Special" Exhibit.pdf');

      expect(csv, contains('"Smith ""Special"" Exhibit.pdf"'));
    });
  });

  group('PdfBatesNumberingService - formatBatesStampedFileName & Config', () {
    test('formats filename with _bates suffix', () {
      const config = BatesConfig();
      final output = PdfBatesNumberingService.formatBatesStampedFileName(
        r'C:\Litigation\Trial_Brief.pdf',
        config,
      );
      expect(output, contains('Trial_Brief_bates.pdf'));
    });

    test('formats filename for path without extension', () {
      const config = BatesConfig();
      final output = PdfBatesNumberingService.formatBatesStampedFileName(
        r'C:\Temp\filing_doc',
        config,
      );
      expect(output, contains('filing_doc_bates.pdf'));
    });

    test('BatesConfig default values and copyWith', () {
      const config = BatesConfig();
      expect(config.prefix, equals('EXHIBIT-'));
      expect(config.paddingDigits, equals(6));
      expect(config.position, equals(BatesPosition.bottomRight));

      final updated = config.copyWith(
        prefix: 'DEF-',
        paddingDigits: 8,
        position: BatesPosition.topLeft,
      );

      expect(updated.prefix, equals('DEF-'));
      expect(updated.paddingDigits, equals(8));
      expect(updated.position, equals(BatesPosition.topLeft));
      expect(updated.startNumber, equals(1));
    });
  });
}
