import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

enum AttachmentSecurityRisk {
  safe,
  caution,
  danger,
}

class PdfAttachmentInfo {
  final String id;
  final String name;
  final String description;
  final int size;
  final String mimeType;
  final DateTime? modificationDate;
  final String sha256;
  final AttachmentSecurityRisk securityRisk;
  final Uint8List data;

  const PdfAttachmentInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.size,
    required this.mimeType,
    this.modificationDate,
    required this.sha256,
    required this.securityRisk,
    required this.data,
  });

  String get humanSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'size': size,
        'humanSize': humanSize,
        'mimeType': mimeType,
        'modificationDate': modificationDate?.toIso8601String(),
        'sha256': sha256,
        'securityRisk': securityRisk.name,
      };
}

class FileToAttach {
  final String name;
  final String description;
  final Uint8List data;
  final String? mimeType;

  const FileToAttach({
    required this.name,
    this.description = '',
    required this.data,
    this.mimeType,
  });
}

class PdfAttachmentService {
  static const Set<String> _dangerExtensions = {
    'exe', 'dll', 'bat', 'cmd', 'ps1', 'vbs', 'js', 'vbe', 'wsf', 'scr',
    'pif', 'com', 'hta', 'jar', 'msi', 'reg', 'sh', 'bash', 'bin', 'cpl',
  };

  static const Set<String> _cautionExtensions = {
    'xlsm', 'docm', 'pptm', 'zip', 'rar', '7z', 'tar', 'gz', 'iso',
  };

  /// Evaluates security risk based on filename extension
  static AttachmentSecurityRisk evaluateSecurityRisk(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    if (_dangerExtensions.contains(ext)) {
      return AttachmentSecurityRisk.danger;
    }
    if (_cautionExtensions.contains(ext)) {
      return AttachmentSecurityRisk.caution;
    }
    return AttachmentSecurityRisk.safe;
  }

  /// Derives likely MIME type from file extension
  static String deriveMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'xml':
        return 'application/xml';
      case 'json':
        return 'application/json';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Inspects and parses all embedded file specifications and streams from PDF bytes
  static List<PdfAttachmentInfo> inspectAttachments(Uint8List pdfBytes) {
    final List<PdfAttachmentInfo> attachments = [];
    final rawPdfString = latin1.decode(pdfBytes);

    // Find all objects: N 0 obj ... endobj
    final objRegex = RegExp(
      r'(\d+)\s+(\d+)\s+obj([\s\S]*?)endobj',
      caseSensitive: false,
    );

    final visitedStreamObjs = <int>{};
    final Map<int, String> objectContents = {};

    for (final match in objRegex.allMatches(rawPdfString)) {
      final objNum = int.tryParse(match.group(1) ?? '') ?? 0;
      final content = match.group(3) ?? '';
      objectContents[objNum] = content;
    }

    // 1. Process Filespec objects
    for (final entry in objectContents.entries) {
      final objNum = entry.key;
      final content = entry.value;

      if (!content.contains('/Type /Filespec') && !content.contains('/Type/Filespec')) {
        continue;
      }

      // Extract filename
      String fileName = 'attachment_$objNum.dat';
      final ufMatch = RegExp(r'/UF\s*\(([^)]+)\)').firstMatch(content);
      final fMatch = RegExp(r'/F\s*\(([^)]+)\)').firstMatch(content);
      final hexUfMatch = RegExp(r'/UF\s*<([0-9a-fA-F]+)>').firstMatch(content);

      if (ufMatch != null) {
        fileName = _unescapePdfString(ufMatch.group(1)!);
      } else if (fMatch != null) {
        fileName = _unescapePdfString(fMatch.group(1)!);
      } else if (hexUfMatch != null) {
        fileName = _decodeHexString(hexUfMatch.group(1)!);
      }

      // Extract description
      String description = '';
      final descMatch = RegExp(r'/Desc\s*\(([^)]*)\)').firstMatch(content);
      if (descMatch != null) {
        description = _unescapePdfString(descMatch.group(1)!);
      }

      // Extract stream reference in /EF << ... /F X 0 R ... >>
      final efMatch = RegExp(r'/EF\s*<<[\s\S]*?/F\s*(\d+)\s+\d+\s+R').firstMatch(content);
      if (efMatch != null) {
        final streamObjNum = int.tryParse(efMatch.group(1) ?? '') ?? 0;
        visitedStreamObjs.add(streamObjNum);

        final streamData = _extractStreamBytes(rawPdfString, pdfBytes, streamObjNum);
        if (streamData != null) {
          final hash = sha256.convert(streamData).toString();
          final risk = evaluateSecurityRisk(fileName);
          final mime = deriveMimeType(fileName);

          attachments.add(
            PdfAttachmentInfo(
              id: 'filespec_$objNum',
              name: fileName,
              description: description,
              size: streamData.length,
              mimeType: mime,
              modificationDate: DateTime.now(),
              sha256: hash,
              securityRisk: risk,
              data: streamData,
            ),
          );
        }
      }
    }

    // 2. Also search for any standalone /Type /EmbeddedFile streams not linked via Filespec
    for (final entry in objectContents.entries) {
      final objNum = entry.key;
      final content = entry.value;

      if (visitedStreamObjs.contains(objNum)) continue;
      if (!content.contains('/Type /EmbeddedFile') && !content.contains('/Type/EmbeddedFile')) {
        continue;
      }

      final streamData = _extractStreamBytes(rawPdfString, pdfBytes, objNum);
      if (streamData != null) {
        final name = 'embedded_stream_$objNum.bin';
        final hash = sha256.convert(streamData).toString();
        final risk = evaluateSecurityRisk(name);
        final mime = deriveMimeType(name);

        attachments.add(
          PdfAttachmentInfo(
            id: 'embedded_$objNum',
            name: name,
            description: 'Embedded raw file stream',
            size: streamData.length,
            mimeType: mime,
            modificationDate: DateTime.now(),
            sha256: hash,
            securityRisk: risk,
            data: streamData,
          ),
        );
      }
    }

    return attachments;
  }

  /// Extracts and decompresses the stream content for a given object number
  static Uint8List? _extractStreamBytes(String pdfString, Uint8List rawPdfBytes, int objNum) {
    try {
      final pattern = RegExp(
        '$objNum\\s+\\d+\\s+obj\\s*<<([\\s\\S]*?)>>\\s*stream[\\r\\n]+',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(pdfString);
      if (match == null) return null;

      final dict = match.group(1) ?? '';
      final isFlate = dict.contains('/FlateDecode');
      final streamStartIndex = match.end;

      // Find endstream
      final endstreamIndex = pdfString.indexOf('endstream', streamStartIndex);
      if (endstreamIndex == -1) return null;

      // Slice exact bytes from raw byte buffer
      int start = streamStartIndex;
      int end = endstreamIndex;

      // Clean up possible trailing \r or \n before endstream
      while (end > start && (rawPdfBytes[end - 1] == 10 || rawPdfBytes[end - 1] == 13)) {
        end--;
      }

      final streamSlice = rawPdfBytes.sublist(start, end);

      if (isFlate) {
        try {
          final decompressed = zlib.decode(streamSlice);
          return Uint8List.fromList(decompressed);
        } catch (_) {
          return streamSlice;
        }
      } else {
        return streamSlice;
      }
    } catch (_) {
      return null;
    }
  }

  static String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\n', '\n');
  }

  static String _decodeHexString(String hex) {
    try {
      final clean = hex.replaceAll(RegExp(r'\s+'), '');
      final bytes = <int>[];
      for (int i = 0; i < clean.length; i += 2) {
        if (i + 2 <= clean.length) {
          bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
        }
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return hex;
    }
  }

  /// Embeds new file attachments into an existing PDF document
  static Uint8List attachFilesToPdf(Uint8List originalPdfBytes, List<FileToAttach> filesToAttach) {
    if (filesToAttach.isEmpty) return originalPdfBytes;

    final pdfString = latin1.decode(originalPdfBytes);

    // Find highest existing object number
    final objRegex = RegExp(r'(\d+)\s+0\s+obj');
    int maxObjNum = 0;
    for (final match in objRegex.allMatches(pdfString)) {
      final n = int.tryParse(match.group(1) ?? '') ?? 0;
      if (n > maxObjNum) maxObjNum = n;
    }
    if (maxObjNum == 0) maxObjNum = 10;

    final buffer = BytesBuilder();
    buffer.add(originalPdfBytes);

    final List<int> filespecObjNumbers = [];
    final List<String> fileNames = [];

    int currentObjNum = maxObjNum + 1;

    for (final file in filesToAttach) {
      final streamObjNum = currentObjNum++;
      final filespecObjNum = currentObjNum++;
      filespecObjNumbers.add(filespecObjNum);
      fileNames.add(file.name);

      // Compress data using zlib / FlateDecode
      final compressedData = Uint8List.fromList(zlib.encode(file.data));
      final mime = file.mimeType ?? deriveMimeType(file.name);
      final escapedMime = mime.replaceAll('/', '#2F');
      final escapedName = file.name.replaceAll('(', r'\(').replaceAll(')', r'\)');
      final escapedDesc = file.description.replaceAll('(', r'\(').replaceAll(')', r'\)');

      final streamHeader = '''
\n$streamObjNum 0 obj
<<
  /Type /EmbeddedFile
  /Subtype /$escapedMime
  /Length ${compressedData.length}
  /Filter /FlateDecode
  /Params << /Size ${file.data.length} >>
>>
stream\n''';

      final streamFooter = '\nendstream\nendobj\n';

      final filespecObject = '''
$filespecObjNum 0 obj
<<
  /Type /Filespec
  /F ($escapedName)
  /UF ($escapedName)
  /EF << /F $streamObjNum 0 R >>
  /Desc ($escapedDesc)
>>
endobj
''';

      buffer.add(latin1.encode(streamHeader));
      buffer.add(compressedData);
      buffer.add(latin1.encode(streamFooter));
      buffer.add(latin1.encode(filespecObject));
    }

    // Build EmbeddedFiles Name Tree dictionary
    final namesTreeObjNum = currentObjNum++;
    final namesEntries = StringBuffer();
    for (int i = 0; i < filespecObjNumbers.length; i++) {
      final escaped = fileNames[i].replaceAll('(', r'\(').replaceAll(')', r'\)');
      namesEntries.write('($escaped) ${filespecObjNumbers[i]} 0 R ');
    }

    final namesTreeObj = '''
$namesTreeObjNum 0 obj
<<
  /Names [ $namesEntries]
>>
endobj
''';
    buffer.add(latin1.encode(namesTreeObj));

    // Append updated catalog or metadata reference
    final updatedCatalogObjNum = currentObjNum++;
    final updatedCatalog = '''
$updatedCatalogObjNum 0 obj
<<
  /Type /Catalog
  /Names << /EmbeddedFiles $namesTreeObjNum 0 R >>
>>
endobj
''';
    buffer.add(latin1.encode(updatedCatalog));

    // Write final incremental EOF
    final incrementalTrailer = '''
\ntrailer
<<
  /Root $updatedCatalogObjNum 0 R
>>
%%EOF\n''';
    buffer.add(latin1.encode(incrementalTrailer));

    return buffer.toBytes();
  }

  /// Strips all embedded files and attachments from PDF to ensure security compliance
  static Uint8List stripAttachments(Uint8List pdfBytes) {
    String content = latin1.decode(pdfBytes);

    // Nullify /EmbeddedFiles in Names dictionary
    content = content.replaceAll(
      RegExp(r'/EmbeddedFiles\s*<<[\s\S]*?>>', caseSensitive: false),
      '/EmbeddedFiles << /Names [] >>',
    );
    content = content.replaceAll(
      RegExp(r'/EmbeddedFiles\s+\d+\s+\d+\s+R', caseSensitive: false),
      '',
    );

    // Nullify /Filespec, /EmbeddedFile, and /FileAttachment objects
    content = content.replaceAllMapped(
      RegExp(r'(\d+\s+\d+\s+obj[\s\S]*?endobj)', caseSensitive: false),
      (match) {
        final block = match.group(1) ?? '';
        if (block.contains('/Type /Filespec') ||
            block.contains('/Type/Filespec') ||
            block.contains('/Type /EmbeddedFile') ||
            block.contains('/Type/EmbeddedFile') ||
            block.contains('/Subtype /FileAttachment')) {
          return '% stripped attachment object';
        }
        return block;
      },
    );

    return Uint8List.fromList(latin1.encode(content));
  }

  /// Generates CSV manifest string for attachments
  static String exportCsvManifest(List<PdfAttachmentInfo> attachments, {String? documentName}) {
    final buffer = StringBuffer();
    buffer.writeln('# PDFCraft Studio - Embedded Attachments & Portfolio Manifest');
    if (documentName != null) {
      buffer.writeln('# Document: $documentName');
    }
    buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Total Attachments: ${attachments.length}');
    buffer.writeln('Index,File Name,Size (Bytes),Human Size,MIME Type,Security Risk,SHA-256 Hash,Description');

    for (int i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      final desc = '"${a.description.replaceAll('"', '""')}"';
      final name = '"${a.name.replaceAll('"', '""')}"';
      buffer.writeln('${i + 1},$name,${a.size},${a.humanSize},${a.mimeType},${a.securityRisk.name},${a.sha256},$desc');
    }

    return buffer.toString();
  }

  /// Generates JSON manifest string for attachments
  static String exportJsonManifest(List<PdfAttachmentInfo> attachments, {String? documentName}) {
    final map = {
      'application': 'PDFCraft Studio',
      'documentName': documentName,
      'generatedAt': DateTime.now().toIso8601String(),
      'totalAttachments': attachments.length,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Extracts an individual attachment to the specified directory
  static Future<File> extractAttachment(PdfAttachmentInfo attachment, String targetDirectory) async {
    final dir = Directory(targetDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final targetPath = p.join(targetDirectory, attachment.name);
    final file = File(targetPath);
    await file.writeAsBytes(attachment.data);
    return file;
  }

  /// Batch extracts all attachments into the target directory
  static Future<List<File>> extractAllAttachments(List<PdfAttachmentInfo> attachments, String targetDirectory) async {
    final files = <File>[];
    for (final attachment in attachments) {
      final file = await extractAttachment(attachment, targetDirectory);
      files.add(file);
    }
    return files;
  }
}
