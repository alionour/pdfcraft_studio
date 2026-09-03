import 'dart:io';
import 'package:path/path.dart' as p;

class TocEntry {
  final String title;
  final int pageNumber; // 1-indexed page number
  final int level; // Hierarchy level (1 = H1, 2 = H2, etc.)

  const TocEntry({
    required this.title,
    required this.pageNumber,
    this.level = 1,
  });
}

class PdfTocService {
  /// Formats Table of Contents entries into a structured text report
  static String generateTocTextReport({
    required String pdfName,
    required List<TocEntry> entries,
  }) {
    final buffer = StringBuffer();
    buffer.writeln("========================================");
    buffer.writeln("Table of Contents: $pdfName");
    buffer.writeln("========================================");

    if (entries.isEmpty) {
      buffer.writeln("No table of contents entries found.");
      return buffer.toString();
    }

    for (var entry in entries) {
      final indent = '  ' * (entry.level - 1);
      final dotsCount = (50 - (indent.length + entry.title.length)).clamp(5, 50);
      final dots = '.' * dotsCount;
      buffer.writeln("$indent${entry.title} $dots Page ${entry.pageNumber}");
    }

    return buffer.toString();
  }

  /// Calculates total entries and highest hierarchy depth in TOC
  static Map<String, dynamic> analyzeTocStats(List<TocEntry> entries) {
    if (entries.isEmpty) {
      return {
        'totalEntries': 0,
        'maxLevel': 0,
        'firstPage': 0,
        'lastPage': 0,
      };
    }

    int maxLvl = 1;
    for (var entry in entries) {
      if (entry.level > maxLvl) maxLvl = entry.level;
    }

    return {
      'totalEntries': entries.length,
      'maxLevel': maxLvl,
      'firstPage': entries.first.pageNumber,
      'lastPage': entries.last.pageNumber,
    };
  }
}
