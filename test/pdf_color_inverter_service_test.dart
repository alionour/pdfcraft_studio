import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/pdf_color_inverter_service.dart';

void main() {
  group('PdfColorInverterService - formatInvertedFileName', () {
    test('formats inverted filename correctly for file with extension', () {
      const input = r'C:\Documents\annual_report.pdf';
      final output = PdfColorInverterService.formatInvertedFileName(
        input,
        ColorInversionTheme.invertedDark,
      );
      expect(output, contains('annual_report_inverteddark.pdf'));
    });

    test('formats inverted filename for solarized dark theme', () {
      const input = r'C:\Reports\whitepaper.pdf';
      final output = PdfColorInverterService.formatInvertedFileName(
        input,
        ColorInversionTheme.solarizedDark,
      );
      expect(output, contains('whitepaper_solarizeddark.pdf'));
    });

    test('formats inverted filename for file without extension', () {
      const input = r'C:\Temp\document_draft';
      final output = PdfColorInverterService.formatInvertedFileName(
        input,
        ColorInversionTheme.warmAmber,
      );
      expect(output, contains('document_draft_warmamber.pdf'));
    });
  });

  group('ColorInversionConfig', () {
    test('instantiates with default values', () {
      const config = ColorInversionConfig();
      expect(config.theme, equals(ColorInversionTheme.invertedDark));
      expect(config.contrastBoost, equals(1.0));
      expect(config.invertOnlyBackground, isFalse);
    });

    test('copyWith updates specified fields correctly', () {
      const config = ColorInversionConfig();
      final updated = config.copyWith(
        theme: ColorInversionTheme.highContrastYellow,
        contrastBoost: 1.5,
        invertOnlyBackground: true,
      );
      expect(updated.theme, equals(ColorInversionTheme.highContrastYellow));
      expect(updated.contrastBoost, equals(1.5));
      expect(updated.invertOnlyBackground, isTrue);
    });
  });

  group('PdfColorInverterService - applyColorTransform', () {
    test('inverts pure white to pure black in invertedDark mode', () {
      final imgObj = img.Image(width: 2, height: 2);
      for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
          imgObj.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
      final inputBytes = Uint8List.fromList(img.encodePng(imgObj));
      const config = ColorInversionConfig(theme: ColorInversionTheme.invertedDark);

      final resultBytes = PdfColorInverterService.applyColorTransform(inputBytes, config);
      final decoded = img.decodeImage(resultBytes);

      expect(decoded, isNotNull);
      final p0 = decoded!.getPixel(0, 0);
      expect(p0.r.toInt(), equals(0));
      expect(p0.g.toInt(), equals(0));
      expect(p0.b.toInt(), equals(0));
    });

    test('transforms high contrast yellow on dark background', () {
      final imgObj = img.Image(width: 2, height: 2);
      imgObj.setPixelRgba(0, 0, 0, 0, 0, 255); // Dark pixel (text)
      imgObj.setPixelRgba(1, 1, 255, 255, 255, 255); // Light pixel (background)

      final inputBytes = Uint8List.fromList(img.encodePng(imgObj));
      const config = ColorInversionConfig(theme: ColorInversionTheme.highContrastYellow);

      final resultBytes = PdfColorInverterService.applyColorTransform(inputBytes, config);
      final decoded = img.decodeImage(resultBytes);

      expect(decoded, isNotNull);
      final textPixel = decoded!.getPixel(0, 0);
      // Dark text transforms to bright yellow (r=255, g=230, b=0)
      expect(textPixel.r.toInt(), equals(255));
      expect(textPixel.g.toInt(), equals(230));
      expect(textPixel.b.toInt(), equals(0));

      final bgPixel = decoded.getPixel(1, 1);
      // Light background transforms to dark (r=15, g=15, b=15)
      expect(bgPixel.r.toInt(), equals(15));
      expect(bgPixel.g.toInt(), equals(15));
      expect(bgPixel.b.toInt(), equals(15));
    });
  });
}
