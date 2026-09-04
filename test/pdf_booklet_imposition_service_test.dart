import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_booklet_imposition_service.dart';

void main() {
  group('PdfBookletImpositionService - Saddle Stitch Calculation', () {
    test('returns empty list for 0 or negative page counts', () {
      expect(PdfBookletImpositionService.computeSaddleStitchLayout(0), isEmpty);
      expect(PdfBookletImpositionService.computeSaddleStitchLayout(-4), isEmpty);
    });

    test('correctly imposes 4-page booklet (1 sheet)', () {
      final sheets = PdfBookletImpositionService.computeSaddleStitchLayout(4);
      expect(sheets.length, equals(1));

      final sheet1 = sheets[0];
      expect(sheet1.sheetIndex, equals(1));

      // Front side: Left = 4, Right = 1
      expect(sheet1.frontSide[0].pageNumber, equals(4));
      expect(sheet1.frontSide[0].isBlank, isFalse);
      expect(sheet1.frontSide[1].pageNumber, equals(1));
      expect(sheet1.frontSide[1].isBlank, isFalse);

      // Back side: Left = 2, Right = 3
      expect(sheet1.backSide[0].pageNumber, equals(2));
      expect(sheet1.backSide[0].isBlank, isFalse);
      expect(sheet1.backSide[1].pageNumber, equals(3));
      expect(sheet1.backSide[1].isBlank, isFalse);
    });

    test('correctly imposes 8-page booklet (2 sheets)', () {
      final sheets = PdfBookletImpositionService.computeSaddleStitchLayout(8);
      expect(sheets.length, equals(2));

      // Sheet 1
      expect(sheets[0].frontSide[0].pageNumber, equals(8));
      expect(sheets[0].frontSide[1].pageNumber, equals(1));
      expect(sheets[0].backSide[0].pageNumber, equals(2));
      expect(sheets[0].backSide[1].pageNumber, equals(7));

      // Sheet 2
      expect(sheets[1].frontSide[0].pageNumber, equals(6));
      expect(sheets[1].frontSide[1].pageNumber, equals(3));
      expect(sheets[1].backSide[0].pageNumber, equals(4));
      expect(sheets[1].backSide[1].pageNumber, equals(5));
    });

    test('correctly pads 5-page document to 8 pages with blank slots', () {
      final sheets = PdfBookletImpositionService.computeSaddleStitchLayout(5);
      expect(sheets.length, equals(2));

      // Padded slots (> 5) should be blank with pageNumber = 0
      // Sheet 1: Front Left was 8 (blank), Front Right was 1
      expect(sheets[0].frontSide[0].isBlank, isTrue);
      expect(sheets[0].frontSide[0].pageNumber, equals(0));
      expect(sheets[0].frontSide[1].isBlank, isFalse);
      expect(sheets[0].frontSide[1].pageNumber, equals(1));

      // Sheet 1: Back Left was 2, Back Right was 7 (blank)
      expect(sheets[0].backSide[0].isBlank, isFalse);
      expect(sheets[0].backSide[0].pageNumber, equals(2));
      expect(sheets[0].backSide[1].isBlank, isTrue);
      expect(sheets[0].backSide[1].pageNumber, equals(0));

      // Sheet 2: Front Left was 6 (blank), Front Right was 3
      expect(sheets[1].frontSide[0].isBlank, isTrue);
      expect(sheets[1].frontSide[0].pageNumber, equals(0));
      expect(sheets[1].frontSide[1].isBlank, isFalse);
      expect(sheets[1].frontSide[1].pageNumber, equals(3));

      // Sheet 2: Back Left was 4, Back Right was 5
      expect(sheets[1].backSide[0].isBlank, isFalse);
      expect(sheets[1].backSide[0].pageNumber, equals(4));
      expect(sheets[1].backSide[1].isBlank, isFalse);
      expect(sheets[1].backSide[1].pageNumber, equals(5));
    });
  });

  group('PdfBookletImpositionService - 2-Up Side-by-Side', () {
    test('returns empty list for 0 or negative page counts', () {
      expect(PdfBookletImpositionService.computeTwoUpLayout(0), isEmpty);
      expect(PdfBookletImpositionService.computeTwoUpLayout(-1), isEmpty);
    });

    test('correctly pairs even page counts', () {
      final sheets = PdfBookletImpositionService.computeTwoUpLayout(4);
      expect(sheets.length, equals(2));
      expect(sheets[0][0].pageNumber, equals(1));
      expect(sheets[0][1].pageNumber, equals(2));
      expect(sheets[1][0].pageNumber, equals(3));
      expect(sheets[1][1].pageNumber, equals(4));
    });

    test('correctly pads odd page count with trailing blank slot', () {
      final sheets = PdfBookletImpositionService.computeTwoUpLayout(3);
      expect(sheets.length, equals(2));
      expect(sheets[0][0].pageNumber, equals(1));
      expect(sheets[0][1].pageNumber, equals(2));
      expect(sheets[1][0].pageNumber, equals(3));
      expect(sheets[1][1].isBlank, isTrue);
      expect(sheets[1][1].pageNumber, equals(0));
    });
  });

  group('PdfBookletImpositionService - 4-Up Grid', () {
    test('returns empty list for 0 or negative page counts', () {
      expect(PdfBookletImpositionService.computeFourUpLayout(0), isEmpty);
    });

    test('correctly groups 4 pages into single sheet grid', () {
      final sheets = PdfBookletImpositionService.computeFourUpLayout(4);
      expect(sheets.length, equals(1));
      expect(sheets[0].map((s) => s.pageNumber).toList(), equals([1, 2, 3, 4]));
      expect(sheets[0].every((s) => !s.isBlank), isTrue);
    });

    test('correctly pads remaining slots when page count is not multiple of 4', () {
      final sheets = PdfBookletImpositionService.computeFourUpLayout(5);
      expect(sheets.length, equals(2));
      // First sheet: 1, 2, 3, 4
      expect(sheets[0].map((s) => s.pageNumber).toList(), equals([1, 2, 3, 4]));
      // Second sheet: 5, blank, blank, blank
      expect(sheets[1][0].pageNumber, equals(5));
      expect(sheets[1][0].isBlank, isFalse);
      expect(sheets[1][1].isBlank, isTrue);
      expect(sheets[1][2].isBlank, isTrue);
      expect(sheets[1][3].isBlank, isTrue);
    });
  });

  group('PdfBookletImpositionService - Summary PDF Generation', () {
    test('generates valid PDF byte array for saddle stitch', () async {
      final pdfBytes = await PdfBookletImpositionService.generateBookletSummaryPdf(
        documentTitle: 'Sample Brochure',
        totalOriginalPages: 8,
        bindingType: BookletBindingType.saddleStitch,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF header validation (%PDF-)
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generates valid PDF byte array for 2-up layout', () async {
      final pdfBytes = await PdfBookletImpositionService.generateBookletSummaryPdf(
        documentTitle: 'Handout Document',
        totalOriginalPages: 6,
        bindingType: BookletBindingType.twoUpSideBySide,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generates valid PDF byte array for 4-up grid', () async {
      final pdfBytes = await PdfBookletImpositionService.generateBookletSummaryPdf(
        documentTitle: 'Presentation Slides',
        totalOriginalPages: 10,
        bindingType: BookletBindingType.fourUpGrid,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
