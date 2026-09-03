import 'dart:convert';
import 'dart:io';

class FormFieldEntry {
  final String fieldName;
  final String fieldValue;
  final String fieldType;
  final int pageNumber;

  const FormFieldEntry({
    required this.fieldName,
    required this.fieldValue,
    this.fieldType = 'text',
    this.pageNumber = 1,
  });

  String get key => fieldName;
  String get value => fieldValue;

  Map<String, dynamic> toJson() => {
        'fieldName': fieldName,
        'fieldValue': fieldValue,
        'fieldType': fieldType,
        'pageNumber': pageNumber,
      };
}

class PdfFormDataService {
  /// Exports form fields list into a valid JSON string
  static String exportToJson(List<FormFieldEntry> entries) {
    final list = entries.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Exports form fields list into a valid CSV text format
  static String exportToCsv(List<FormFieldEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('Page,Field Name,Field Value,Field Type');

    for (var entry in entries) {
      final cleanKey = _sanitizeCsvField(entry.fieldName);
      final cleanVal = _sanitizeCsvField(entry.fieldValue);
      final cleanType = _sanitizeCsvField(entry.fieldType);
      buffer.writeln('${entry.pageNumber},"$cleanKey","$cleanVal","$cleanType"');
    }

    return buffer.toString();
  }

  /// Saves exported CSV or JSON data to destination output file
  static Future<String> saveExportFile({
    required String outputPath,
    required List<FormFieldEntry> entries,
    required String format,
    String pdfName = 'document',
  }) async {
    final content = format.toLowerCase() == 'csv'
        ? exportToCsv(entries)
        : exportToJson(entries);

    final outFile = File(outputPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsString(content, flush: true);
    return outputPath;
  }

  static String _sanitizeCsvField(String field) {
    return field.replaceAll('"', '""').replaceAll('\n', ' ');
  }
}
