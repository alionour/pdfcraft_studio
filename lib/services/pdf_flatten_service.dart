import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum FlattenQuality {
  high,
  standard,
}

class PdfFlattenService {
  /// Formats output filename for flattened PDF document
  static String formatFlattenedFileName(String inputPdfPath) {
    final baseName = p.basenameWithoutExtension(inputPdfPath);
    final ext = p.extension(inputPdfPath);
    final cleanExt = ext.isNotEmpty ? ext : '.pdf';
    return "${baseName}_flattened$cleanExt";
  }

  /// Flattens form fields and interactive annotations into static rendered page layers
  static Future<String> flattenPdf({
    required String inputPdfPath,
    required String outputPdfPath,
    FlattenQuality quality = FlattenQuality.high,
    double? renderDpi,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(inputPdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", inputPdfPath);
    }

    final targetDpi = renderDpi ?? (quality == FlattenQuality.high ? 300.0 : 150.0);
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final pdfDoc = pw.Document();
    final scale = targetDpi / 72.0;

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
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

      if (onProgress != null) {
        onProgress(pageNum, totalPages);
      }
    }

    await inputDoc.close();

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await pdfDoc.save(), flush: true);
    return outputPdfPath;
  }
}
