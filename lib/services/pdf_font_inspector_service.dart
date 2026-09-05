import 'dart:convert';
import 'dart:typed_data';

class PdfFontInfo {
  final String name;
  final String baseFont;
  final String subtype;
  final bool isEmbedded;
  final bool isSubset;
  final String encoding;
  final bool hasToUnicode;
  final List<int> pageUsages;

  const PdfFontInfo({
    required this.name,
    required this.baseFont,
    required this.subtype,
    required this.isEmbedded,
    required this.isSubset,
    required this.encoding,
    required this.hasToUnicode,
    this.pageUsages = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseFont': baseFont,
        'subtype': subtype,
        'isEmbedded': isEmbedded,
        'isSubset': isSubset,
        'encoding': encoding,
        'hasToUnicode': hasToUnicode,
        'pageUsages': pageUsages,
      };
}

class FontPreflightReport {
  final int totalFonts;
  final int embeddedCount;
  final int missingCount;
  final int subsetCount;
  final int toUnicodeCompliantCount;
  final double complianceScore;
  final List<String> issues;
  final List<PdfFontInfo> fonts;

  const FontPreflightReport({
    required this.totalFonts,
    required this.embeddedCount,
    required this.missingCount,
    required this.subsetCount,
    required this.toUnicodeCompliantCount,
    required this.complianceScore,
    required this.issues,
    required this.fonts,
  });

  Map<String, dynamic> toJson() => {
        'totalFonts': totalFonts,
        'embeddedCount': embeddedCount,
        'missingCount': missingCount,
        'subsetCount': subsetCount,
        'toUnicodeCompliantCount': toUnicodeCompliantCount,
        'complianceScore': complianceScore,
        'issues': issues,
        'fonts': fonts.map((f) => f.toJson()).toList(),
      };
}

class PdfFontInspectorService {
  static final RegExp _subsetPrefixRegex = RegExp(r'^[A-Z]{6}\+');

  /// Clean font name by removing leading slash and subset tag (e.g. /BCDFEE+Arial-Bold -> Arial-Bold)
  static String cleanBaseFont(String fontName) {
    var name = fontName.trim();
    if (name.startsWith('/')) {
      name = name.substring(1);
    }
    return name.replaceAll(_subsetPrefixRegex, '');
  }

  /// Check whether font name includes a 6-letter PDF subset prefix (e.g. ABCDEF+Font)
  static bool checkIsSubset(String fontName) {
    var name = fontName.trim();
    if (name.startsWith('/')) {
      name = name.substring(1);
    }
    return _subsetPrefixRegex.hasMatch(name);
  }

  /// Inspects and analyzes all fonts in a PDF binary buffer
  static FontPreflightReport inspectFonts(Uint8List pdfBytes) {
    final pdfString = latin1.decode(pdfBytes);

    // Map all objects: objNum -> content
    final objRegex = RegExp(r'(\d+)\s+(\d+)\s+obj([\s\S]*?)endobj', caseSensitive: false);
    final objectMap = <int, String>{};

    for (final match in objRegex.allMatches(pdfString)) {
      final num = int.tryParse(match.group(1) ?? '') ?? 0;
      objectMap[num] = match.group(3) ?? '';
    }

    final fontsList = <PdfFontInfo>[];
    final seenFontNames = <String>{};

    // Standard 14 PDF core fonts that historically did not require embedding
    final standard14 = {
      'Times-Roman', 'Times-Bold', 'Times-Italic', 'Times-BoldItalic',
      'Helvetica', 'Helvetica-Bold', 'Helvetica-Oblique', 'Helvetica-BoldOblique',
      'Courier', 'Courier-Bold', 'Courier-Oblique', 'Courier-BoldOblique',
      'Symbol', 'ZapfDingbats',
    };

    final fontTypeRegex = RegExp(r'/Type\s*/Font(?![A-Za-z])');

    for (final entry in objectMap.entries) {
      final content = entry.value;
      if (!fontTypeRegex.hasMatch(content)) {
        continue;
      }

      // Extract Subtype
      String subtype = 'Unknown';
      final subtypeMatch = RegExp(r'/Subtype\s*/([A-Za-z0-9]+)').firstMatch(content);
      if (subtypeMatch != null) {
        subtype = subtypeMatch.group(1)!;
      }

      // Extract BaseFont
      String rawFontName = 'UnnamedFont_${entry.key}';
      final baseFontMatch = RegExp(r'/BaseFont\s*/([^\s/>]+)').firstMatch(content);
      if (baseFontMatch != null) {
        rawFontName = baseFontMatch.group(1)!;
      }

      // Extract Encoding
      String encoding = 'StandardEncoding';
      final encodingMatch = RegExp(r'/Encoding\s*(?:/([A-Za-z0-9\-]+)|(\d+\s+\d+\s+R))').firstMatch(content);
      if (encodingMatch != null) {
        if (encodingMatch.group(1) != null) {
          encoding = encodingMatch.group(1)!;
        } else if (encodingMatch.group(2) != null) {
          encoding = 'Custom Encoding';
        }
      }

      // Check ToUnicode
      final hasToUnicode = content.contains('/ToUnicode');

      // Check FontDescriptor for embedded font streams
      bool isEmbedded = false;
      final descMatch = RegExp(r'/FontDescriptor\s*(\d+)\s+\d+\s+R').firstMatch(content);
      if (descMatch != null) {
        final descObjNum = int.tryParse(descMatch.group(1) ?? '') ?? 0;
        final descContent = objectMap[descObjNum] ?? '';
        if (descContent.contains('/FontFile') ||
            descContent.contains('/FontFile2') ||
            descContent.contains('/FontFile3')) {
          isEmbedded = true;
        }
      }

      // Direct embedded font stream check
      if (content.contains('/FontFile')) {
        isEmbedded = true;
      }

      final isSubset = checkIsSubset(rawFontName);
      final cleanName = cleanBaseFont(rawFontName);

      // If it is a subset, it is embedded by definition
      if (isSubset) {
        isEmbedded = true;
      }

      // Deduplicate by raw font name
      if (seenFontNames.contains(rawFontName)) continue;
      seenFontNames.add(rawFontName);

      fontsList.add(
        PdfFontInfo(
          name: rawFontName,
          baseFont: cleanName,
          subtype: subtype,
          isEmbedded: isEmbedded,
          isSubset: isSubset,
          encoding: encoding,
          hasToUnicode: hasToUnicode,
        ),
      );
    }

    // Evaluate issues and compliance score
    final issues = <String>[];
    int embeddedCount = 0;
    int missingCount = 0;
    int subsetCount = 0;
    int toUnicodeCount = 0;

    for (final f in fontsList) {
      if (f.isEmbedded) {
        embeddedCount++;
      } else {
        missingCount++;
        if (standard14.contains(f.baseFont)) {
          issues.add("Font '${f.baseFont}' is a Standard-14 font but not embedded (may cause layout variance in PDF/A viewers).");
        } else {
          issues.add("Critical: Font '${f.baseFont}' is NOT embedded. Recipient devices lacking this font will substitute fallbacks, breaking layouts.");
        }
      }

      if (f.isSubset) {
        subsetCount++;
      }

      if (f.hasToUnicode) {
        toUnicodeCount++;
      } else if (f.subtype == 'Type0' || f.subtype == 'CIDFontType2') {
        issues.add("Warning: Composite font '${f.baseFont}' is missing a /ToUnicode CMap. Copying or searching text may produce garbled characters.");
      }
    }

    double score = 100.0;
    if (fontsList.isNotEmpty) {
      // 70% weight on embedding, 30% weight on ToUnicode
      final embedRatio = embeddedCount / fontsList.length;
      final toUnicodeRatio = toUnicodeCount / fontsList.length;
      score = (embedRatio * 70.0) + (toUnicodeRatio * 30.0);
      if (score > 100.0) score = 100.0;
      if (score < 0.0) score = 0.0;
    }

    return FontPreflightReport(
      totalFonts: fontsList.length,
      embeddedCount: embeddedCount,
      missingCount: missingCount,
      subsetCount: subsetCount,
      toUnicodeCompliantCount: toUnicodeCount,
      complianceScore: double.parse(score.toStringAsFixed(1)),
      issues: issues,
      fonts: fontsList,
    );
  }

  /// Exports typography preflight report as a CSV string
  static String exportCsvReport(FontPreflightReport report, {String? documentName}) {
    final buffer = StringBuffer();
    buffer.writeln('# PDFCraft Studio - Font Preflight & Typography Audit Report');
    if (documentName != null) {
      buffer.writeln('# Document: $documentName');
    }
    buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Total Fonts: ${report.totalFonts}');
    buffer.writeln('# Compliance Score: ${report.complianceScore}%');
    buffer.writeln('# Embedded: ${report.embeddedCount} | Missing: ${report.missingCount} | Subsets: ${report.subsetCount}');
    buffer.writeln('Font Name,Base Family,Subtype,Embedded,Subset,Encoding,Has ToUnicode');

    for (final f in report.fonts) {
      buffer.writeln('"${f.name}","${f.baseFont}",${f.subtype},${f.isEmbedded},${f.isSubset},"${f.encoding}",${f.hasToUnicode}');
    }

    if (report.issues.isNotEmpty) {
      buffer.writeln('\n# Issues & Diagnostics');
      for (final issue in report.issues) {
        buffer.writeln('# [!] $issue');
      }
    }

    return buffer.toString();
  }

  /// Exports typography preflight report as a JSON string
  static String exportJsonReport(FontPreflightReport report, {String? documentName}) {
    final data = {
      'application': 'PDFCraft Studio',
      'documentName': documentName,
      'generatedAt': DateTime.now().toIso8601String(),
      'report': report.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
