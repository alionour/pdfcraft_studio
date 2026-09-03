import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;

class ExtractedImageInfo {
  final String path;
  final int pageNumber;

  const ExtractedImageInfo({
    required this.path,
    required this.pageNumber,
  });
}

class PdfImageExtractorService {
  /// Formats extracted image output filenames
  static String formatImageName({
    required String pdfName,
    required int pageNumber,
    required String extension,
  }) {
    final cleanExt = extension.toLowerCase().replaceAll('.', '');
    final paddedPage = pageNumber.toString().padLeft(3, '0');
    return "${pdfName}_extracted_page_$paddedPage.$cleanExt";
  }

  /// Extracts rendered page images from a PDF document into destination folder
  static Future<List<ExtractedImageInfo>> extractImagesFromPdf({
    required String pdfPath,
    required String outputDir,
    String format = 'png',
    double renderDpi = 300.0,
    Function(int current, int total)? onProgress,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw FileSystemException("PDF file not found", pdfPath);
    }

    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final pdfDoc = await pdfx.PdfDocument.openFile(pdfPath);
    final totalPages = pdfDoc.pagesCount;
    final pdfBaseName = p.basenameWithoutExtension(pdfPath);
    final extractedResults = <ExtractedImageInfo>[];
    final scale = renderDpi / 72.0;
    final fmt = format.toLowerCase().replaceAll('.', '');

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await pdfDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: fmt == 'png'
            ? pdfx.PdfPageImageFormat.png
            : pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImg != null) {
        final imageName = formatImageName(
          pdfName: pdfBaseName,
          pageNumber: pageNum,
          extension: fmt,
        );
        final outPath = p.join(outputDir, imageName);
        final outFile = File(outPath);
        await outFile.writeAsBytes(pageImg.bytes, flush: true);
        extractedResults.add(ExtractedImageInfo(path: outPath, pageNumber: pageNum));

        if (onProgress != null) {
          onProgress(pageNum, totalPages);
        }
      }
    }

    await pdfDoc.close();
    return extractedResults;
  }
}
