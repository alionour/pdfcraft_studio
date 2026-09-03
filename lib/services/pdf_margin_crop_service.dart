import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class MarginCropConfig {
  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;

  const MarginCropConfig({
    this.topMm = 10.0,
    this.bottomMm = 10.0,
    this.leftMm = 10.0,
    this.rightMm = 10.0,
  });

  static double mmToPoints(double mm) => mm * 2.83465;

  double get topPt => mmToPoints(topMm);
  double get bottomPt => mmToPoints(bottomMm);
  double get leftPt => mmToPoints(leftMm);
  double get rightPt => mmToPoints(rightMm);
}

class PdfMarginCropService {
  /// Adds custom padding margins around PDF document pages
  static Future<String> addPageMargins({
    required String inputPdfPath,
    required String outputPdfPath,
    MarginCropConfig config = const MarginCropConfig(),
    double renderDpi = 300.0,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(inputPdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", inputPdfPath);
    }

    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final pdfDoc = pw.Document();
    final scale = renderDpi / 72.0;

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: pdfx.PdfPageImageFormat.png,
      );

      final origW = page.width;
      final origH = page.height;
      await page.close();

      if (pageImg != null) {
        final imgWidget = pw.MemoryImage(pageImg.bytes);
        final newW = origW + config.leftPt + config.rightPt;
        final newH = origH + config.topPt + config.bottomPt;

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(newW, newH, marginAll: 0),
            build: (pw.Context context) {
              return pw.Padding(
                padding: pw.EdgeInsets.only(
                  top: config.topPt,
                  bottom: config.bottomPt,
                  left: config.leftPt,
                  right: config.rightPt,
                ),
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

  /// Alias method for margin and crop processing
  static Future<String> processMarginCrop({
    required String inputPdfPath,
    required String outputPdfPath,
    MarginCropConfig config = const MarginCropConfig(),
    double renderDpi = 300.0,
    Function(int current, int total)? onProgress,
  }) =>
      addPageMargins(
        inputPdfPath: inputPdfPath,
        outputPdfPath: outputPdfPath,
        config: config,
        renderDpi: renderDpi,
        onProgress: onProgress,
      );
}
