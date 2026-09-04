import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum BookletBindingType {
  saddleStitch, // Standard folded booklet (4 pages per sheet: 2 front, 2 back)
  twoUpSideBySide, // 2 pages per sheet side by side
  fourUpGrid, // 4 pages per sheet (2x2 grid)
}

class ImpositionPageSlot {
  final int pageNumber; // 1-based index (0 indicates blank page padding)
  final bool isBlank;

  const ImpositionPageSlot({required this.pageNumber, this.isBlank = false});
  const ImpositionPageSlot.blank() : pageNumber = 0, isBlank = true;
}

class ImpositionSheet {
  final int sheetIndex;
  final List<ImpositionPageSlot> frontSide;
  final List<ImpositionPageSlot> backSide;

  const ImpositionSheet({
    required this.sheetIndex,
    required this.frontSide,
    required this.backSide,
  });
}

class PdfBookletImpositionService {
  /// Computes the exact page layout order for saddle-stitch booklet binding.
  /// A saddle-stitch booklet folds sheets in half.
  /// Total pages must be a multiple of 4 (padded with blank pages if needed).
  static List<ImpositionSheet> computeSaddleStitchLayout(int pageCount) {
    if (pageCount <= 0) return [];

    final int paddedTotal = (pageCount % 4 == 0) ? pageCount : pageCount + (4 - (pageCount % 4));
    final int sheetCount = paddedTotal ~/ 4;
    final List<ImpositionSheet> sheets = [];

    for (int i = 0; i < sheetCount; i++) {
      // Front side: Left = Last Page, Right = First Page
      final int frontLeft = paddedTotal - (2 * i);
      final int frontRight = (2 * i) + 1;

      // Back side: Left = Second Page, Right = Second to Last Page
      final int backLeft = (2 * i) + 2;
      final int backRight = paddedTotal - (2 * i) - 1;

      sheets.add(
        ImpositionSheet(
          sheetIndex: i + 1,
          frontSide: [
            frontLeft <= pageCount ? ImpositionPageSlot(pageNumber: frontLeft) : const ImpositionPageSlot.blank(),
            frontRight <= pageCount ? ImpositionPageSlot(pageNumber: frontRight) : const ImpositionPageSlot.blank(),
          ],
          backSide: [
            backLeft <= pageCount ? ImpositionPageSlot(pageNumber: backLeft) : const ImpositionPageSlot.blank(),
            backRight <= pageCount ? ImpositionPageSlot(pageNumber: backRight) : const ImpositionPageSlot.blank(),
          ],
        ),
      );
    }

    return sheets;
  }

  /// Computes 2-up imposition (2 sequential pages side by side per sheet).
  static List<List<ImpositionPageSlot>> computeTwoUpLayout(int pageCount) {
    if (pageCount <= 0) return [];
    final List<List<ImpositionPageSlot>> sheets = [];

    for (int i = 1; i <= pageCount; i += 2) {
      final left = ImpositionPageSlot(pageNumber: i);
      final right = (i + 1 <= pageCount)
          ? ImpositionPageSlot(pageNumber: i + 1)
          : const ImpositionPageSlot.blank();
      sheets.add([left, right]);
    }

    return sheets;
  }

  /// Computes 4-up grid layout (4 sequential pages in a 2x2 grid per sheet).
  static List<List<ImpositionPageSlot>> computeFourUpLayout(int pageCount) {
    if (pageCount <= 0) return [];
    final List<List<ImpositionPageSlot>> sheets = [];

    for (int i = 1; i <= pageCount; i += 4) {
      final slot1 = ImpositionPageSlot(pageNumber: i);
      final slot2 = (i + 1 <= pageCount) ? ImpositionPageSlot(pageNumber: i + 1) : const ImpositionPageSlot.blank();
      final slot3 = (i + 2 <= pageCount) ? ImpositionPageSlot(pageNumber: i + 2) : const ImpositionPageSlot.blank();
      final slot4 = (i + 3 <= pageCount) ? ImpositionPageSlot(pageNumber: i + 3) : const ImpositionPageSlot.blank();
      sheets.add([slot1, slot2, slot3, slot4]);
    }

    return sheets;
  }

  /// Generates printable booklet layout plan document
  static Future<Uint8List> generateBookletSummaryPdf({
    required String documentTitle,
    required int totalOriginalPages,
    required BookletBindingType bindingType,
  }) async {
    final pdf = pw.Document();

    final saddleSheets = bindingType == BookletBindingType.saddleStitch
        ? computeSaddleStitchLayout(totalOriginalPages)
        : null;

    final nUpSheets = bindingType == BookletBindingType.twoUpSideBySide
        ? computeTwoUpLayout(totalOriginalPages)
        : bindingType == BookletBindingType.fourUpGrid
            ? computeFourUpLayout(totalOriginalPages)
            : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'PDFCraft Studio - Booklet Imposition Plan',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Binding: ${bindingType.name}',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Document: $documentTitle', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Original Page Count: $totalOriginalPages', style: const pw.TextStyle(fontSize: 12)),
                if (saddleSheets != null)
                  pw.Text('Imposed Physical Sheets Required: ${saddleSheets.length}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 16),
                pw.Text('Imposition Signature Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.SizedBox(height: 8),
                if (saddleSheets != null)
                  pw.Expanded(
                    child: pw.ListView.builder(
                      itemCount: saddleSheets.length,
                      itemBuilder: (context, index) {
                        final sheet = saddleSheets[index];
                        final fLeft = sheet.frontSide[0].isBlank ? '[Blank]' : 'p.${sheet.frontSide[0].pageNumber}';
                        final fRight = sheet.frontSide[1].isBlank ? '[Blank]' : 'p.${sheet.frontSide[1].pageNumber}';
                        final bLeft = sheet.backSide[0].isBlank ? '[Blank]' : 'p.${sheet.backSide[0].pageNumber}';
                        final bRight = sheet.backSide[1].isBlank ? '[Blank]' : 'p.${sheet.backSide[1].pageNumber}';

                        return pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 4),
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Sheet ${sheet.sheetIndex}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.Text('Front: [ $fLeft | $fRight ]'),
                              pw.Text('Back: [ $bLeft | $bRight ]'),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else if (nUpSheets != null)
                  pw.Expanded(
                    child: pw.ListView.builder(
                      itemCount: nUpSheets.length,
                      itemBuilder: (context, index) {
                        final sheet = nUpSheets[index];
                        final slots = sheet.map((s) => s.isBlank ? '[Blank]' : 'p.${s.pageNumber}').join(' | ');

                        return pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 4),
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Sheet ${index + 1}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.Text('Pages on Sheet: [ $slots ]'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
