import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum HeaderFooterAlignment { left, center, right }

class HeaderFooterConfig {
  final String headerText;
  final String footerText;
  final HeaderFooterAlignment alignment;
  final double fontSize;
  final double marginOffset;

  const HeaderFooterConfig({
    this.headerText = '',
    this.footerText = 'Page {page} of {total}',
    this.alignment = HeaderFooterAlignment.center,
    this.fontSize = 10.0,
    this.marginOffset = 18.0,
  });

  HeaderFooterConfig copyWith({
    String? headerText,
    String? footerText,
    HeaderFooterAlignment? alignment,
    double? fontSize,
    double? marginOffset,
  }) {
    return HeaderFooterConfig(
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      alignment: alignment ?? this.alignment,
      fontSize: fontSize ?? this.fontSize,
      marginOffset: marginOffset ?? this.marginOffset,
    );
  }
}

class PdfHeaderFooterService {
  /// Formats default output filename for PDF with headers and footers
  static String formatHeaderFooterFileName(String inputPdfPath) {
    final baseName = p.basenameWithoutExtension(inputPdfPath);
    final ext = p.extension(inputPdfPath);
    final cleanExt = ext.isNotEmpty ? ext : '.pdf';
    return "${baseName}_headers$cleanExt";
  }

  /// Replaces variables in header/footer templates ({page}, {total}, {pdf_name})
  static String formatText({
    required String template,
    required int currentPage,
    required int totalPages,
    required String pdfName,
  }) {
    var result = template;
    result = result.replaceAll('{page}', '$currentPage');
    result = result.replaceAll('{total}', '$totalPages');
    result = result.replaceAll('{pdf_name}', pdfName);
    return result;
  }

  /// Maps alignment enum to pw.Alignment
  static pw.Alignment resolveAlignment(HeaderFooterAlignment alignment) {
    switch (alignment) {
      case HeaderFooterAlignment.left:
        return pw.Alignment.centerLeft;
      case HeaderFooterAlignment.right:
        return pw.Alignment.centerRight;
      case HeaderFooterAlignment.center:
      default:
        return pw.Alignment.center;
    }
  }

  /// Adds custom headers and footers to PDF document pages
  static Future<String> addHeaderAndFooter({
    required String inputPdfPath,
    required String outputPdfPath,
    required HeaderFooterConfig config,
    double renderDpi = 150.0,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(inputPdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", inputPdfPath);
    }

    final pdfName = p.basenameWithoutExtension(inputPdfPath);
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final pdfDoc = pw.Document();
    final count = inputDoc.pagesCount;
    final scale = renderDpi / 72.0;

    final align = resolveAlignment(config.alignment);

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

        final formattedHeader = formatText(
          template: config.headerText,
          currentPage: pageNum,
          totalPages: count,
          pdfName: pdfName,
        );

        final formattedFooter = formatText(
          template: config.footerText,
          currentPage: pageNum,
          totalPages: count,
          pdfName: pdfName,
        );

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageW, pageH, marginAll: 0),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Stack(
                  children: [
                    // Main document content
                    pw.Center(
                      child: pw.Image(imgWidget, fit: pw.BoxFit.contain),
                    ),

                    // Header overlay
                    if (formattedHeader.isNotEmpty)
                      pw.Positioned(
                        top: config.marginOffset,
                        left: 24,
                        right: 24,
                        child: pw.Align(
                          alignment: align,
                          child: pw.Text(
                            formattedHeader,
                            style: pw.TextStyle(
                              fontSize: config.fontSize,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      ),

                    // Footer overlay
                    if (formattedFooter.isNotEmpty)
                      pw.Positioned(
                        bottom: config.marginOffset,
                        left: 24,
                        right: 24,
                        child: pw.Align(
                          alignment: align,
                          child: pw.Text(
                            formattedFooter,
                            style: pw.TextStyle(
                              fontSize: config.fontSize,
                              color: PdfColors.grey800,
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
