import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'package:path/path.dart' as p;
import '../models/conversion_options.dart';

class PdfConverterService {
  /// Parses page range string (e.g. '1-3, 5, 7-9' or 'all') into 0-indexed page numbers
  static List<int> parsePageRange(String rangeStr, int maxPages) {
    if (rangeStr.trim().isEmpty || rangeStr.trim().toLowerCase() == 'all') {
      return List<int>.generate(maxPages, (i) => i);
    }

    final pages = <int>{};
    final parts = rangeStr.split(',');

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
              pages.add(p - 1);
            }
          }
        }
      } else {
        final p = int.tryParse(part);
        if (p != null && p >= 1 && p <= maxPages) {
          pages.add(p - 1);
        }
      }
    }

    if (pages.isEmpty) {
      return List<int>.generate(maxPages, (i) => i);
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  /// Formats filename based on naming pattern template
  static String formatFileName({
    required String pattern,
    required String pdfName,
    required int pageNumber,
    required int totalPages,
    required int dpi,
    required String format,
  }) {
    if (pattern.trim().isEmpty) {
      pattern = '{pdf_name}_page_{page}';
    }

    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final paddedPage =
        pageNumber.toString().padLeft(totalPages.toString().length, '0');

    var result = pattern
        .replaceAll('{pdf_name}', pdfName)
        .replaceAll('{page}', pageNumber.toString())
        .replaceAll('{page_padded}', paddedPage)
        .replaceAll('{total_pages}', totalPages.toString())
        .replaceAll('{dpi}', dpi.toString())
        .replaceAll('{format}', format)
        .replaceAll('{date}', dateStr);

    final cleanFmt = format.toLowerCase().replaceAll('.', '');
    if (!result.toLowerCase().endsWith('.$cleanFmt')) {
      result = '$result.$cleanFmt';
    }
    return result;
  }

  /// Converts a single PDF file to images
  static Future<List<String>> convertPdfFile({
    required String pdfPath,
    required String outputDir,
    required ConversionOptions options,
    Function(int current, int total, String savedPath)? onProgress,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", pdfPath);
    }

    final document = await PdfDocument.openFile(pdfPath);
    final totalDocPages = document.pagesCount;
    final targetPages = parsePageRange(options.pageRange, totalDocPages);

    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final pdfName = p.basenameWithoutExtension(pdfPath);
    final fmt = options.format.toLowerCase().replaceAll('.', '');
    final savedFiles = <String>[];

    // Scale calculation based on 72 DPI base
    final scale = options.dpi / 72.0;

    for (var i = 0; i < targetPages.length; i++) {
      final pageIndex = targetPages[i];
      final page = await document.getPage(pageIndex + 1); // 1-indexed in pdfx

      final pageImage = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: fmt == 'png'
            ? PdfPageImageFormat.png
            : PdfPageImageFormat.jpeg,
        backgroundColor: (fmt == 'png' && options.transparent)
            ? '#00000000'
            : '#FFFFFF',
      );

      await page.close();

      if (pageImage != null) {
        final outputFileName = formatFileName(
          pattern: options.namingPattern,
          pdfName: pdfName,
          pageNumber: pageIndex + 1,
          totalPages: totalDocPages,
          dpi: options.dpi,
          format: fmt,
        );
        final outputFilePath = p.join(outputDir, outputFileName);

        final outFile = File(outputFilePath);
        await outFile.writeAsBytes(pageImage.bytes);
        savedFiles.add(outputFilePath);

        if (onProgress != null) {
          onProgress(i + 1, targetPages.length, outputFilePath);
        }
      }
    }

    await document.close();
    return savedFiles;
  }

  /// Converts all PDF files in a directory
  static Future<Map<String, List<String>>> convertDirectory({
    required String inputDir,
    required String outputDir,
    required ConversionOptions options,
    Function(String fileName, int current, int total, String savedPath)? onProgress,
  }) async {
    final dir = Directory(inputDir);
    if (!await dir.exists()) {
      throw FileSystemException("Input directory not found", inputDir);
    }

    final results = <String, List<String>>{};
    final list = await dir.list().toList();
    final pdfFiles = list
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();

    for (var pdfFile in pdfFiles) {
      final pdfName = p.basenameWithoutExtension(pdfFile.path);
      final pdfOutputDir = p.join(outputDir, pdfName);

      final saved = await convertPdfFile(
        pdfPath: pdfFile.path,
        outputDir: pdfOutputDir,
        options: options,
        onProgress: (cur, tot, savedPath) {
          if (onProgress != null) {
            onProgress(p.basename(pdfFile.path), cur, tot, savedPath);
          }
        },
      );
      results[pdfFile.path] = saved;
    }

    return results;
  }
}
