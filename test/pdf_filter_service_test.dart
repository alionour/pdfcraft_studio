import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/pdf_filter_service.dart';

void main() {
  late Uint8List testPngBytes;

  setUp(() {
    final image = img.Image(width: 10, height: 10);
    img.fill(image, color: img.ColorRgb8(255, 100, 50));
    testPngBytes = Uint8List.fromList(img.encodePng(image));
  });

  group('PdfFilterService - applyFilterToImage', () {
    test('returns original bytes when filter is none', () {
      final result = PdfFilterService.applyFilterToImage(
        testPngBytes,
        ImageFilterType.none,
      );
      expect(result, testPngBytes);
    });

    test('applies grayscale filter without throwing exceptions', () {
      final result = PdfFilterService.applyFilterToImage(
        testPngBytes,
        ImageFilterType.grayscale,
      );
      expect(result, isNotNull);
      expect(result.isNotEmpty, isTrue);
    });

    test('applies dark mode inversion filter', () {
      final result = PdfFilterService.applyFilterToImage(
        testPngBytes,
        ImageFilterType.invertDarkMode,
      );
      expect(result, isNotNull);
      expect(result.isNotEmpty, isTrue);
    });

    test('applies sepia filter', () {
      final result = PdfFilterService.applyFilterToImage(
        testPngBytes,
        ImageFilterType.sepia,
      );
      expect(result, isNotNull);
      expect(result.isNotEmpty, isTrue);
    });
  });
}
