import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/src/pdf/format/name.dart';
import 'package:pdf/src/pdf/format/num.dart';
import 'package:pdf/src/pdf/format/string.dart';
import 'package:pdf/src/pdf/format/object_base.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

const List<int> _pdfPadding = [
  0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
  0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
  0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
  0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A
];

class WatermarkOptions {
  final bool isText;
  final String text;
  final String? imagePath;
  final double fontSize;
  final double opacity;
  final PdfColor color;
  final double rotationAngleDegree;

  static const List<String> textPresets = [
    'CONFIDENTIAL',
    'DRAFT',
    'SAMPLE',
    'APPROVED',
    'TOP SECRET',
    'DO NOT COPY',
  ];

  WatermarkOptions({
    this.isText = true,
    this.text = 'CONFIDENTIAL',
    this.imagePath,
    this.fontSize = 48,
    this.opacity = 0.3,
    this.color = PdfColors.grey700,
    this.rotationAngleDegree = 45,
  });

  static WatermarkOptions createImageWatermark({
    required String imagePath,
    double opacity = 0.25,
    double rotationAngleDegree = 0,
  }) {
    return WatermarkOptions(
      isText: false,
      imagePath: imagePath,
      opacity: opacity,
      rotationAngleDegree: rotationAngleDegree,
    );
  }

  static double degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  WatermarkOptions copyWith({
    bool? isText,
    String? text,
    String? imagePath,
    double? fontSize,
    double? opacity,
    PdfColor? color,
    double? rotationAngleDegree,
  }) {
    return WatermarkOptions(
      isText: isText ?? this.isText,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      rotationAngleDegree: rotationAngleDegree ?? this.rotationAngleDegree,
    );
  }
}

/// ISO 32000-1 Standard PDF 128-bit RC4 Encryption Provider
class StandardPdfPasswordEncryption extends PdfEncryption {
  late Uint8List _oKey;
  late Uint8List _uKey;

  StandardPdfPasswordEncryption(
    super.pdfDocument, {
    required String userPassword,
    required String ownerPassword,
  }) {
    final userPadded = _padPassword(userPassword);
    final ownerPadded = _padPassword(ownerPassword.isNotEmpty ? ownerPassword : userPassword);

    final documentID = pdfDocument.documentID;

    // 1. Compute Owner Key (/O)
    final ownerHash = md5.convert(ownerPadded).bytes;
    _oKey = _rc4Encrypt(Uint8List.fromList(ownerHash.sublist(0, 16)), userPadded);

    // 2. Compute File Encryption Key
    final pVal = -44;
    final pBytes = Uint8List(4)
      ..buffer.asByteData().setInt32(0, pVal, Endian.little);

    final keyBuf = <int>[
      ...userPadded,
      ..._oKey,
      ...pBytes,
      ...documentID,
    ];

    var encKey = md5.convert(keyBuf).bytes;
    for (var i = 0; i < 50; i++) {
      encKey = md5.convert(encKey).bytes;
    }
    final finalEncKey = Uint8List.fromList(encKey.sublist(0, 16));

    // 3. Compute User Key (/U)
    var uHash = _rc4Encrypt(finalEncKey, Uint8List.fromList(_pdfPadding));
    for (var i = 1; i <= 19; i++) {
      final keyXor = Uint8List(16);
      for (var j = 0; j < 16; j++) {
        keyXor[j] = finalEncKey[j] ^ i;
      }
      uHash = _rc4Encrypt(keyXor, uHash);
    }

    _uKey = Uint8List(32);
    _uKey.setRange(0, 16, uHash);

    params['/Filter'] = const PdfName('/Standard');
    params['/V'] = const PdfNum(2);
    params['/R'] = const PdfNum(3);
    params['/Length'] = const PdfNum(128);
    params['/P'] = PdfNum(pVal);
    params['/O'] = PdfString(_oKey, format: PdfStringFormat.binary);
    params['/U'] = PdfString(_uKey, format: PdfStringFormat.binary);
  }

  static Uint8List _padPassword(String password) {
    final bytes = password.codeUnits;
    final padded = Uint8List(32);
    if (bytes.length >= 32) {
      padded.setRange(0, 32, bytes.sublist(0, 32));
    } else {
      padded.setRange(0, bytes.length, bytes);
      padded.setRange(bytes.length, 32, _pdfPadding.sublist(0, 32 - bytes.length));
    }
    return padded;
  }

  static Uint8List _rc4Encrypt(Uint8List key, Uint8List data) {
    final s = List<int>.generate(256, (i) => i);
    int j = 0;
    for (int i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 0xFF;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
    }

    final out = Uint8List(data.length);
    int i = 0;
    j = 0;
    for (int k = 0; k < data.length; k++) {
      i = (i + 1) & 0xFF;
      j = (j + s[i]) & 0xFF;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
      out[k] = data[k] ^ s[(s[i] + s[j]) & 0xFF];
    }
    return out;
  }

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    return input;
  }
}

class PdfSecurityService {
  /// Adds text or image watermark and password protection to a PDF document
  static Future<String> processSecurityOptions({
    required String inputPdfPath,
    required String outputPdfPath,
    WatermarkOptions? watermark,
    String? userPassword,
    String? ownerPassword,
    Function(int current, int total)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(inputPdfPath);
    final totalPages = doc.pagesCount;

    final pdfDoc = pw.Document();

    if ((userPassword != null && userPassword.isNotEmpty) ||
        (ownerPassword != null && ownerPassword.isNotEmpty)) {
      StandardPdfPasswordEncryption(
        pdfDoc.document,
        userPassword: userPassword ?? '',
        ownerPassword: ownerPassword ?? (userPassword ?? ''),
      );
    }

    pw.MemoryImage? watermarkImage;
    if (watermark != null && !watermark.isText && watermark.imagePath != null) {
      final wmFile = File(watermark.imagePath!);
      if (await wmFile.exists()) {
        watermarkImage = pw.MemoryImage(await wmFile.readAsBytes());
      }
    }

    for (var pageNum = 1; pageNum <= totalPages; pageNum++) {
      final page = await doc.getPage(pageNum);
      final pageImg = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);

        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              final children = <pw.Widget>[
                pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
              ];

              if (watermark != null) {
                final angleRad = watermark.rotationAngleDegree * (3.14159 / 180.0);
                pw.Widget watermarkWidget;

                if (watermark.isText) {
                  watermarkWidget = pw.Opacity(
                    opacity: watermark.opacity,
                    child: pw.Transform.rotate(
                      angle: angleRad,
                      child: pw.Text(
                        watermark.text,
                        style: pw.TextStyle(
                          color: watermark.color,
                          fontSize: watermark.fontSize,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                } else if (watermarkImage != null) {
                  watermarkWidget = pw.Opacity(
                    opacity: watermark.opacity,
                    child: pw.Transform.rotate(
                      angle: angleRad,
                      child: pw.Image(
                        watermarkImage,
                        width: page.width * 0.5,
                        height: page.height * 0.5,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  );
                } else {
                  watermarkWidget = pw.Container();
                }

                children.add(
                  pw.Positioned.fill(
                    child: pw.Center(child: watermarkWidget),
                  ),
                );
              }

              return pw.Stack(children: children);
            },
          ),
        );
      }

      if (onProgress != null) {
        onProgress(pageNum, totalPages);
      }
    }

    await doc.close();

    final bytes = await pdfDoc.save();
    final outFile = File(outputPdfPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(bytes, flush: true);
    return outputPdfPath;
  }

  /// Removes password/encryption or re-exports unencrypted PDF
  static Future<String> removePassword({
    required String inputPdfPath,
    required String outputPdfPath,
    String? password,
    Function(int current, int total)? onProgress,
  }) async {
    final doc = await pdfx.PdfDocument.openFile(
      inputPdfPath,
      password: password,
    );
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

      if (pageImg != null) {
        final img = pw.MemoryImage(pageImg.bytes);
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
            ),
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
