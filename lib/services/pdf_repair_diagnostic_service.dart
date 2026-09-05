import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

enum DiagnosticSeverity {
  healthy,
  warning,
  critical,
}

class DiagnosticIssue {
  final String code;
  final String description;
  final DiagnosticSeverity severity;
  final int offset;

  const DiagnosticIssue({
    required this.code,
    required this.description,
    required this.severity,
    this.offset = -1,
  });
}

class PdfHealthReport {
  final int healthScore; // 0 to 100%
  final String pdfVersion;
  final int objectCount;
  final int streamCount;
  final bool hasValidHeader;
  final bool hasValidEof;
  final bool hasValidTrailer;
  final List<DiagnosticIssue> issues;
  final bool isRepairable;

  const PdfHealthReport({
    required this.healthScore,
    required this.pdfVersion,
    required this.objectCount,
    required this.streamCount,
    required this.hasValidHeader,
    required this.hasValidEof,
    required this.hasValidTrailer,
    required this.issues,
    required this.isRepairable,
  });

  bool get isClean => issues.isEmpty;
}

class PdfRepairDiagnosticService {
  /// Scans raw bytes of a PDF document and evaluates structural integrity
  static PdfHealthReport diagnosePdfBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const PdfHealthReport(
        healthScore: 0,
        pdfVersion: 'Unknown',
        objectCount: 0,
        streamCount: 0,
        hasValidHeader: false,
        hasValidEof: false,
        hasValidTrailer: false,
        issues: [
          DiagnosticIssue(
            code: 'EMPTY_FILE',
            description: 'The file is 0 bytes in length.',
            severity: DiagnosticSeverity.critical,
          )
        ],
        isRepairable: false,
      );
    }

    final List<DiagnosticIssue> issues = [];
    int penalty = 0;

    // 1. Check Header (%PDF-1.x)
    final String fullText = latin1.decode(bytes, allowInvalid: true);
    final headerIndex = fullText.indexOf('%PDF-');
    bool hasValidHeader = false;
    String version = '1.4';

    if (headerIndex == -1) {
      issues.add(
        const DiagnosticIssue(
          code: 'MISSING_HEADER',
          description: 'No %PDF- magic signature found in file.',
          severity: DiagnosticSeverity.critical,
          offset: 0,
        ),
      );
      penalty += 35;
    } else if (headerIndex > 0) {
      issues.add(
        DiagnosticIssue(
          code: 'CORRUPTED_HEADER_OFFSET',
          description: '$headerIndex leading garbage bytes detected before %PDF- header.',
          severity: DiagnosticSeverity.warning,
          offset: headerIndex,
        ),
      );
      penalty += 15;
      hasValidHeader = true;
      final verSub = fullText.substring(headerIndex + 5, (headerIndex + 8).clamp(0, fullText.length));
      version = verSub.trim();
    } else {
      hasValidHeader = true;
      final verSub = fullText.substring(5, (8).clamp(0, fullText.length));
      version = verSub.trim();
    }

    // 2. Check EOF marker (%%EOF)
    final eofIndex = fullText.lastIndexOf('%%EOF');
    bool hasValidEof = false;

    if (eofIndex == -1) {
      issues.add(
        const DiagnosticIssue(
          code: 'MISSING_EOF',
          description: 'Missing %%EOF end-of-file terminator marker.',
          severity: DiagnosticSeverity.critical,
        ),
      );
      penalty += 25;
    } else {
      hasValidEof = true;
      // Check trailing bytes after EOF
      final trailingBytes = fullText.length - (eofIndex + 5);
      if (trailingBytes > 64) {
        issues.add(
          DiagnosticIssue(
            code: 'TRAILING_TRASH_BYTES',
            description: '$trailingBytes unexpected bytes detected after %%EOF marker.',
            severity: DiagnosticSeverity.warning,
            offset: eofIndex + 5,
          ),
        );
        penalty += 10;
      }
    }

    // 3. Object and Stream counts
    final objMatches = RegExp(r'\b\d+\s+\d+\s+obj\b').allMatches(fullText);
    final endObjMatches = RegExp(r'\bendobj\b').allMatches(fullText);
    final objectCount = objMatches.length;

    if (objMatches.length != endObjMatches.length) {
      issues.add(
        DiagnosticIssue(
          code: 'UNBALANCED_OBJECTS',
          description: 'Mismatched object tags: ${objMatches.length} "obj" vs ${endObjMatches.length} "endobj".',
          severity: DiagnosticSeverity.warning,
        ),
      );
      penalty += 15;
    }

    final streamMatches = RegExp(r'\bstream\b').allMatches(fullText);
    final endStreamMatches = RegExp(r'\bendstream\b').allMatches(fullText);

    if (streamMatches.length != endStreamMatches.length) {
      issues.add(
        DiagnosticIssue(
          code: 'UNCLOSED_STREAM',
          description: 'Mismatched stream markers: ${streamMatches.length} "stream" vs ${endStreamMatches.length} "endstream".',
          severity: DiagnosticSeverity.critical,
        ),
      );
      penalty += 20;
    }

    // 4. Trailer Dictionary Check
    final hasTrailer = fullText.contains('trailer') || fullText.contains('/Root');
    if (!hasTrailer) {
      issues.add(
        const DiagnosticIssue(
          code: 'MISSING_TRAILER',
          description: 'Missing trailer dictionary or /Root document catalog pointer.',
          severity: DiagnosticSeverity.critical,
        ),
      );
      penalty += 20;
    }

    final int score = (100 - penalty).clamp(0, 100);

    return PdfHealthReport(
      healthScore: score,
      pdfVersion: version.isNotEmpty ? version : '1.4',
      objectCount: objectCount,
      streamCount: streamMatches.length,
      hasValidHeader: hasValidHeader,
      hasValidEof: hasValidEof,
      hasValidTrailer: hasTrailer,
      issues: issues,
      isRepairable: hasValidHeader || objectCount > 0,
    );
  }

  /// Reconstructs and repairs syntax anomalies in the PDF bytes
  static Uint8List repairPdfBytes(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return rawBytes;

    String text = latin1.decode(rawBytes, allowInvalid: true);

    // 1. Strip leading garbage bytes before %PDF-
    final headerIndex = text.indexOf('%PDF-');
    if (headerIndex > 0) {
      text = text.substring(headerIndex);
    } else if (headerIndex == -1) {
      // Prepend standard header if completely missing
      text = '%PDF-1.4\n%âãÏÓ\n$text';
    }

    // 2. Fix unclosed streams
    final streamMatches = RegExp(r'\bstream[\r\n]').allMatches(text).toList();
    final endStreamMatches = RegExp(r'\bendstream\b').allMatches(text).toList();
    if (streamMatches.length > endStreamMatches.length) {
      // Append missing endstream for open streams
      text = '$text\nendstream\nendobj';
    }

    // 3. Fix missing %%EOF
    final trimmed = text.trimRight();
    if (!trimmed.endsWith('%%EOF')) {
      if (!trimmed.contains('startxref')) {
        text = '$trimmed\nstartxref\n${text.length}\n%%EOF\n';
      } else {
        text = '$trimmed\n%%EOF\n';
      }
    }

    return Uint8List.fromList(latin1.encode(text));
  }

  /// Formats repaired output file path
  static String formatRepairedFileName(String inputPath) {
    final dir = p.dirname(inputPath);
    final ext = p.extension(inputPath);
    final nameWithoutExt = p.basenameWithoutExtension(inputPath);

    if (ext.isEmpty) {
      return p.join(dir, '${nameWithoutExt}_repaired.pdf');
    }
    return p.join(dir, '${nameWithoutExt}_repaired$ext');
  }
}
