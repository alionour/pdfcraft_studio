import 'dart:ui';
import 'package:path/path.dart' as p;

enum RedactionStyle {
  blackout,
  whiteout,
  stamped,
}

class RedactionBox {
  final int pageNumber; // 1-based
  final double left; // Normalized 0.0 to 1.0 or points
  final double top;
  final double width;
  final double height;
  final String label;
  final RedactionStyle style;

  const RedactionBox({
    required this.pageNumber,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.label = 'REDACTED',
    this.style = RedactionStyle.blackout,
  });

  RedactionBox copyWith({
    int? pageNumber,
    double? left,
    double? top,
    double? width,
    double? height,
    String? label,
    RedactionStyle? style,
  }) {
    return RedactionBox(
      pageNumber: pageNumber ?? this.pageNumber,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      label: label ?? this.label,
      style: style ?? this.style,
    );
  }

  Rect toRect(double pageWidth, double pageHeight) {
    return Rect.fromLTWH(
      left * pageWidth,
      top * pageHeight,
      width * pageWidth,
      height * pageHeight,
    );
  }
}

class SensitivePatternMatch {
  final String patternType;
  final String matchedText;
  final int startIndex;
  final int endIndex;

  const SensitivePatternMatch({
    required this.patternType,
    required this.matchedText,
    required this.startIndex,
    required this.endIndex,
  });
}

class SanitizeOptions {
  final bool stripMetadata;
  final bool stripBookmarks;
  final bool stripAnnotations;
  final RedactionStyle defaultStyle;
  final String stampText;

  const SanitizeOptions({
    this.stripMetadata = true,
    this.stripBookmarks = false,
    this.stripAnnotations = true,
    this.defaultStyle = RedactionStyle.blackout,
    this.stampText = 'CONFIDENTIAL',
  });

  SanitizeOptions copyWith({
    bool? stripMetadata,
    bool? stripBookmarks,
    bool? stripAnnotations,
    RedactionStyle? defaultStyle,
    String? stampText,
  }) {
    return SanitizeOptions(
      stripMetadata: stripMetadata ?? this.stripMetadata,
      stripBookmarks: stripBookmarks ?? this.stripBookmarks,
      stripAnnotations: stripAnnotations ?? this.stripAnnotations,
      defaultStyle: defaultStyle ?? this.defaultStyle,
      stampText: stampText ?? this.stampText,
    );
  }
}

class PdfRedactionService {
  // Common PII Detection Regular Expressions
  static final RegExp emailRegex = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b',
  );

  static final RegExp phoneRegex = RegExp(
    r'(\+?\d{1,3}[-.\s]?)?(\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}\b',
  );

  static final RegExp ssnRegex = RegExp(
    r'\b\d{3}-\d{2}-\d{4}\b',
  );

  static final RegExp creditCardRegex = RegExp(
    r'\b(?:\d{4}[-\s]?){3}\d{4}\b',
  );

  /// Scans raw text for sensitive PII items and returns match positions
  static List<SensitivePatternMatch> detectSensitiveInformation(String text) {
    if (text.isEmpty) return [];

    final List<SensitivePatternMatch> matches = [];

    for (final match in emailRegex.allMatches(text)) {
      matches.add(
        SensitivePatternMatch(
          patternType: 'Email Address',
          matchedText: match.group(0) ?? '',
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    for (final match in ssnRegex.allMatches(text)) {
      matches.add(
        SensitivePatternMatch(
          patternType: 'Social Security Number (SSN)',
          matchedText: match.group(0) ?? '',
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    for (final match in creditCardRegex.allMatches(text)) {
      matches.add(
        SensitivePatternMatch(
          patternType: 'Credit Card Number',
          matchedText: match.group(0) ?? '',
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    for (final match in phoneRegex.allMatches(text)) {
      final val = match.group(0) ?? '';
      // Filter out short numbers to prevent false positives
      if (val.replaceAll(RegExp(r'\D'), '').length >= 7) {
        matches.add(
          SensitivePatternMatch(
            patternType: 'Phone Number',
            matchedText: val,
            startIndex: match.start,
            endIndex: match.end,
          ),
        );
      }
    }

    // Sort by start index
    matches.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    return matches;
  }

  /// Helper to generate output sanitized file path
  static String formatSanitizedFileName(String inputPath) {
    final dir = p.dirname(inputPath);
    final ext = p.extension(inputPath);
    final nameWithoutExt = p.basenameWithoutExtension(inputPath);

    if (ext.isEmpty) {
      return p.join(dir, '${nameWithoutExt}_sanitized.pdf');
    }
    return p.join(dir, '${nameWithoutExt}_sanitized$ext');
  }

  /// Calculates text replacement mask (e.g. "user@example.com" -> "[REDACTED EMAIL]")
  static String maskString(String input, {String mask = '█'}) {
    if (input.isEmpty) return '';
    return mask * input.length;
  }
}
