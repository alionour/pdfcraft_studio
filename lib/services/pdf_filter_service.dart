import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

enum FilterMode {
  darkMode,
  grayscale,
  sepia,
}

enum ImageFilterType {
  none,
  grayscale,
  sepia,
  invertDarkMode,
  highContrast,
}

class PdfFilterService {
  /// Applies selected ImageFilterType filter to image byte data
  static Uint8List applyFilterToImage(
    Uint8List inputBytes,
    ImageFilterType filter,
  ) {
    if (filter == ImageFilterType.none) {
      return inputBytes;
    }

    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    img.Image processed;
    switch (filter) {
      case ImageFilterType.grayscale:
        processed = img.grayscale(decoded);
        break;
      case ImageFilterType.sepia:
        processed = img.sepia(decoded);
        break;
      case ImageFilterType.invertDarkMode:
        processed = img.invert(decoded);
        break;
      case ImageFilterType.highContrast:
        processed = img.contrast(decoded, contrast: 150);
        break;
      case ImageFilterType.none:
      default:
        processed = decoded;
        break;
    }

    return Uint8List.fromList(img.encodePng(processed));
  }

  /// Converts a PDF by rendering pages, applying specified FilterMode, and saving output PDF
  static Future<String> convertPdfWithFilter({
    required String inputPdfPath,
    required String outputPdfPath,
    required FilterMode mode,
    Function(int current, int total)? onProgress,
  }) async {
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;
    final outputPdf = pw.Document();

    ImageFilterType filterType;
    switch (mode) {
      case FilterMode.darkMode:
        filterType = ImageFilterType.invertDarkMode;
        break;
      case FilterMode.grayscale:
        filterType = ImageFilterType.grayscale;
        break;
      case FilterMode.sepia:
        filterType = ImageFilterType.sepia;
        break;
    }

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImg != null) {
        final filteredBytes = applyFilterToImage(pageImg.bytes, filterType);
        final imgWidget = pw.MemoryImage(filteredBytes);

        outputPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
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
