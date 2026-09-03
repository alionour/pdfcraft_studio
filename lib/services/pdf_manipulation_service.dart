import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PageItemInfo {
  final int originalIndex;
  final String pdfPath;
  int rotationAngle; // 0, 90, 180, 270
  bool isSelected;

  PageItemInfo({
    required this.originalIndex,
    required this.pdfPath,
    this.rotationAngle = 0,
    this.isSelected = true,
  });
}

class PdfManipulationService {
  /// Normalizes any rotation angle degree to 0, 90, 180, or 270 degrees
  static int normalizeRotationAngle(int angle) {
    int modded = angle % 360;
    if (modded < 0) modded += 360;
    if (modded < 45 || modded >= 315) return 0;
    if (modded >= 45 && modded < 135) return 90;
    if (modded >= 135 && modded < 225) return 180;
    return 270;
  }

  /// Rotates a PageItemInfo page 90 degrees clockwise
  static void rotatePageClockwise(PageItemInfo item) {
    item.rotationAngle = normalizeRotationAngle(item.rotationAngle + 90);
  }

  /// Rotates a PageItemInfo page 90 degrees counter-clockwise
  static void rotatePageCounterClockwise(PageItemInfo item) {
    item.rotationAngle = normalizeRotationAngle(item.rotationAngle - 90);
  }
  /// Merges multiple PDF files into one output PDF path
  static Future<String> mergePdfs({
    required List<String> pdfPaths,
    required String outputPdfPath,
    Function(int current, int total)? onProgress,
  }) async {
    final pdfDoc = pw.Document();
    int totalPagesCount = 0;
    int processedPages = 0;

    // Calculate total pages for progress
    for (var pdfPath in pdfPaths) {
      final doc = await pdfx.PdfDocument.openFile(pdfPath);
      totalPagesCount += doc.pagesCount;
      await doc.close();
    }

    for (var pdfPath in pdfPaths) {
      final file = File(pdfPath);
      if (!await file.exists()) continue;

      final doc = await pdfx.PdfDocument.openFile(pdfPath);

      for (var pageNum = 1; pageNum <= doc.pagesCount; pageNum++) {
        final page = await doc.getPage(pageNum);
        final pageImg = await page.render(
          width: page.width * 2.0, // High quality render
          height: page.height * 2.0,
          format: pdfx.PdfPageImageFormat.png,
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
                  child: pw.Center(
                    child: pw.Image(img, fit: pw.BoxFit.contain),
                  ),
                );
              },
            ),
          );
        }

        processedPages++;
        if (onProgress != null) {
          onProgress(processedPages, totalPagesCount);
        }
      }
      await doc.close();
    }

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await pdfDoc.save(), flush: true);
    return outputPdfPath;
  }

  /// Splits a PDF into multiple documents based on specified ranges or chunk size
  static Future<List<String>> splitPdf({
    required String pdfPath,
    required String outputDir,
    required String splitMode, // 'ranges', 'every_n', 'single_pages'
    String rangeString = '', // e.g. '1-3, 4-6'
    int everyNPages = 1,
    Function(int current, int total)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(pdfPath);
    final totalPages = doc.pagesCount;
    final pdfName = p.basenameWithoutExtension(pdfPath);
    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final generatedFiles = <String>[];

    if (splitMode == 'single_pages' || (splitMode == 'every_n' && everyNPages == 1)) {
      for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
        final page = await doc.getPage(pageNum);
        final pageImg = await page.render(
          width: page.width * 2.0,
          height: page.height * 2.0,
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImg != null) {
          final pdfDoc = pw.Document();
          final img = pw.MemoryImage(pageImg.bytes);
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
              build: (pw.Context context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
              ),
            ),
          );
          final outPath = p.join(outputDir, "${pdfName}_page_$pageNum.pdf");
          await File(outPath).writeAsBytes(await pdfDoc.save());
          generatedFiles.add(outPath);
        }
        if (onProgress != null) onProgress(pageNum, totalPages);
      }
    } else if (splitMode == 'every_n') {
      int fileCounter = 1;
      for (var start = 1; start <= totalPages; start += everyNPages) {
        final end = (start + everyNPages - 1 > totalPages) ? totalPages : start + everyNPages - 1;
        final pdfDoc = pw.Document();

        for (var pageNum = start; pageNum <= end; pageNum++) {
          final page = await doc.getPage(pageNum);
          final pageImg = await page.render(
            width: page.width * 2.0,
            height: page.height * 2.0,
            format: pdfx.PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImg != null) {
            final img = pw.MemoryImage(pageImg.bytes);
            pdfDoc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
                build: (pw.Context context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                ),
              ),
            );
          }
          if (onProgress != null) onProgress(pageNum, totalPages);
        }

        final outPath = p.join(outputDir, "${pdfName}_part_${fileCounter}_($start-$end).pdf");
        await File(outPath).writeAsBytes(await pdfDoc.save());
        generatedFiles.add(outPath);
        fileCounter++;
      }
    } else if (splitMode == 'ranges' && rangeString.isNotEmpty) {
      final rangeGroups = rangeString.split(';');
      int partIdx = 1;

      for (var group in rangeGroups) {
        group = group.trim();
        if (group.isEmpty) continue;

        final pdfDoc = pw.Document();
        final pageIndices = parseRangeIndices(group, totalPages);

        for (var pageIndex in pageIndices) {
          final page = await doc.getPage(pageIndex + 1);
          final pageImg = await page.render(
            width: page.width * 2.0,
            height: page.height * 2.0,
            format: pdfx.PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImg != null) {
            final img = pw.MemoryImage(pageImg.bytes);
            pdfDoc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
                build: (pw.Context context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                ),
              ),
            );
          }
        }

        final outPath = p.join(outputDir, "${pdfName}_range_part_$partIdx.pdf");
        await File(outPath).writeAsBytes(await pdfDoc.save());
        generatedFiles.add(outPath);
        partIdx++;
      }
    }

    await doc.close();
    return generatedFiles;
  }

  /// Exports modified pages (reordered, rotated, or filtered) into a new PDF
  static Future<String> saveOrganizedPdf({
    required List<PageItemInfo> pages,
    required String outputPdfPath,
    Function(int current, int total)? onProgress,
  }) async {
    final pdfDoc = pw.Document();
    final activePages = pages.where((p) => p.isSelected).toList();

    for (var i = 0; i < activePages.length; i++) {
      final pageItem = activePages[i];
      final doc = await pdfx.PdfDocument.openFile(pageItem.pdfPath);
      final page = await doc.getPage(pageItem.originalIndex + 1);

      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);

        // Adjust rotation (0, 90, 180, 270)
        double angleRad = 0;
        if (pageItem.rotationAngle == 90) angleRad = 1.5708;
        if (pageItem.rotationAngle == 180) angleRad = 3.14159;
        if (pageItem.rotationAngle == 270) angleRad = 4.71239;

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: angleRad == 0
                      ? pw.Image(img, fit: pw.BoxFit.contain)
                      : pw.Transform.rotate(
                          angle: angleRad,
                          child: pw.Image(img, fit: pw.BoxFit.contain),
                        ),
                ),
              );
            },
          ),
        );
      }

      if (onProgress != null) {
        onProgress(i + 1, activePages.length);
      }
    }

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await pdfDoc.save(), flush: true);
    return outputPdfPath;
  }

  static List<int> parseRangeIndices(String rangeStr, int maxPages) {
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
    return pages.toList()..sort();
  }
}
