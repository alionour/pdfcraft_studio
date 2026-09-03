import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum BackgroundTintPreset {
  none,
  sepiaWarm,
  eyeCareGreen,
  darkMode,
}

class WatermarkConfig {
  final String text;
  final double opacity;
  final double fontSize;
  final double angleDegrees;
  final Color backgroundColor;

  const WatermarkConfig({
    this.text = 'CONFIDENTIAL',
    this.opacity = 0.3,
    this.fontSize = 48.0,
    this.angleDegrees = 45.0,
    this.backgroundColor = const Color(0x00FFFFFF),
  });

  static Color getBackgroundColor(BackgroundTintPreset preset) {
    switch (preset) {
      case BackgroundTintPreset.sepiaWarm:
        return const Color(0x1DFBF0D9);
      case BackgroundTintPreset.eyeCareGreen:
        return const Color(0x1DC7EDCC);
      case BackgroundTintPreset.darkMode:
        return const Color(0x1D121212);
      case BackgroundTintPreset.none:
      default:
        return const Color(0x00FFFFFF);
    }
  }

  WatermarkConfig copyWith({
    String? text,
    double? opacity,
    double? fontSize,
    double? angleDegrees,
    Color? backgroundColor,
  }) {
    return WatermarkConfig(
      text: text ?? this.text,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      angleDegrees: angleDegrees ?? this.angleDegrees,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

class PdfWatermarkBackgroundService {
  /// Formats default watermarked output filename
  static String formatWatermarkedFileName(String inputPdfPath) {
    final baseName = p.basenameWithoutExtension(inputPdfPath);
    final ext = p.extension(inputPdfPath);
    final cleanExt = ext.isNotEmpty ? ext : '.pdf';
    return "${baseName}_watermarked$cleanExt";
  }

  /// Applies background tinting and watermark text overlay across all PDF pages
  static Future<String> applyWatermarkAndBackground({
    required String inputPdfPath,
    required String outputPdfPath,
    required WatermarkConfig config,
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

    final rotAngle = config.angleDegrees * (3.141592653589793 / 180.0);

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
                child: pw.Stack(
                  children: [
                    // Background tint layer if specified
                    if (config.backgroundColor.alpha > 0)
                      pw.Container(
                        width: pageW,
                        height: pageH,
                        color: PdfColor.fromInt(config.backgroundColor.value),
                      ),
                    // Original PDF Page Content Image
                    pw.Center(
                      child: pw.Image(imgWidget, fit: pw.BoxFit.contain),
                    ),
                    // Watermark Text Overlay Layer
                    if (config.text.isNotEmpty)
                      pw.Center(
                        child: pw.Opacity(
                          opacity: config.opacity,
                          child: pw.Transform.rotateBox(
                            angle: rotAngle,
                            child: pw.Text(
                              config.text,
                              style: pw.TextStyle(
                                fontSize: config.fontSize,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
