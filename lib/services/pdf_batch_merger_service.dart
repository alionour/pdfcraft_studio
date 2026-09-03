import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfBatchMergerService {
  /// Formats output filename for merged PDF document
  static String formatMergedFileName(String firstPdfPath) {
    final baseName = p.basenameWithoutExtension(firstPdfPath);
    final ext = p.extension(firstPdfPath);
    final cleanExt = ext.isNotEmpty ? ext : '.pdf';
    return "${baseName}_merged$cleanExt";
  }

  /// Calculates combined total pages across all target PDF files
  static Future<int> calculateTotalPages(List<String> pdfPaths) async {
    int total = 0;
    for (final path in pdfPaths) {
      final file = File(path);
      if (await file.exists()) {
        final doc = await pdfx.PdfDocument.openFile(path);
        total += doc.pagesCount;
        await doc.close();
      }
    }
    return total;
  }

  /// Merges multiple PDF files into a single unified output PDF
  static Future<String> mergePdfs({
    required List<String> inputPdfPaths,
    required String outputPdfPath,
    double renderDpi = 150.0,
    Function(int current, int total)? onProgress,
  }) async {
    if (inputPdfPaths.isEmpty) {
      throw Exception("No input PDF files provided for merging");
    }

    final pdfDoc = pw.Document();
    final scale = renderDpi / 72.0;

    int totalPages = 0;
    for (final path in inputPdfPaths) {
      final file = File(path);
      if (await file.exists()) {
        final doc = await pdfx.PdfDocument.openFile(path);
        totalPages += doc.pagesCount;
        await doc.close();
      }
    }

    int processedPages = 0;
    for (final path in inputPdfPaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final inputDoc = await pdfx.PdfDocument.openFile(path);
      final count = inputDoc.pagesCount;

      for (var pageNum = 1; pageNum <= count; pageNum++) {
        final page = await inputDoc.getPage(pageNum);
        final pageImg = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.png,
        );
        final pageW = page.width;
        final pageH = page.height;
        await page.close();

        if (pageImg != null) {
          final imgWidget = pw.MemoryImage(pageImg.bytes);
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(pageW, pageH, marginAll: 0),
              build: (pw.Context context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Image(imgWidget, fit: pw.BoxFit.contain),
                  ),
                );
              },
            ),
          );
        }

        processedPages++;
        if (onProgress != null && totalPages > 0) {
          onProgress(processedPages, totalPages);
        }
      }

      await inputDoc.close();
    }

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }

    await outFile.writeAsBytes(await pdfDoc.save(), flush: true);
    return outputPdfPath;
  }
}
