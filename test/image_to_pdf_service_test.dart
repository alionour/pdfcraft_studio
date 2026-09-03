import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter_app/services/image_to_pdf_service.dart';

void main() {
  group('ImageToPdfService - resolvePageFormat', () {
    test('resolves original image dimensions when pageSize is original', () {
      const options = ImageToPdfOptions(pageSize: ImagePageSize.original);
      final format = ImageToPdfService.resolvePageFormat(
        imageWidth: 800,
        imageHeight: 600,
        options: options,
      );

      expect(format.width, 800);
      expect(format.height, 600);
    });

    test('resolves A4 portrait and landscape auto orientation correctly', () {
      const portraitOptions = ImageToPdfOptions(
        pageSize: ImagePageSize.a4,
        orientation: ImagePageOrientation.auto,
      );

      final portraitFormat = ImageToPdfService.resolvePageFormat(
        imageWidth: 600,
        imageHeight: 800,
        options: portraitOptions,
      );
      expect(portraitFormat.width < portraitFormat.height, isTrue);

      final landscapeFormat = ImageToPdfService.resolvePageFormat(
        imageWidth: 1000,
        imageHeight: 600,
        options: portraitOptions,
      );
      expect(landscapeFormat.width > landscapeFormat.height, isTrue);
    });

    test('applies custom margins correctly', () {
      const options = ImageToPdfOptions(
        pageSize: ImagePageSize.a4,
        margin: 20.0,
      );

      final format = ImageToPdfService.resolvePageFormat(
        imageWidth: 500,
        imageHeight: 700,
        options: options,
      );

      expect(format.marginTop, 20.0);
      expect(format.marginBottom, 20.0);
      expect(format.marginLeft, 20.0);
      expect(format.marginRight, 20.0);
    });
  });
}
