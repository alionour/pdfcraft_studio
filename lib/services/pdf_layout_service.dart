import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum NUpMode {
  twoUp,  // 2 pages per sheet (1x2)
  fourUp, // 4 pages per sheet (2x2)
}

class PdfLayoutService {
  /// Calculates how many output sheets will be needed given total input pages and N-Up mode
  static int calculateSheetCount(int totalPages, NUpMode mode) {
    final perSheet = mode == NUpMode.twoUp ? 2 : 4;
    return (totalPages / perSheet).ceil();
  }

  /// Converts a PDF into an N-Up grid document (2-Up or 4-Up)
  static Future<String> generateNUpPdf({
    required String inputPdfPath,
    required String outputPdfPath,
    required NUpMode mode,
    bool drawBorders = true,
    Function(int currentSheet, int totalSheets)? onProgress,
  }) async {
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final pagesPerSheet = mode == NUpMode.twoUp ? 2 : 4;
    final totalSheets = calculateSheetCount(totalPages, mode);
    final outputPdf = pw.Document();

    int pageIndex = 1;

    for (var sheetIdx = 1; sheetIdx <= totalSheets; sheetIdx++) {
      final sheetImages = <pw.MemoryImage>[];

      for (var i = 0; i < pagesPerSheet; i++) {
        if (pageIndex <= totalPages) {
          final page = await inputDoc.getPage(pageIndex);
          final pageImg = await page.render(
            width: page.width * 2.0,
            height: page.height * 2.0,
            format: pdfx.PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImg != null) {
            sheetImages.add(pw.MemoryImage(pageImg.bytes));
          }
          pageIndex++;
        }
      }

      if (mode == NUpMode.twoUp) {
        outputPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(16),
            build: (pw.Context context) {
              return pw.Row(
                children: [
                  for (var i = 0; i < sheetImages.length; i++) ...[
                    if (i > 0) pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Container(
                        decoration: drawBorders
                            ? pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                              )
                            : null,
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Image(sheetImages[i], fit: pw.BoxFit.contain),
                        ),
                      ),
                    ),
                  ],
                  if (sheetImages.length < 2)
                    pw.Expanded(child: pw.SizedBox()),
                ],
              );
            },
          ),
        );
      } else {
        // 4-Up (2x2 grid)
        final topRow = sheetImages.take(2).toList();
        final bottomRow = sheetImages.skip(2).take(2).toList();

        outputPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        for (var i = 0; i < topRow.length; i++) ...[
                          if (i > 0) pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Container(
                              decoration: drawBorders
                                  ? pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                                    )
                                  : null,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Center(
                                child: pw.Image(topRow[i], fit: pw.BoxFit.contain),
                              ),
                            ),
                          ),
                        ],
                        if (topRow.length < 2) pw.Expanded(child: pw.SizedBox()),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        for (var i = 0; i < bottomRow.length; i++) ...[
                          if (i > 0) pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Container(
                              decoration: drawBorders
                                  ? pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                                    )
                                  : null,
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Center(
                                child: pw.Image(bottomRow[i], fit: pw.BoxFit.contain),
                              ),
                            ),
                          ),
                        ],
                        if (bottomRow.isEmpty)
                          pw.Expanded(child: pw.SizedBox())
                        else if (bottomRow.length < 2)
                          pw.Expanded(child: pw.SizedBox()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      if (onProgress != null) {
        onProgress(sheetIdx, totalSheets);
      }
    }

    await inputDoc.close();

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await outputPdf.save(), flush: true);
    return outputPdfPath;
  }
}
