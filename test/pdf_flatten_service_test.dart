import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_flatten_service.dart';

void main() {
  group('PdfFlattenService - formatFlattenedFileName', () {
    test('appends _flattened to filenames ending with .pdf', () {
      final formatted = PdfFlattenService.formatFlattenedFileName('C:\\docs\\contract.pdf');
      expect(formatted, 'contract_flattened.pdf');
    });

    test('appends _flattened.pdf to filenames without extension', () {
      final formatted = PdfFlattenService.formatFlattenedFileName('my_form');
      expect(formatted, 'my_form_flattened.pdf');
    });
  });
}
