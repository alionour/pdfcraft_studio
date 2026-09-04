import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/pdf_booklet_imposition_service.dart';

class BookletImpositionScreen extends StatefulWidget {
  const BookletImpositionScreen({super.key});

  @override
  State<BookletImpositionScreen> createState() => _BookletImpositionScreenState();
}

class _BookletImpositionScreenState extends State<BookletImpositionScreen> {
  String? _filePath;
  String? _fileName;
  int _pageCount = 0;
  bool _isLoading = false;
  BookletBindingType _bindingType = BookletBindingType.saddleStitch;
  String? _statusMessage;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _filePath = result.files.single.path;
          _fileName = result.files.single.name;
          _statusMessage = null;
        });

        final doc = await pdfx.PdfDocument.openFile(_filePath!);
        final count = doc.pagesCount;
        await doc.close();

        setState(() {
          _pageCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error opening PDF: $e';
      });
    }
  }

  Future<void> _exportImpositionPlan() async {
    if (_filePath == null || _pageCount == 0) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await PdfBookletImpositionService.generateBookletSummaryPdf(
        documentTitle: _fileName ?? 'Document',
        totalOriginalPages: _pageCount,
        bindingType: _bindingType,
      );

      final outputDir = await FilePicker.getDirectoryPath();
      if (outputDir != null) {
        final outPath = '$outputDir/${_fileName?.replaceAll('.pdf', '')}_booklet_plan.pdf';
        await File(outPath).writeAsBytes(bytes);

        setState(() {
          _isLoading = false;
          _statusMessage = 'Booklet plan saved successfully to:\n$outPath';
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Export failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saddleSheets = _pageCount > 0 && _bindingType == BookletBindingType.saddleStitch
        ? PdfBookletImpositionService.computeSaddleStitchLayout(_pageCount)
        : null;

    final nUpSheets = _pageCount > 0 && _bindingType != BookletBindingType.saddleStitch
        ? (_bindingType == BookletBindingType.twoUpSideBySide
            ? PdfBookletImpositionService.computeTwoUpLayout(_pageCount)
            : PdfBookletImpositionService.computeFourUpLayout(_pageCount))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booklet & Signature Imposition'),
        actions: [
          if (_filePath != null)
            IconButton(
              icon: const Icon(PhosphorIconsLight.downloadSimple),
              tooltip: 'Export Printable Booklet Plan',
              onPressed: _isLoading ? null : _exportImpositionPlan,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName ?? 'No PDF loaded',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _pageCount > 0
                                ? 'Total Pages: $_pageCount | Target Sheets: ${(saddleSheets?.length ?? nUpSheets?.length ?? 0)}'
                                : 'Select a PDF document to arrange printing signatures or 2-up/4-up sheet imposition.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _pickFile,
                      icon: const Icon(PhosphorIconsLight.filePdf),
                      label: Text(_filePath == null ? 'Select PDF' : 'Change PDF'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_pageCount > 0) ...[
              Text('Imposition Binding Format:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<BookletBindingType>(
                segments: const [
                  ButtonSegment(
                    value: BookletBindingType.saddleStitch,
                    label: Text('Saddle-Stitch Booklet (Folded)'),
                    icon: Icon(PhosphorIconsLight.bookBookmark),
                  ),
                  ButtonSegment(
                    value: BookletBindingType.twoUpSideBySide,
                    label: Text('2-Up Side-by-Side'),
                    icon: Icon(PhosphorIconsLight.columns),
                  ),
                  ButtonSegment(
                    value: BookletBindingType.fourUpGrid,
                    label: Text('4-Up Grid (2x2)'),
                    icon: Icon(PhosphorIconsLight.squaresFour),
                  ),
                ],
                selected: {_bindingType},
                onSelectionChanged: (set) => setState(() => _bindingType = set.first),
              ),
              const SizedBox(height: 16),
            ],
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIconsLight.info, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMessage!)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (saddleSheets != null) ...[
              Text(
                'Calculated Print Signatures (${saddleSheets.length} Physical Sheets):',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: saddleSheets.length,
                  itemBuilder: (context, index) {
                    final sheet = saddleSheets[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('${sheet.sheetIndex}'),
                        ),
                        title: Text('Sheet ${sheet.sheetIndex}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Front Side: [ Page ${sheet.frontSide[0].isBlank ? 'Blank' : sheet.frontSide[0].pageNumber} | Page ${sheet.frontSide[1].isBlank ? 'Blank' : sheet.frontSide[1].pageNumber} ]',
                            ),
                            Text(
                              'Back Side:  [ Page ${sheet.backSide[0].isBlank ? 'Blank' : sheet.backSide[0].pageNumber} | Page ${sheet.backSide[1].isBlank ? 'Blank' : sheet.backSide[1].pageNumber} ]',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (nUpSheets != null) ...[
              Text(
                'Calculated Sheet Layout (${nUpSheets.length} Sheets):',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: nUpSheets.length,
                  itemBuilder: (context, index) {
                    final sheet = nUpSheets[index];
                    final slotsStr = sheet.map((s) => s.isBlank ? 'Blank' : 'Page ${s.pageNumber}').join('  |  ');
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text('Sheet ${index + 1}'),
                        subtitle: Text('Layout: [ $slotsStr ]'),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsLight.bookOpen, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('Load a document to preview and generate booklet imposition signatures.'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
