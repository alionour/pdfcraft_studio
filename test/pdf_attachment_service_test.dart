import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_app/services/pdf_attachment_service.dart';

void main() {
  group('PdfAttachmentService - Security Risk & MIME', () {
    test('evaluateSecurityRisk correctly categorizes safe, caution, and danger files', () {
      expect(PdfAttachmentService.evaluateSecurityRisk('report.pdf'), AttachmentSecurityRisk.safe);
      expect(PdfAttachmentService.evaluateSecurityRisk('data.xml'), AttachmentSecurityRisk.safe);
      expect(PdfAttachmentService.evaluateSecurityRisk('image.PNG'), AttachmentSecurityRisk.safe);
      expect(PdfAttachmentService.evaluateSecurityRisk('table.csv'), AttachmentSecurityRisk.safe);

      expect(PdfAttachmentService.evaluateSecurityRisk('archive.zip'), AttachmentSecurityRisk.caution);
      expect(PdfAttachmentService.evaluateSecurityRisk('macro_sheet.xlsm'), AttachmentSecurityRisk.caution);

      expect(PdfAttachmentService.evaluateSecurityRisk('malware.exe'), AttachmentSecurityRisk.danger);
      expect(PdfAttachmentService.evaluateSecurityRisk('payload.ps1'), AttachmentSecurityRisk.danger);
      expect(PdfAttachmentService.evaluateSecurityRisk('script.bat'), AttachmentSecurityRisk.danger);
      expect(PdfAttachmentService.evaluateSecurityRisk('virus.vbs'), AttachmentSecurityRisk.danger);
    });

    test('deriveMimeType resolves proper MIME strings', () {
      expect(PdfAttachmentService.deriveMimeType('doc.xml'), 'application/xml');
      expect(PdfAttachmentService.deriveMimeType('doc.json'), 'application/json');
      expect(PdfAttachmentService.deriveMimeType('data.csv'), 'text/csv');
      expect(PdfAttachmentService.deriveMimeType('note.txt'), 'text/plain');
      expect(PdfAttachmentService.deriveMimeType('doc.pdf'), 'application/pdf');
      expect(PdfAttachmentService.deriveMimeType('img.png'), 'image/png');
      expect(PdfAttachmentService.deriveMimeType('custom.xyz'), 'application/octet-stream');
    });

    test('PdfAttachmentInfo humanSize formatting and toJson', () {
      final data = Uint8List.fromList(utf8.encode('Hello World'));
      final info = PdfAttachmentInfo(
        id: 'test_1',
        name: 'test.txt',
        description: 'A test note',
        size: 512,
        mimeType: 'text/plain',
        modificationDate: DateTime(2026, 9, 5),
        sha256: sha256.convert(data).toString(),
        securityRisk: AttachmentSecurityRisk.safe,
        data: data,
      );

      expect(info.humanSize, '512 B');
      expect(info.toJson()['name'], 'test.txt');
      expect(info.toJson()['securityRisk'], 'safe');
      expect(info.toJson()['humanSize'], '512 B');
    });
  });

  group('PdfAttachmentService - Embed, Inspect, & Extract Round-Trip', () {
    late Uint8List dummyPdfBytes;

    setUp(() {
      // Minimal valid PDF structure
      final pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
endobj
xref
0 4
0000000000 65535 f 
0000000010 00000 n 
0000000060 00000 n 
0000000115 00000 n 
trailer
<< /Size 4 /Root 1 0 R >>
startxref
185
%%EOF
''';
      dummyPdfBytes = Uint8List.fromList(latin1.encode(pdfContent));
    });

    test('inspectAttachments returns empty list for PDF without attachments', () {
      final attachments = PdfAttachmentService.inspectAttachments(dummyPdfBytes);
      expect(attachments, isEmpty);
    });

    test('attachFilesToPdf embeds files and inspectAttachments discovers them', () {
      final file1Data = Uint8List.fromList(utf8.encode('{"customer": "Alice", "amount": 1500}'));
      final file2Data = Uint8List.fromList(utf8.encode('InvoiceNumber,Tax,Total\nINV-001,15,115'));

      final filesToAttach = [
        FileToAttach(
          name: 'invoice_payload.json',
          description: 'Electronic billing metadata',
          data: file1Data,
          mimeType: 'application/json',
        ),
        FileToAttach(
          name: 'summary.csv',
          description: 'Tax and breakdown details',
          data: file2Data,
          mimeType: 'text/csv',
        ),
      ];

      final updatedPdf = PdfAttachmentService.attachFilesToPdf(dummyPdfBytes, filesToAttach);
      expect(updatedPdf.length, greaterThan(dummyPdfBytes.length));

      // Inspect updated PDF
      final discovered = PdfAttachmentService.inspectAttachments(updatedPdf);
      expect(discovered.length, 2);

      final jsonAttachment = discovered.firstWhere((a) => a.name == 'invoice_payload.json');
      expect(jsonAttachment.description, 'Electronic billing metadata');
      expect(utf8.decode(jsonAttachment.data), '{"customer": "Alice", "amount": 1500}');
      expect(jsonAttachment.securityRisk, AttachmentSecurityRisk.safe);
      expect(jsonAttachment.sha256, sha256.convert(file1Data).toString());

      final csvAttachment = discovered.firstWhere((a) => a.name == 'summary.csv');
      expect(csvAttachment.description, 'Tax and breakdown details');
      expect(utf8.decode(csvAttachment.data), 'InvoiceNumber,Tax,Total\nINV-001,15,115');
    });

    test('stripAttachments removes attachments from embedded PDF', () {
      final testData = Uint8List.fromList(utf8.encode('Secret Spreadsheet Data'));
      final filesToAttach = [
        FileToAttach(
          name: 'internal_calc.xlsx',
          description: 'Confidential corporate formulas',
          data: testData,
        ),
      ];

      final embeddedPdf = PdfAttachmentService.attachFilesToPdf(dummyPdfBytes, filesToAttach);
      expect(PdfAttachmentService.inspectAttachments(embeddedPdf).length, 1);

      final strippedPdf = PdfAttachmentService.stripAttachments(embeddedPdf);
      final remaining = PdfAttachmentService.inspectAttachments(strippedPdf);
      expect(remaining, isEmpty);
    });

    test('exportCsvManifest and exportJsonManifest format output correctly', () {
      final data = Uint8List.fromList(utf8.encode('Report content'));
      final attachments = [
        PdfAttachmentInfo(
          id: 'filespec_1',
          name: 'evidence.pdf',
          description: 'Legal exhibit "A"',
          size: data.length,
          mimeType: 'application/pdf',
          modificationDate: DateTime(2026, 9, 5),
          sha256: sha256.convert(data).toString(),
          securityRisk: AttachmentSecurityRisk.safe,
          data: data,
        ),
      ];

      final csv = PdfAttachmentService.exportCsvManifest(attachments, documentName: 'contract.pdf');
      expect(csv, contains('evidence.pdf'));
      expect(csv, contains('application/pdf'));
      expect(csv, contains('contract.pdf'));

      final json = PdfAttachmentService.exportJsonManifest(attachments, documentName: 'contract.pdf');
      expect(json, contains('"documentName": "contract.pdf"'));
      expect(json, contains('"totalAttachments": 1'));
    });

    test('extractAttachment and extractAllAttachments write files to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('pdf_attach_test_');
      try {
        final data = Uint8List.fromList(utf8.encode('Disk extraction test'));
        final attachment = PdfAttachmentInfo(
          id: 'test_ext',
          name: 'extracted_note.txt',
          description: 'Note on disk',
          size: data.length,
          mimeType: 'text/plain',
          sha256: sha256.convert(data).toString(),
          securityRisk: AttachmentSecurityRisk.safe,
          data: data,
        );

        final file = await PdfAttachmentService.extractAttachment(attachment, tempDir.path);
        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), 'Disk extraction test');

        final all = await PdfAttachmentService.extractAllAttachments([attachment], tempDir.path);
        expect(all.length, 1);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
