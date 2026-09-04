import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:image/image.dart' as img;

enum ColorInversionTheme {
  invertedDark('Night Inverted', 'Inverts all brightness values to dark mode'),
  solarizedDark('Solarized Dark', 'Comfortable navy and cyan theme for low-light reading'),
  warmAmber('Warm Amber', 'Gentle sepia-amber palette reducing blue light strain'),
  highContrastYellow('High Contrast', 'Maximum legibility yellow text on deep obsidian black');

  final String label;
  final String description;
  const ColorInversionTheme(this.label, this.description);
}

class ColorInversionConfig {
  final ColorInversionTheme theme;
  final double contrastBoost;
  final bool invertOnlyBackground;

  const ColorInversionConfig({
    this.theme = ColorInversionTheme.invertedDark,
    this.contrastBoost = 1.0,
    this.invertOnlyBackground = false,
  });

  ColorInversionConfig copyWith({
    ColorInversionTheme? theme,
    double? contrastBoost,
    bool? invertOnlyBackground,
  }) {
    return ColorInversionConfig(
      theme: theme ?? this.theme,
      contrastBoost: contrastBoost ?? this.contrastBoost,
      invertOnlyBackground: invertOnlyBackground ?? this.invertOnlyBackground,
    );
  }
}

class PdfColorInverterService {
  static String formatInvertedFileName(String originalPath, ColorInversionTheme theme) {
    final dir = p.dirname(originalPath);
    final ext = p.extension(originalPath);
    final base = p.basenameWithoutExtension(originalPath);
    final suffix = theme.name.toLowerCase();

    if (ext.isEmpty) {
      return p.join(dir, '${base}_$suffix.pdf');
    }
    return p.join(dir, '${base}_$suffix$ext');
  }

  static Uint8List applyColorTransform(
    Uint8List imageBytes,
    ColorInversionConfig config,
  ) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final width = image.width;
    final height = image.height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        int nr = r;
        int ng = g;
        int nb = b;

        switch (config.theme) {
          case ColorInversionTheme.invertedDark:
            nr = 255 - r;
            ng = 255 - g;
            nb = 255 - b;
            break;
          case ColorInversionTheme.solarizedDark:
            final lum = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
            final invLum = 255 - lum;
            nr = (invLum * 0.05).toInt().clamp(10, 40);
            ng = (invLum * 0.35 + 30).toInt().clamp(30, 160);
            nb = (invLum * 0.55 + 50).toInt().clamp(50, 220);
            break;
          case ColorInversionTheme.warmAmber:
            final lum = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
            final invLum = 255 - lum;
            nr = (invLum * 0.95 + 40).toInt().clamp(40, 255);
            ng = (invLum * 0.70 + 20).toInt().clamp(20, 190);
            nb = (invLum * 0.30 + 10).toInt().clamp(10, 80);
            break;
          case ColorInversionTheme.highContrastYellow:
            final lum = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
            if (lum > 120) {
              nr = 15;
              ng = 15;
              nb = 15;
            } else {
              nr = 255;
              ng = 230;
              nb = 0;
            }
            break;
        }

        image.setPixelRgba(x, y, nr, ng, nb, a);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  static Future<String> generateInvertedPdf({
    required String inputPdfPath,
    required ColorInversionConfig config,
    void Function(int current, int total)? onProgress,
  }) async {
    final document = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = document.pagesCount;
    final pdfOutput = pw.Document();

    for (int i = 1; i <= totalPages; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage != null) {
        final transformedBytes = applyColorTransform(pageImage.bytes, config);
        final pdfImage = pw.MemoryImage(transformedBytes);

        pdfOutput.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
              );
            },
          ),
        );
      }

      onProgress?.call(i, totalPages);
    }

    await document.close();

    final outputPath = formatInvertedFileName(inputPdfPath, config.theme);
    final file = File(outputPath);
    await file.writeAsBytes(await pdfOutput.save());
    return outputPath;
  }
}
