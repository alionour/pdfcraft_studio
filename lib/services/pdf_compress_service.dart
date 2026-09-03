import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum CompressionPreset {
  web, // Low DPI (72 DPI)
  medium, // Standard (150 DPI)
  high, // High quality (200 DPI)
  custom,
}

class PdfCompressService {
  /// Resolves target DPI based on compression preset
  static double resolveTargetDpi(
    CompressionPreset preset, {
    double customDpi = 150.0,
  }) {
    switch (preset) {
      case CompressionPreset.web:
        return 72.0;
      case CompressionPreset.medium:
        return 150.0;
      case CompressionPreset.high:
        return 200.0;
      case CompressionPreset.custom:
        return customDpi > 0 ? customDpi : 150.0;
    }
  }

  /// Calculates percentage reduction between original and compressed file sizes
  static double calculateCompressionRatio({
    required int originalSizeBytes,
    required int compressedSizeBytes,
  }) {
    if (originalSizeBytes <= 0) return 0.0;
    final reduction = (originalSizeBytes - compressedSizeBytes) / originalSizeBytes;
    return (reduction * 100.0).clamp(-100.0, 100.0);
  }

  /// Estimates resulting compressed file size based on compression preset
  static int estimateCompressedSizeBytes({
    required int originalSizeBytes,
    required CompressionPreset preset,
  }) {
    if (originalSizeBytes <= 0) return 0;
    switch (preset) {
      case CompressionPreset.web:
        return (originalSizeBytes * 0.3).round();
      case CompressionPreset.medium:
        return (originalSizeBytes * 0.5).round();
      case CompressionPreset.high:
        return (originalSizeBytes * 0.75).round();
      case CompressionPreset.custom:
        return (originalSizeBytes * 0.6).round();
    }
  }

  /// Compresses a PDF file by re-encoding pages at specified DPI and quality
  static Future<String> compressPdf({
    required String inputPdfPath,
    required String outputPdfPath,
    CompressionPreset preset = CompressionPreset.medium,
    double customDpi = 150.0,
    Function(int current, int total)? onProgress,
  }) async {
    final targetDpi = resolveTargetDpi(preset, customDpi: customDpi);
    final scale = targetDpi / 72.0;

    final doc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = doc.pagesCount;
    final pdfDoc = pw.Document();

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await doc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
              );
            },
          ),
        );
      }

      if (onProgress != null) {
        onProgress(pageNum, totalPages);
      }
    }

    await doc.close();

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }

    final bytes = await pdfDoc.save();
    await outFile.writeAsBytes(bytes, flush: true);
    return outputPdfPath;
  }
}
