import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum StampPosition {
  headerLeft,
  headerCenter,
  headerRight,
  footerLeft,
  footerCenter,
  footerRight,
}

enum StampPreset {
  pageNumberFooter,
  headerTitle,
  confidentialFooter,
  datePageFooter,
  custom,
}

class StampOptions {
  final String text; // e.g. "Page {page} of {total}" or "Confidential - {pdf_name}"
  final StampPosition position;
  final double fontSize;
  final PdfColor color;
  final String pageRange; // "all", "1-5", etc.

  const StampOptions({
    required this.text,
    this.position = StampPosition.footerRight,
    this.fontSize = 10.0,
    this.color = PdfColors.black,
    this.pageRange = 'all',
  });

  static StampOptions fromPreset(StampPreset preset) {
    switch (preset) {
      case StampPreset.pageNumberFooter:
        return const StampOptions(
          text: 'Page {page} of {total}',
          position: StampPosition.footerRight,
        );
      case StampPreset.headerTitle:
        return const StampOptions(
          text: '{pdf_name}',
          position: StampPosition.headerCenter,
        );
      case StampPreset.confidentialFooter:
        return const StampOptions(
          text: 'CONFIDENTIAL - {pdf_name}',
          position: StampPosition.footerLeft,
          color: PdfColors.red800,
        );
      case StampPreset.datePageFooter:
        return const StampOptions(
          text: 'Page {page} | {date}',
          position: StampPosition.footerCenter,
        );
      case StampPreset.custom:
      default:
        return const StampOptions(
          text: 'Page {page}',
          position: StampPosition.footerRight,
        );
    }
  }
}

class PdfStamperService {
  /// Format stamp template string with variables ({page}, {total}, {pdf_name}, {date})
  static String formatStampText({
    required String template,
    required int currentPage,
    required int totalPages,
    required String pdfName,
    DateTime? timestamp,
  }) {
    final dt = timestamp ?? DateTime.now();
    final dateStr =
        "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

    return template
        .replaceAll('{page}', currentPage.toString())
        .replaceAll('{total}', totalPages.toString())
        .replaceAll('{pdf_name}', pdfName)
        .replaceAll('{date}', dateStr);
  }

  /// Stamp page numbers / headers / footers onto a PDF file
  static Future<String> stampPdf({
    required String inputPdfPath,
    required String outputPdfPath,
    required StampOptions options,
    Function(int current, int total)? onProgress,
  }) async {
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final pdfName = p.basenameWithoutExtension(inputPdfPath);
    final pdfDoc = pw.Document();

    final allowedPages = parsePageRange(options.pageRange, totalPages);

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);
        final isStamped = allowedPages.contains(pageNum);
        final stampText = isStamped
            ? formatStampText(
                template: options.text,
                currentPage: pageNum,
                totalPages: totalPages,
                pdfName: pdfName,
              )
            : '';

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Center(
                      child: pw.Image(img, fit: pw.BoxFit.contain),
                    ),
                  ),
                  if (isStamped && stampText.isNotEmpty)
                    _buildStampOverlay(stampText, options, page.width, page.height),
                ],
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

  static pw.Widget _buildStampOverlay(
    String text,
    StampOptions options,
    double pageWidth,
    double pageHeight,
  ) {
    const margin = 20.0;
    final textWidget = pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: options.fontSize,
        color: options.color,
      ),
    );

    pw.Alignment alignment;
    switch (options.position) {
      case StampPosition.headerLeft:
        alignment = pw.Alignment.topLeft;
        break;
      case StampPosition.headerCenter:
        alignment = pw.Alignment.topCenter;
        break;
      case StampPosition.headerRight:
        alignment = pw.Alignment.topRight;
        break;
      case StampPosition.footerLeft:
        alignment = pw.Alignment.bottomLeft;
        break;
      case StampPosition.footerCenter:
        alignment = pw.Alignment.bottomCenter;
        break;
      case StampPosition.footerRight:
        alignment = pw.Alignment.bottomRight;
        break;
    }

    return pw.Positioned.fill(
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(margin),
        child: pw.Align(
          alignment: alignment,
          child: textWidget,
        ),
      ),
    );
  }

  static List<int> parsePageRange(String rangeStr, int maxPages) {
    final trimmed = rangeStr.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'all') {
      return List.generate(maxPages, (i) => i + 1);
    }

    final pages = <int>{};
    final parts = trimmed.split(',');

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null) {
            final minP = start < 1 ? 1 : start;
            final maxP = end > maxPages ? maxPages : end;
            for (var p = minP; p <= maxP; p++) {
              pages.add(p);
            }
          }
        }
      } else {
        final p = int.tryParse(part);
        if (p != null && p >= 1 && p <= maxPages) {
          pages.add(p);
        }
      }
    }

    return pages.isEmpty ? List.generate(maxPages, (i) => i + 1) : (pages.toList()..sort());
  }
}
