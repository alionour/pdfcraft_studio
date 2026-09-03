import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/pdf_form_data_service.dart';

void main() {
  group('PdfFormDataService - exportToJson', () {
    test('formats form fields into valid JSON string', () {
      const entries = [
        FormFieldEntry(fieldName: 'FullName', fieldValue: 'John Doe', pageNumber: 1),
        FormFieldEntry(fieldName: 'Email', fieldValue: 'john@example.com', pageNumber: 1),
      ];

      final jsonStr = PdfFormDataService.exportToJson(entries);
      expect(jsonStr, contains('FullName'));
      expect(jsonStr, contains('John Doe'));
      expect(jsonStr, contains('john@example.com'));
    });
  });

  group('PdfFormDataService - exportToCsv', () {
    test('formats form fields into valid CSV text', () {
      const entries = [
        FormFieldEntry(fieldName: 'Signature', fieldValue: 'Approved', pageNumber: 2),
      ];

      final csvStr = PdfFormDataService.exportToCsv(entries);
      expect(csvStr, contains('Page,Field Name,Field Value,Field Type'));
      expect(csvStr, contains('2,"Signature","Approved"'));
    });
  });
}
