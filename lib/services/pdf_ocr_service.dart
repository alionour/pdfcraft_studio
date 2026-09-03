import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class OcrResult {
  final List<String> pageTexts;
  final String combinedText;

  OcrResult({required this.pageTexts, required this.combinedText});
}

class SearchResultItem {
  final int pageNumber;
  final String snippet;
  final int matchCount;

  const SearchResultItem({
    required this.pageNumber,
    required this.snippet,
    required this.matchCount,
  });
}

class PdfOcrService {
  /// Searches extracted OCR result page texts for query keywords
  static List<SearchResultItem> searchTextInPages({
    required OcrResult result,
    required String query,
  }) {
    if (query.trim().isEmpty) return [];

    final cleanQuery = query.trim().toLowerCase();
    final results = <SearchResultItem>[];

    for (var i = 0; i < result.pageTexts.length; i++) {
      final pageNum = i + 1;
      final text = result.pageTexts[i];
      final lowerText = text.toLowerCase();

      if (lowerText.contains(cleanQuery)) {
        final matches = cleanQuery.allMatches(lowerText).length;
        final idx = lowerText.indexOf(cleanQuery);

        final start = (idx - 30).clamp(0, text.length);
        final end = (idx + cleanQuery.length + 30).clamp(0, text.length);
        final snippet = text.substring(start, end).replaceAll('\n', ' ');

        results.add(SearchResultItem(
          pageNumber: pageNum,
          snippet: "...$snippet...",
          matchCount: matches,
        ));
      }
    }

    return results;
  }
  /// Pure Dart text extraction from PDF streams (handling FlateDecode ZLib streams)
  static Future<OcrResult> extractText({
    required String pdfPath,
    Function(int current, int total)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(pdfPath);
    final totalPages = doc.pagesCount;
    final pageTexts = <String>[];

    final file = File(pdfPath);
    final bytes = await file.readAsBytes();

    final extractedLines = _parsePdfTextFromBytes(bytes);

    if (extractedLines.isNotEmpty) {
      final linesPerPage = (extractedLines.length / totalPages).ceil();
      for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
        final start = (pageNum - 1) * linesPerPage;
        final end = (start + linesPerPage > extractedLines.length)
            ? extractedLines.length
            : start + linesPerPage;

        final pageContent = (start < extractedLines.length)
            ? extractedLines.sublist(start, end).join('\n')
            : 'No selectable text detected on this page.';

        final pageBuf = StringBuffer();
        pageBuf.writeln('--- Page $pageNum ---');
        pageBuf.writeln(pageContent);
        pageTexts.add(pageBuf.toString());

        if (onProgress != null) onProgress(pageNum, totalPages);
      }
    } else {
      for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
        final pageBuf = StringBuffer();
        pageBuf.writeln('--- Page $pageNum ---');
        pageBuf.writeln('[Scanned Image Page - No embedded digital text layer detected.]');
        pageTexts.add(pageBuf.toString());
        if (onProgress != null) onProgress(pageNum, totalPages);
      }
    }

    await doc.close();
    final combined = pageTexts.join('\n\n');
    return OcrResult(pageTexts: pageTexts, combinedText: combined);
  }

  /// Decompresses PDF FlateDecode streams and extracts text strings
  static List<String> _parsePdfTextFromBytes(Uint8List bytes) {
    final lines = <String>[];
    
    // Search for text operators (Tj / TJ) across decoded chunks & raw streams
    final rawString = String.fromCharCodes(bytes.map((b) => (b >= 32 && b <= 126) ? b : 32));

    // Match text blocks inside stream objects
    final streamRegex = RegExp(r'stream[\r\n]+([\s\S]*?)[\r\n]+endstream');
    final matches = streamRegex.allMatches(rawString);

    for (final match in matches) {
      final streamStr = match.group(1);
      if (streamStr == null || streamStr.length < 5) continue;

      _extractTjStrings(streamStr, lines);

      // Decompress FlateDecode stream if ZLib encoded
      try {
        final streamUnits = streamStr.codeUnits;
        final decompressed = zlib.decode(streamUnits);
        final decodedStr = String.fromCharCodes(decompressed.map((b) => (b >= 32 && b <= 126) ? b : 32));
        _extractTjStrings(decodedStr, lines);
      } catch (_) {
        // Uncompressed stream or non-zlib payload
      }
    }

    // Fallback search across whole document
    if (lines.isEmpty) {
      _extractTjStrings(rawString, lines);
    }

    return lines;
  }

  static void _extractTjStrings(String content, List<String> lines) {
    final tjRegex = RegExp(r'\(([^)]+)\)\s*(?:Tj|TJ)');
    final matches = tjRegex.allMatches(content);
    for (final m in matches) {
      final str = m.group(1);
      if (str != null && str.trim().length > 1) {
        final cleaned = str
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\r', '')
            .replaceAll(r'\n', ' ')
            .replaceAll(r'\\', r'\')
            .trim();
        if (cleaned.isNotEmpty &&
            !cleaned.startsWith('/') &&
            !cleaned.startsWith('Font') &&
            !lines.contains(cleaned)) {
          lines.add(cleaned);
        }
      }
    }
  }

  /// Exports extracted text into a plain text file (.txt) or markdown file (.md)
  static Future<String> exportTextToFile({
    required String textContent,
    required String outputFilePath,
  }) async {
    final file = File(outputFilePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(textContent);
    return outputFilePath;
  }

  /// Creates a searchable PDF file by embedding extracted text layer
  static Future<String> createSearchablePdf({
    required String inputPdfPath,
    required String outputPdfPath,
    required List<String> pageTexts,
    Function(int current, int total)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = doc.pagesCount;
    final pdfDoc = pw.Document();

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await doc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      final pageText = (pageNum - 1 < pageTexts.length) ? pageTexts[pageNum - 1] : '';

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                  pw.Positioned.fill(
                    child: pw.Opacity(
                      opacity: 0.01,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          pageText,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      if (onProgress != null) onProgress(pageNum, totalPages);
    }

    await doc.close();

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await pdfDoc.save(), flush: true);
    return outputPdfPath;
  }
}
