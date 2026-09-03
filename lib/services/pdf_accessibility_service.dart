import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum AccessibilityPreset {
  softAmber,          // Warm amber tint for dyslexia and eye strain
  highContrastMono,   // Deep black text on stark white background
  legibilityBoost,    // Enhanced text edge contrast
}

class PdfAccessibilityService {
  /// Appylies accessibility color transformation to decoded images
  static img.Image applyAccessibilityPreset(img.Image image, AccessibilityPreset preset) {
    final copy = img.Image.from(image);

    switch (preset) {
      case AccessibilityPreset.softAmber:
        for (var y = 0; y < copy.height; y++) {
          for (var x = 0; x < copy.width; x++) {
            final p = copy.getPixel(x, y);
            final r = (p.r * 0.95).clamp(0, 255).toInt();
            final g = (p.g * 0.88).clamp(0, 255).toInt();
            final b = (p.b * 0.70).clamp(0, 255).toInt();
            copy.setPixelRgb(x, y, r, g, b);
          }
        }
        break;
      case AccessibilityPreset.highContrastMono:
        img.grayscale(copy);
        img.contrast(copy, contrast: 150);
        break;
      case AccessibilityPreset.legibilityBoost:
        img.contrast(copy, contrast: 120);
        break;
    }
    return copy;
  }

  /// Exports an accessible PDF with transformed page legibility
  static Future<String> processAccessiblePdf({
    required String inputPdfPath,
    required String outputPdfPath,
    required AccessibilityPreset preset,
    Function(int current, int total)? onProgress,
  }) async {
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final outputPdf = pw.Document();

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImg != null) {
        final decoded = img.decodeImage(pageImg.bytes);
        if (decoded != null) {
          final processed = applyAccessibilityPreset(decoded, preset);
          final encodedBytes = img.encodePng(processed);
          final memImg = pw.MemoryImage(encodedBytes);

          outputPdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
              build: (pw.Context context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Image(memImg, fit: pw.BoxFit.contain),
                  ),
                );
              },
            ),
          );
        }
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
    await outFile.writeAsBytes(await outputPdf.save(), flush: true);
    return outputPdfPath;
  }
}
