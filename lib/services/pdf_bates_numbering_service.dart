import 'package:path/path.dart' as p;

enum BatesPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class BatesConfig {
  final String prefix;
  final String suffix;
  final int startNumber;
  final int paddingDigits;
  final BatesPosition position;
  final double fontSize;
  final bool includeAuditLog;

  const BatesConfig({
    this.prefix = 'EXHIBIT-',
    this.suffix = '',
    this.startNumber = 1,
    this.paddingDigits = 6,
    this.position = BatesPosition.bottomRight,
    this.fontSize = 10.0,
    this.includeAuditLog = true,
  });

  BatesConfig copyWith({
    String? prefix,
    String? suffix,
    int? startNumber,
    int? paddingDigits,
    BatesPosition? position,
    double? fontSize,
    bool? includeAuditLog,
  }) {
    return BatesConfig(
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      startNumber: startNumber ?? this.startNumber,
      paddingDigits: paddingDigits ?? this.paddingDigits,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      includeAuditLog: includeAuditLog ?? this.includeAuditLog,
    );
  }
}

class BatesRecord {
  final int pageNumber;
  final String batesNumber;
  final DateTime timestamp;

  const BatesRecord({
    required this.pageNumber,
    required this.batesNumber,
    required this.timestamp,
  });
}

class PdfBatesNumberingService {
  /// Generates the exact Bates sequence string for a given page index
  static String formatBatesNumber(int pageOffset, BatesConfig config) {
    final int currentNum = config.startNumber + pageOffset;
    final String padded = currentNum.toString().padLeft(config.paddingDigits, '0');
    return '${config.prefix}$padded${config.suffix}';
  }

  /// Generates a list of Bates records for all pages
  static List<BatesRecord> generateBatesIndex(int pageCount, BatesConfig config) {
    if (pageCount <= 0) return [];
    final now = DateTime.now();
    final List<BatesRecord> records = [];

    for (int i = 0; i < pageCount; i++) {
      records.add(
        BatesRecord(
          pageNumber: i + 1,
          batesNumber: formatBatesNumber(i, config),
          timestamp: now,
        ),
      );
    }

    return records;
  }

  /// Exports an audit log CSV manifest suitable for court filings and discovery indexing
  static String exportAuditLogCsv(
    List<BatesRecord> records,
    String documentName,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Page Number,Bates Number,Document Name,Timestamp');

    for (final record in records) {
      final safeDoc = documentName.replaceAll('"', '""');
      final timeStr = record.timestamp.toIso8601String();
      buffer.writeln('${record.pageNumber},"${record.batesNumber}","$safeDoc","$timeStr"');
    }

    return buffer.toString();
  }

  /// Formats output file name with Bates suffix
  static String formatBatesStampedFileName(String inputPath, BatesConfig config) {
    final dir = p.dirname(inputPath);
    final ext = p.extension(inputPath);
    final nameWithoutExt = p.basenameWithoutExtension(inputPath);

    if (ext.isEmpty) {
      return p.join(dir, '${nameWithoutExt}_bates.pdf');
    }
    return p.join(dir, '${nameWithoutExt}_bates$ext');
  }
}
