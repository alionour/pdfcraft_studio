import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfBookmarkNode {
  final String title;
  final int pageNumber; // 1-indexed page number

  const PdfBookmarkNode({
    required this.title,
    required this.pageNumber,
  });

  PdfBookmarkNode copyWith({
    String? title,
    int? pageNumber,
  }) {
    return PdfBookmarkNode(
      title: title ?? this.title,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }
}

class PdfBookmarkService {
  /// Validates target page numbers against maximum page count
  static List<PdfBookmarkNode> sanitizeBookmarks(
    List<PdfBookmarkNode> bookmarks,
    int maxPages,
  ) {
    return bookmarks.where((b) => b.title.isNotEmpty && b.pageNumber >= 1 && b.pageNumber <= maxPages).toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  /// Embeds dynamic outline bookmarks into a PDF document
  static Future<String> embedBookmarks({
    required String inputPdfPath,
    required String outputPdfPath,
    required List<PdfBookmarkNode> bookmarks,
    Function(int current, int total)? onProgress,
  }) async {
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final validBookmarks = sanitizeBookmarks(bookmarks, totalPages);

    final outputPdf = pw.Document();

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      final matchingBookmark = validBookmarks.cast<PdfBookmarkNode?>().firstWhere(
        (b) => b?.pageNumber == pageNum,
        orElse: () => null,
      );

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);
        outputPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              final content = pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Image(img, fit: pw.BoxFit.contain),
                ),
              );

              if (matchingBookmark != null) {
                return pw.Outline(
                  name: matchingBookmark.title,
                  title: matchingBookmark.title,
                  child: content,
                );
              }
              return content;
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
    await outFile.writeAsBytes(await outputPdf.save(), flush: true);
    return outputPdfPath;
  }
}
