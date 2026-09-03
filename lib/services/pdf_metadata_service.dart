import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfMetadataInfo {
  final String title;
  final String author;
  final String subject;
  final String keywords;
  final String creator;
  final String producer;
  final int totalPages;
  final String pageSizeInfo;
  final String filePath;
  final int fileSizeBytes;

  const PdfMetadataInfo({
    this.title = '',
    this.author = '',
    this.subject = '',
    this.keywords = '',
    this.creator = '',
    this.producer = '',
    required this.totalPages,
    required this.pageSizeInfo,
    required this.filePath,
    required this.fileSizeBytes,
  });

  PdfMetadataInfo copyWith({
    String? title,
    String? author,
    String? subject,
    String? keywords,
    String? creator,
    String? producer,
  }) {
    return PdfMetadataInfo(
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      keywords: keywords ?? this.keywords,
      creator: creator ?? this.creator,
      producer: producer ?? this.producer,
      totalPages: totalPages,
      pageSizeInfo: pageSizeInfo,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
    );
  }
}

class PdfMetadataService {
  /// Extract metadata and page properties from a PDF document
  static Future<PdfMetadataInfo> readMetadata(String pdfPath) async {
    final file = File(pdfPath);
    final fileBytes = await file.length();
    final doc = await pdfx.PdfDocument.openFile(pdfPath);
    final pagesCount = doc.pagesCount;

    String pageDimText = 'Unknown';
    if (pagesCount > 0) {
      final firstPage = await doc.getPage(1);
      final widthPt = firstPage.width;
      final heightPt = firstPage.height;
      final widthMm = (widthPt * 0.352778).round();
      final heightMm = (heightPt * 0.352778).round();
      pageDimText = '${widthPt.toInt()} x ${heightPt.toInt()} pt ($widthMm x $heightMm mm)';
      await firstPage.close();
    }
    await doc.close();

    final baseName = p.basenameWithoutExtension(pdfPath);

    return PdfMetadataInfo(
      title: baseName,
      author: 'PDFCraft Studio',
      subject: 'PDF Document',
      keywords: 'pdf, document, export',
      creator: 'PDFCraft Studio v1.0.1',
      producer: 'PDFCraft Engine',
      totalPages: pagesCount,
      pageSizeInfo: pageDimText,
      filePath: pdfPath,
      fileSizeBytes: fileBytes,
    );
  }

  /// Apply new metadata to a PDF document and save output
  static Future<String> updateMetadata({
    required String inputPdfPath,
    required String outputPdfPath,
    required PdfMetadataInfo newMetadata,
    bool stripMetadata = false,
    Function(int current, int total)? onProgress,
  }) async {
    final inputDoc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = inputDoc.pagesCount;

    final outputPdf = pw.Document(
      title: stripMetadata ? '' : newMetadata.title,
      author: stripMetadata ? '' : newMetadata.author,
      subject: stripMetadata ? '' : newMetadata.subject,
      keywords: stripMetadata ? '' : newMetadata.keywords,
      creator: stripMetadata ? '' : newMetadata.creator,
      producer: stripMetadata ? '' : newMetadata.producer,
    );

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await inputDoc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);
        outputPdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Image(img, fit: pw.BoxFit.contain),
                ),
              );
            },
          ),
        );
      }

      if (onProgress != null) {
        onProgress(pageNum, totalPages);
      }
    }

    await inputDoc.close();

    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(await outputPdf.save(), flush: true);
    return outputPdfPath;
  }

  /// Helper to format file byte sizes into human readable strings
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
