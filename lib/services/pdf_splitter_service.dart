import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum SplitMode {
  singlePages, // Every page to a separate file
  chunkEveryN, // Groups of N pages
  customRange, // Explicit ranges like "1-3, 5, 8-10"
}

class PdfSplitterService {
  /// Formats split filename for output chunks
  static String formatSplitFileName({
    required String inputPdfPath,
    required int chunkIndex,
    required String suffix,
  }) {
    final baseName = p.basenameWithoutExtension(inputPdfPath);
    final ext = p.extension(inputPdfPath);
    final cleanExt = ext.isNotEmpty ? ext : '.pdf';
    return "${baseName}_part${chunkIndex}_$suffix$cleanExt";
  }

  /// Calculates total chunk count given total pages and split mode settings
  static int calculateChunkCount({
    required int totalPages,
    required SplitMode mode,
    int pagesPerChunk = 2,
    List<String> customRanges = const [],
  }) {
    if (totalPages <= 0) return 0;

    switch (mode) {
      case SplitMode.singlePages:
        return totalPages;
      case SplitMode.chunkEveryN:
        if (pagesPerChunk <= 0) return 1;
        return (totalPages / pagesPerChunk).ceil();
      case SplitMode.customRange:
        return customRanges.isNotEmpty ? customRanges.length : 1;
    }
  }

  /// Splits PDF document into multiple files based on configured mode
  static Future<List<String>> splitPdf({
    required String inputPdfPath,
    required String outputDirectory,
    required SplitMode mode,
    int pagesPerChunk = 2,
    List<String> customRanges = const [],
    double renderDpi = 150.0,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(inputPdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", inputPdfPath);
    }

    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final scale = renderDpi / 72.0;

    final outputPaths = <String>[];
    final outDir = Directory(outputDirectory);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final chunkCount = calculateChunkCount(
      totalPages: totalPages,
      mode: mode,
      pagesPerChunk: pagesPerChunk,
      customRanges: customRanges,
    );

    for (var chunk = 1; chunk <= chunkCount; chunk++) {
      final pdfDoc = pw.Document();
      int startPage = 1;
      int endPage = totalPages;

      if (mode == SplitMode.singlePages) {
        startPage = chunk;
        endPage = chunk;
      } else if (mode == SplitMode.chunkEveryN) {
        startPage = (chunk - 1) * pagesPerChunk + 1;
        endPage = chunk * pagesPerChunk;
        if (endPage > totalPages) endPage = totalPages;
      }

      for (var pageNum = startPage; pageNum <= endPage; pageNum++) {
        if (pageNum > totalPages) break;
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
      }

      final suffix = mode == SplitMode.singlePages ? 'p$chunk' : 'chunk$chunk';
      final outPath = p.join(
        outputDirectory,
        formatSplitFileName(
          inputPdfPath: inputPdfPath,
          chunkIndex: chunk,
          suffix: suffix,
        ),
      );

      final outFile = File(outPath);
      await outFile.writeAsBytes(await pdfDoc.save(), flush: true);
      outputPaths.add(outPath);

      if (onProgress != null) {
        onProgress(chunk, chunkCount);
      }
    }

    await inputDoc.close();
    return outputPaths;
  }
}
