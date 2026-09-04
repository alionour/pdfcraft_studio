import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_redaction_service.dart';

void main() {
  group('PdfRedactionService - Sensitive Data Detection', () {
    test('detects email addresses accurately', () {
      const sample = 'Please contact support@pdfcraft.com or admin.team@enterprise.org for keys.';
      final matches = PdfRedactionService.detectSensitiveInformation(sample);

      final emails = matches.where((m) => m.patternType == 'Email Address').toList();
      expect(emails.length, equals(2));
      expect(emails[0].matchedText, equals('support@pdfcraft.com'));
      expect(emails[1].matchedText, equals('admin.team@enterprise.org'));
    });

    test('detects Social Security Numbers (SSN)', () {
      const sample = 'Patient SSN record: 123-45-6789 verified.';
      final matches = PdfRedactionService.detectSensitiveInformation(sample);

      final ssns = matches.where((m) => m.patternType == 'Social Security Number (SSN)').toList();
      expect(ssns.length, equals(1));
      expect(ssns[0].matchedText, equals('123-45-6789'));
    });

    test('detects Credit Card Numbers', () {
      const sample = 'Payment processed with card: 4111-2222-3333-4444 on terminal.';
      final matches = PdfRedactionService.detectSensitiveInformation(sample);

      final ccs = matches.where((m) => m.patternType == 'Credit Card Number').toList();
      expect(ccs.length, equals(1));
      expect(ccs[0].matchedText, equals('4111-2222-3333-4444'));
    });

    test('detects Phone Numbers', () {
      const sample = 'Direct line: +1-800-555-0199 or mobile 555-123-4567.';
      final matches = PdfRedactionService.detectSensitiveInformation(sample);

      final phones = matches.where((m) => m.patternType == 'Phone Number').toList();
      expect(phones.isNotEmpty, isTrue);
    });

    test('returns empty list for empty string or text without PII', () {
      expect(PdfRedactionService.detectSensitiveInformation(''), isEmpty);
      expect(PdfRedactionService.detectSensitiveInformation('Hello world, this is a plain text file without sensitive data.'), isEmpty);
    });

    test('sorts multiple different matches by start index', () {
      const sample = 'Contact me at test@example.com or call 555-123-4567, SSN is 987-65-4321.';
      final matches = PdfRedactionService.detectSensitiveInformation(sample);

      expect(matches.length, greaterThanOrEqualTo(3));
      for (int i = 0; i < matches.length - 1; i++) {
        expect(matches[i].startIndex, lessThanOrEqualTo(matches[i + 1].startIndex));
      }
    });
  });

  group('PdfRedactionService - File Naming & Masking', () {
    test('formatSanitizedFileName appends _sanitized with extension', () {
      const input = r'C:\Legal\Confidential_Contract.pdf';
      final output = PdfRedactionService.formatSanitizedFileName(input);
      expect(output, contains('Confidential_Contract_sanitized.pdf'));
    });

    test('formatSanitizedFileName handles paths without extension', () {
      const input = r'C:\Temp\patient_medical_file';
      final output = PdfRedactionService.formatSanitizedFileName(input);
      expect(output, contains('patient_medical_file_sanitized.pdf'));
    });

    test('maskString masks characters with designated block symbol', () {
      const text = 'password123';
      final masked = PdfRedactionService.maskString(text);
      expect(masked.length, equals(text.length));
      expect(masked, equals('███████████'));
    });

    test('maskString returns empty for empty input', () {
      expect(PdfRedactionService.maskString(''), isEmpty);
    });
  });

  group('RedactionBox & SanitizeOptions models', () {
    test('RedactionBox calculates point Rect correctly', () {
      const box = RedactionBox(
        pageNumber: 1,
        left: 0.1,
        top: 0.2,
        width: 0.5,
        height: 0.1,
        style: RedactionStyle.blackout,
      );

      final rect = box.toRect(1000.0, 500.0);
      expect(rect.left, equals(100.0));
      expect(rect.top, equals(100.0));
      expect(rect.width, equals(500.0));
      expect(rect.height, equals(50.0));
    });

    test('RedactionBox copyWith updates properties correctly', () {
      const box = RedactionBox(
        pageNumber: 1,
        left: 0.1,
        top: 0.2,
        width: 0.3,
        height: 0.4,
      );

      final updated = box.copyWith(
        style: RedactionStyle.stamped,
        label: 'TOP SECRET',
      );

      expect(updated.style, equals(RedactionStyle.stamped));
      expect(updated.label, equals('TOP SECRET'));
      expect(updated.pageNumber, equals(1));
    });

    test('SanitizeOptions default values and copyWith', () {
      const options = SanitizeOptions();
      expect(options.stripMetadata, isTrue);
      expect(options.stripAnnotations, isTrue);
      expect(options.stripBookmarks, isFalse);
      expect(options.defaultStyle, equals(RedactionStyle.blackout));

      final customized = options.copyWith(
        stripBookmarks: true,
        defaultStyle: RedactionStyle.whiteout,
      );
      expect(customized.stripBookmarks, isTrue);
      expect(customized.defaultStyle, equals(RedactionStyle.whiteout));
      expect(customized.stripMetadata, isTrue);
    });
  });
}
