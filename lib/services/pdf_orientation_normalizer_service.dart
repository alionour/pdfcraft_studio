import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum TargetPageSize { a4, letter, legal }

enum TargetOrientation { portrait, landscape, autoUniform }

class PdfOrientationNormalizerService {
  /// Formats default normalized output filename
  static String formatNormalizedFileName(String inputPdfPath) {
    final baseName = p.basenameWithoutExtension(inputPdfPath);
    final ext = p.extension(inputPdfPath);
    final cleanExt = ext.isNotEmpty ? ext : '.pdf';
    return "${baseName}_normalized$cleanExt";
  }

  /// Resolves target PdfPageFormat based on size and orientation choice
  static PdfPageFormat resolvePageFormat(TargetPageSize size, TargetOrientation orientation) {
    PdfPageFormat baseFormat;
    switch (size) {
      case TargetPageSize.letter:
        baseFormat = PdfPageFormat.letter;
        break;
      case TargetPageSize.legal:
        baseFormat = PdfPageFormat.legal;
        break;
      case TargetPageSize.a4:
      default:
        baseFormat = PdfPageFormat.a4;
        break;
    }

    if (orientation == TargetOrientation.landscape) {
      return baseFormat.landscape;
    } else if (orientation == TargetOrientation.portrait) {
      return baseFormat.portrait;
    }
    return baseFormat;
  }

  /// Checks whether page dimensions represent landscape aspect ratio
  static bool isLandscapeAspect({required double width, required double height}) {
    return width > height;
  }

  /// Standardizes mixed page sizes and orientations into uniform output format
  static Future<String> normalizePdf({
    required String inputPdfPath,
    required String outputPdfPath,
    TargetPageSize targetSize = TargetPageSize.a4,
    TargetOrientation targetOrientation = TargetOrientation.portrait,
    double renderDpi = 150.0,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(inputPdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", inputPdfPath);
    }

    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final pdfDoc = pw.Document();
    final count = inputDoc.pagesCount;
    final scale = renderDpi / 72.0;

    final targetFormat = resolvePageFormat(targetSize, targetOrientation);

    for (var pageNum = 1; pageNum <= count; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImg != null) {
        final imgWidget = pw.MemoryImage(pageImg.bytes);
        pdfDoc.addPage(
          pw.Page(
            pageFormat: targetFormat.copyWith(marginTop: 0, marginBottom: 0, marginLeft: 0, marginRight: 0),
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
        onProgress(pageNum, count);
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
