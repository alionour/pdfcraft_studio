import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PageOrderItem {
  final int originalPageIndex; // 1-indexed
  final int rotationDegrees;   // 0, 90, 180, 270
  final bool isDeleted;

  const PageOrderItem({
    required this.originalPageIndex,
    this.rotationDegrees = 0,
    this.isDeleted = false,
  });

  PageOrderItem copyWith({
    int? originalPageIndex,
    int? rotationDegrees,
    bool? isDeleted,
  }) {
    return PageOrderItem(
      originalPageIndex: originalPageIndex ?? this.originalPageIndex,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class PdfPageReorderService {
  /// Normalizes rotation angle to 0, 90, 180, or 270 degrees
  static int normalizeRotation(int angle) {
    final mod = angle % 360;
    return mod < 0 ? mod + 360 : mod;
  }

  /// Filters out deleted pages and returns valid page order items
  static List<PageOrderItem> getActivePages(List<PageOrderItem> items) {
    return items.where((item) => !item.isDeleted).toList();
  }

  /// Reverses the list of page items
  static List<PageOrderItem> reversePageOrder(List<PageOrderItem> items) {
    return items.reversed.toList();
  }

  /// Filters list to only odd-numbered original pages
  static List<PageOrderItem> filterOddPages(List<PageOrderItem> items) {
    return items.where((item) => item.originalPageIndex % 2 != 0).toList();
  }

  /// Filters list to only even-numbered original pages
  static List<PageOrderItem> filterEvenPages(List<PageOrderItem> items) {
    return items.where((item) => item.originalPageIndex % 2 == 0).toList();
  }

  /// Reorders, rotates, and exports PDF pages to a target file
  static Future<String> saveReorderedPdf({
    required String inputPdfPath,
    required String outputPdfPath,
    required List<PageOrderItem> pageOrder,
    double renderDpi = 150.0,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(inputPdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", inputPdfPath);
    }

    final activeItems = getActivePages(pageOrder);
    if (activeItems.isEmpty) {
      throw Exception("No pages selected for export");
    }

    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final pdfDoc = pw.Document();
    final scale = renderDpi / 72.0;
    final totalActive = activeItems.length;

    for (var idx = 0; idx < totalActive; idx++) {
      final item = activeItems[idx];
      final page = await inputDoc.getPage(item.originalPageIndex);
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
        final rotAngle = normalizeRotation(item.rotationDegrees) * (3.141592653589793 / 180.0);
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageW, pageH, marginAll: 0),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Transform.rotateBox(
                    angle: rotAngle,
                    child: pw.Image(imgWidget, fit: pw.BoxFit.contain),
                  ),
                ),
              );
            },
          ),
        );
      }

      if (onProgress != null) {
        onProgress(idx + 1, totalActive);
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
