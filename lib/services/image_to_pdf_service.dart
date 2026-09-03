import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ImagePageSize {
  original,
  a4,
  letter,
  legal,
}

enum ImagePageOrientation {
  auto,
  portrait,
  landscape,
}

class ImageToPdfOptions {
  final ImagePageSize pageSize;
  final ImagePageOrientation orientation;
  final double margin;

  const ImageToPdfOptions({
    this.pageSize = ImagePageSize.original,
    this.orientation = ImagePageOrientation.auto,
    this.margin = 0.0,
  });
}

class ImageToPdfService {
  /// Resolves PdfPageFormat based on options and image dimensions
  static PdfPageFormat resolvePageFormat({
    required double imageWidth,
    required double imageHeight,
    required ImageToPdfOptions options,
  }) {
    if (options.pageSize == ImagePageSize.original) {
      final w = imageWidth > 0 ? imageWidth : PdfPageFormat.a4.width;
      final h = imageHeight > 0 ? imageHeight : PdfPageFormat.a4.height;
      return PdfPageFormat(w, h, marginAll: options.margin);
    }

    PdfPageFormat baseFormat;
    switch (options.pageSize) {
      case ImagePageSize.letter:
        baseFormat = PdfPageFormat.letter;
        break;
      case ImagePageSize.legal:
        baseFormat = PdfPageFormat.legal;
        break;
      case ImagePageSize.a4:
      default:
        baseFormat = PdfPageFormat.a4;
        break;
    }

    bool isLandscape;
    switch (options.orientation) {
      case ImagePageOrientation.portrait:
        isLandscape = false;
        break;
      case ImagePageOrientation.landscape:
        isLandscape = true;
        break;
      case ImagePageOrientation.auto:
      default:
        isLandscape = imageWidth > imageHeight;
        break;
    }

    final format = isLandscape ? baseFormat.landscape : baseFormat.portrait;
    return format.copyWith(
      marginTop: options.margin,
      marginBottom: options.margin,
      marginLeft: options.margin,
      marginRight: options.margin,
    );
  }

  /// Combines a list of image file paths into a single PDF document
  static Future<String> convertImagesToPdf({
    required List<String> imagePaths,
    required String outputPdfPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    Function(int current, int total, String imagePath)? onProgress,
  }) async {
    final pdf = pw.Document();

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final file = File(imagePath);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);

      final imgWidth = (image.width ?? 0).toDouble();
      final imgHeight = (image.height ?? 0).toDouble();

      final pageFormat = resolvePageFormat(
        imageWidth: imgWidth,
        imageHeight: imgHeight,
        options: options,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: options.margin == 0,
              child: pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );

      if (onProgress != null) {
        onProgress(i + 1, imagePaths.length, imagePath);
      }
    }

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await pdf.save(), flush: true);

    return outputPdfPath;
  }
}
