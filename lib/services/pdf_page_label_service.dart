import 'dart:convert';
import 'dart:typed_data';

enum PageNumberingStyle {
  arabic,
  romanUpper,
  romanLower,
  alphaUpper,
  alphaLower,
  none,
}

class PageLabelRange {
  final int startPageIndex; // 0-based physical page index
  final PageNumberingStyle style;
  final String prefix;
  final int startNumber;

  const PageLabelRange({
    required this.startPageIndex,
    this.style = PageNumberingStyle.arabic,
    this.prefix = '',
    this.startNumber = 1,
  });

  PageLabelRange copyWith({
    int? startPageIndex,
    PageNumberingStyle? style,
    String? prefix,
    int? startNumber,
  }) {
    return PageLabelRange(
      startPageIndex: startPageIndex ?? this.startPageIndex,
      style: style ?? this.style,
      prefix: prefix ?? this.prefix,
      startNumber: startNumber ?? this.startNumber,
    );
  }

  String formatLabel(int physicalIndex) {
    if (physicalIndex < startPageIndex) return '';
    final offset = physicalIndex - startPageIndex;
    final currentVal = startNumber + offset;

    String numberPart = '';
    switch (style) {
      case PageNumberingStyle.arabic:
        numberPart = '$currentVal';
        break;
      case PageNumberingStyle.romanUpper:
        numberPart = PdfPageLabelService.toRoman(currentVal, lowercase: false);
        break;
      case PageNumberingStyle.romanLower:
        numberPart = PdfPageLabelService.toRoman(currentVal, lowercase: true);
        break;
      case PageNumberingStyle.alphaUpper:
        numberPart = PdfPageLabelService.toAlpha(currentVal, lowercase: false);
        break;
      case PageNumberingStyle.alphaLower:
        numberPart = PdfPageLabelService.toAlpha(currentVal, lowercase: true);
        break;
      case PageNumberingStyle.none:
        numberPart = '';
        break;
    }

    return '$prefix$numberPart';
  }

  Map<String, dynamic> toJson() => {
        'startPageIndex': startPageIndex,
        'style': style.name,
        'prefix': prefix,
        'startNumber': startNumber,
      };

  factory PageLabelRange.fromJson(Map<String, dynamic> json) {
    return PageLabelRange(
      startPageIndex: json['startPageIndex'] as int? ?? 0,
      style: PageNumberingStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => PageNumberingStyle.arabic,
      ),
      prefix: json['prefix'] as String? ?? '',
      startNumber: json['startNumber'] as int? ?? 1,
    );
  }
}

class PdfPageLabelService {
  /// Converts an integer to Roman numerals (e.g. 1 -> I, 4 -> IV, 14 -> XIV)
  static String toRoman(int number, {bool lowercase = false}) {
    if (number <= 0) return '$number';
    var n = number;
    final buffer = StringBuffer();

    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const numerals = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];

    for (int i = 0; i < values.length; i++) {
      while (n >= values[i]) {
        buffer.write(numerals[i]);
        n -= values[i];
      }
    }

    final result = buffer.toString();
    return lowercase ? result.toLowerCase() : result;
  }

  /// Converts an integer to PDF alphabetical sequence (1 -> A, 2 -> B... 26 -> Z, 27 -> AA, 28 -> BB...)
  static String toAlpha(int number, {bool lowercase = false}) {
    if (number <= 0) return '$number';
    var n = number - 1;
    final charCodeA = lowercase ? 97 : 65; // 'a' or 'A'
    final letter = String.fromCharCode(charCodeA + (n % 26));
    final repeatCount = (n ~/ 26) + 1;
    return letter * repeatCount;
  }

  /// Evaluates the logical label for a given 0-based page index using a list of ranges
  static String getLabelForPage(int pageIndex, List<PageLabelRange> ranges) {
    if (ranges.isEmpty) return '${pageIndex + 1}';

    // Sort ranges by startPageIndex ascending
    final sorted = List<PageLabelRange>.from(ranges)
      ..sort((a, b) => a.startPageIndex.compareTo(b.startPageIndex));

    // Find the range that covers pageIndex
    PageLabelRange activeRange = sorted.first;
    for (final r in sorted) {
      if (r.startPageIndex <= pageIndex) {
        activeRange = r;
      } else {
        break;
      }
    }

    return activeRange.formatLabel(pageIndex);
  }

  /// Parses existing PageLabels from PDF bytes
  static List<PageLabelRange> parsePageLabels(Uint8List pdfBytes) {
    final pdfString = latin1.decode(pdfBytes);
    final List<PageLabelRange> results = [];

    // Search for /PageLabels << /Nums [ ... ] >>
    final numsRegex = RegExp(
      r'/PageLabels\s*(?:<<[\s\S]*?/Nums\s*\[([\s\S]*?)\][\s\S]*?>>|(\d+)\s+(\d+)\s+R)',
      caseSensitive: false,
    );

    final match = numsRegex.firstMatch(pdfString);
    if (match == null) return results;

    String numsContent = match.group(1) ?? '';

    // If /PageLabels is an indirect reference (e.g. 14 0 R), locate that object
    if (match.group(2) != null) {
      final objNum = match.group(2);
      final objRegex = RegExp('$objNum\\s+\\d+\\s+obj([\\s\\S]*?)endobj', caseSensitive: false);
      final objMatch = objRegex.firstMatch(pdfString);
      if (objMatch != null) {
        final innerNums = RegExp(r'/Nums\s*\[([\s\S]*?)\]', caseSensitive: false).firstMatch(objMatch.group(1)!);
        if (innerNums != null) {
          numsContent = innerNums.group(1)!;
        }
      }
    }

    if (numsContent.isEmpty) return results;

    // Parse pairs: index << /S ... /P (...) /St ... >>
    final pairRegex = RegExp(
      r'(\d+)\s*<<([\s\S]*?)>>',
      caseSensitive: false,
    );

    for (final pair in pairRegex.allMatches(numsContent)) {
      final pageIndex = int.tryParse(pair.group(1) ?? '') ?? 0;
      final dict = pair.group(2) ?? '';

      // Parse Style /S
      PageNumberingStyle style = PageNumberingStyle.arabic;
      if (dict.contains('/S /D') || dict.contains('/S/D')) {
        style = PageNumberingStyle.arabic;
      } else if (dict.contains('/S /r') || dict.contains('/S/r')) {
        style = PageNumberingStyle.romanLower;
      } else if (dict.contains('/S /R') || dict.contains('/S/R')) {
        style = PageNumberingStyle.romanUpper;
      } else if (dict.contains('/S /a') || dict.contains('/S/a')) {
        style = PageNumberingStyle.alphaLower;
      } else if (dict.contains('/S /A') || dict.contains('/S/A')) {
        style = PageNumberingStyle.alphaUpper;
      } else if (!dict.contains('/S')) {
        style = PageNumberingStyle.none;
      }

      // Parse Prefix /P
      String prefix = '';
      final prefixMatch = RegExp(r'/P\s*\(([^)]*)\)').firstMatch(dict);
      if (prefixMatch != null) {
        prefix = prefixMatch.group(1)!;
      }

      // Parse Start /St
      int startNumber = 1;
      final startMatch = RegExp(r'/St\s*(\d+)').firstMatch(dict);
      if (startMatch != null) {
        startNumber = int.tryParse(startMatch.group(1) ?? '1') ?? 1;
      }

      results.add(
        PageLabelRange(
          startPageIndex: pageIndex,
          style: style,
          prefix: prefix,
          startNumber: startNumber,
        ),
      );
    }

    return results;
  }

  /// Builds the /PageLabels dictionary string for a list of ranges
  static String buildPageLabelsDict(List<PageLabelRange> ranges) {
    final sorted = List<PageLabelRange>.from(ranges)
      ..sort((a, b) => a.startPageIndex.compareTo(b.startPageIndex));

    final numsBuffer = StringBuffer();
    for (final r in sorted) {
      numsBuffer.write('${r.startPageIndex} << ');
      switch (r.style) {
        case PageNumberingStyle.arabic:
          numsBuffer.write('/S /D ');
          break;
        case PageNumberingStyle.romanLower:
          numsBuffer.write('/S /r ');
          break;
        case PageNumberingStyle.romanUpper:
          numsBuffer.write('/S /R ');
          break;
        case PageNumberingStyle.alphaLower:
          numsBuffer.write('/S /a ');
          break;
        case PageNumberingStyle.alphaUpper:
          numsBuffer.write('/S /A ');
          break;
        case PageNumberingStyle.none:
          break;
      }

      if (r.prefix.isNotEmpty) {
        final escapedPrefix = r.prefix.replaceAll('(', r'\(').replaceAll(')', r'\)');
        numsBuffer.write('/P ($escapedPrefix) ');
      }

      if (r.startNumber != 1) {
        numsBuffer.write('/St ${r.startNumber} ');
      }

      numsBuffer.write('>> ');
    }

    return '<< /Nums [ $numsBuffer] >>';
  }

  /// Injects or updates the /PageLabels dictionary into the PDF
  static Uint8List applyPageLabels(Uint8List originalPdfBytes, List<PageLabelRange> ranges) {
    if (ranges.isEmpty) return originalPdfBytes;

    final pdfString = latin1.decode(originalPdfBytes);

    // Find highest existing object number
    final objRegex = RegExp(r'(\d+)\s+0\s+obj');
    int maxObjNum = 0;
    for (final match in objRegex.allMatches(pdfString)) {
      final n = int.tryParse(match.group(1) ?? '') ?? 0;
      if (n > maxObjNum) maxObjNum = n;
    }
    if (maxObjNum == 0) maxObjNum = 10;

    final pageLabelsObjNum = maxObjNum + 1;
    final catalogObjNum = maxObjNum + 2;

    final labelsDict = buildPageLabelsDict(ranges);

    final pageLabelsObj = '''
\n$pageLabelsObjNum 0 obj
$labelsDict
endobj
''';

    final catalogObj = '''
$catalogObjNum 0 obj
<<
  /Type /Catalog
  /PageLabels $pageLabelsObjNum 0 R
>>
endobj
''';

    final trailerObj = '''
\ntrailer
<<
  /Root $catalogObjNum 0 R
>>
%%EOF\n''';

    final buffer = BytesBuilder();
    buffer.add(originalPdfBytes);
    buffer.add(latin1.encode(pageLabelsObj));
    buffer.add(latin1.encode(catalogObj));
    buffer.add(latin1.encode(trailerObj));

    return buffer.toBytes();
  }

  /// Removes /PageLabels from the PDF, resetting page numbering to defaults
  static Uint8List resetPageLabels(Uint8List originalPdfBytes) {
    String content = latin1.decode(originalPdfBytes);

    // Replace /PageLabels with empty comment
    content = content.replaceAll(
      RegExp(r'/PageLabels\s*<<[\s\S]*?>>', caseSensitive: false),
      '% stripped PageLabels',
    );
    content = content.replaceAll(
      RegExp(r'/PageLabels\s+\d+\s+\d+\s+R', caseSensitive: false),
      '',
    );

    return Uint8List.fromList(latin1.encode(content));
  }

  /// Generates CSV mapping of physical sheets to logical labels
  static String exportLabelsMappingCsv(int totalPages, List<PageLabelRange> ranges, {String? documentName}) {
    final buffer = StringBuffer();
    buffer.writeln('# PDFCraft Studio - Page Labels & Numbering Scheme');
    if (documentName != null) {
      buffer.writeln('# Document: $documentName');
    }
    buffer.writeln('# Total Pages: $totalPages');
    buffer.writeln('Physical Sheet,Logical Page Label');

    for (int i = 0; i < totalPages; i++) {
      final label = getLabelForPage(i, ranges);
      buffer.writeln('${i + 1},"$label"');
    }

    return buffer.toString();
  }

  /// Generates JSON mapping of physical sheets to logical labels
  static String exportLabelsMappingJson(int totalPages, List<PageLabelRange> ranges, {String? documentName}) {
    final pagesList = <Map<String, dynamic>>[];
    for (int i = 0; i < totalPages; i++) {
      pagesList.add({
        'sheetNumber': i + 1,
        'pageIndex': i,
        'label': getLabelForPage(i, ranges),
      });
    }

    final data = {
      'application': 'PDFCraft Studio',
      'documentName': documentName,
      'totalPages': totalPages,
      'ranges': ranges.map((r) => r.toJson()).toList(),
      'pages': pagesList,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
