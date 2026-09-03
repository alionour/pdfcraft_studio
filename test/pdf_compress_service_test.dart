import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_compress_service.dart';

void main() {
  group('PdfCompressService - resolveTargetDpi', () {
    test('resolves correct DPI for web preset', () {
      expect(PdfCompressService.resolveTargetDpi(CompressionPreset.web), 72.0);
    });

    test('resolves correct DPI for medium preset', () {
      expect(PdfCompressService.resolveTargetDpi(CompressionPreset.medium), 150.0);
    });

    test('resolves correct DPI for high preset', () {
      expect(PdfCompressService.resolveTargetDpi(CompressionPreset.high), 200.0);
    });

    test('resolves custom DPI for custom preset', () {
      expect(
        PdfCompressService.resolveTargetDpi(
          CompressionPreset.custom,
          customDpi: 300.0,
        ),
        300.0,
      );
    });
  });

  group('PdfCompressService - calculateCompressionRatio', () {
    test('calculates correct reduction percentage', () {
      final ratio = PdfCompressService.calculateCompressionRatio(
        originalSizeBytes: 1000,
        compressedSizeBytes: 400,
      );
      expect(ratio, 60.0);
    });

    test('handles zero or negative original size gracefully', () {
      final ratio = PdfCompressService.calculateCompressionRatio(
        originalSizeBytes: 0,
        compressedSizeBytes: 100,
      );
      expect(ratio, 0.0);
    });
  });

  group('PdfCompressService - estimateCompressedSizeBytes', () {
    test('estimates web, medium, and high preset sizes accurately', () {
      const orig = 1000000; // 1 MB
      expect(
        PdfCompressService.estimateCompressedSizeBytes(
          originalSizeBytes: orig,
          preset: CompressionPreset.web,
        ),
        300000,
      );
      expect(
        PdfCompressService.estimateCompressedSizeBytes(
          originalSizeBytes: orig,
          preset: CompressionPreset.medium,
        ),
        500000,
      );
      expect(
        PdfCompressService.estimateCompressedSizeBytes(
          originalSizeBytes: orig,
          preset: CompressionPreset.high,
        ),
        750000,
      );
    });
  });
}
