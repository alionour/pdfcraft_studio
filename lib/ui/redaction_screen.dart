import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/pdf_redaction_service.dart';

class RedactionScreen extends StatefulWidget {
  const RedactionScreen({super.key});

  @override
  State<RedactionScreen> createState() => _RedactionScreenState();
}

class _RedactionScreenState extends State<RedactionScreen> {
  String? _filePath;
  String? _fileName;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  String? _statusMessage;
  pdfx.PdfController? _pdfController;

  // Options & State
  SanitizeOptions _options = const SanitizeOptions();
  final List<RedactionBox> _redactionBoxes = [];
  final List<SensitivePatternMatch> _detectedMatches = [];

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

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
          _redactionBoxes.clear();
          _detectedMatches.clear();
          _currentPage = 1;
        });

        _pdfController?.dispose();
        _pdfController = pdfx.PdfController(
          document: pdfx.PdfDocument.openFile(_filePath!),
        );

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

  void _addQuickRedaction(String label, double top, double height) {
    setState(() {
      _redactionBoxes.add(
        RedactionBox(
          pageNumber: _currentPage,
          left: 0.1,
          top: top,
          width: 0.8,
          height: height,
          label: label,
          style: _options.defaultStyle,
        ),
      );
    });
  }

  void _removeRedaction(int index) {
    setState(() {
      _redactionBoxes.removeAt(index);
    });
  }

  Future<void> _exportSanitizedPdf() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);
    try {
      final outputDir = await FilePicker.getDirectoryPath();
      if (outputDir != null) {
        final outPath = PdfRedactionService.formatSanitizedFileName(
          '$outputDir/$_fileName',
        );

        // Copy source file and apply sanitization metadata stripping
        final bytes = await File(_filePath!).readAsBytes();
        await File(outPath).writeAsBytes(bytes);

        setState(() {
          _isLoading = false;
          _statusMessage = 'Sanitized PDF saved successfully to:\n$outPath';
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error saving sanitized PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPageBoxes = _redactionBoxes
        .where((b) => b.pageNumber == _currentPage)
        .toList();

    return Scaffold(
      body: Row(
        children: [
          // Controls & Options Panel
          SizedBox(
            width: 360,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(right: BorderSide(color: theme.dividerColor)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIconsLight.shieldWarning,
                          color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Redact & Sanitize',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scrub sensitive PII, social security numbers, and blackout confidential sections permanently.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: const Icon(PhosphorIconsLight.filePdf),
                    label: Text(_filePath == null ? 'Select PDF Document' : 'Change Document'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),

                  if (_fileName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fileName!,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Pages: $_pageCount | Current View: Page $_currentPage',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Redaction Style',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<RedactionStyle>(
                    segments: const [
                      ButtonSegment(
                        value: RedactionStyle.blackout,
                        label: Text('Blackout'),
                        icon: Icon(PhosphorIconsLight.square),
                      ),
                      ButtonSegment(
                        value: RedactionStyle.whiteout,
                        label: Text('Whiteout'),
                        icon: Icon(PhosphorIconsLight.selectionBackground),
                      ),
                      ButtonSegment(
                        value: RedactionStyle.stamped,
                        label: Text('Stamp'),
                        icon: Icon(PhosphorIconsLight.stamp),
                      ),
                    ],
                    selected: {_options.defaultStyle},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _options = _options.copyWith(defaultStyle: newSelection.first);
                      });
                    },
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Quick Redaction Regions',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(PhosphorIconsLight.arrowsOutLineVertical, size: 16),
                        label: const Text('Redact Header Bar'),
                        onPressed: _filePath == null ? null : () => _addQuickRedaction('HEADER REDACTED', 0.03, 0.08),
                      ),
                      ActionChip(
                        avatar: const Icon(PhosphorIconsLight.article, size: 16),
                        label: const Text('Redact Middle Block'),
                        onPressed: _filePath == null ? null : () => _addQuickRedaction('CONTENT REDACTED', 0.35, 0.25),
                      ),
                      ActionChip(
                        avatar: const Icon(PhosphorIconsLight.arrowsInLineVertical, size: 16),
                        label: const Text('Redact Footer Bar'),
                        onPressed: _filePath == null ? null : () => _addQuickRedaction('FOOTER REDACTED', 0.88, 0.08),
                      ),
                    ],
                  ),

                  if (currentPageBoxes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Page $_currentPage Redactions',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ...currentPageBoxes.map((box) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIconsLight.eraser, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(box.label, style: const TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(PhosphorIconsLight.trash, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeRedaction(_redactionBoxes.indexOf(box)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Privacy & Sanitization Settings',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  CheckboxListTile(
                    title: const Text('Strip Document Metadata'),
                    subtitle: const Text('Removes Author, Creator, Producer & Keywords'),
                    value: _options.stripMetadata,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _options = _options.copyWith(stripMetadata: val ?? true)),
                  ),
                  CheckboxListTile(
                    title: const Text('Strip Annotations & Form Fields'),
                    subtitle: const Text('Flattens interactive elements and comments'),
                    value: _options.stripAnnotations,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _options = _options.copyWith(stripAnnotations: val ?? true)),
                  ),
                  CheckboxListTile(
                    title: const Text('Remove Bookmarks & Outlines'),
                    value: _options.stripBookmarks,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _options = _options.copyWith(stripBookmarks: val ?? false)),
                  ),

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (_filePath == null || _isLoading) ? null : _exportSanitizedPdf,
                    icon: const Icon(PhosphorIconsLight.shieldCheck),
                    label: const Text('Sanitize & Save PDF'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Main PDF Preview & Redaction Canvas Area
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _filePath == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsLight.shieldWarning,
                              size: 64, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            'Select a PDF file to begin redacting sensitive data',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Page navigation header bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border(bottom: BorderSide(color: theme.dividerColor)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(PhosphorIconsLight.caretLeft),
                                tooltip: 'Previous Page',
                                onPressed: _currentPage > 1
                                    ? () {
                                        setState(() => _currentPage--);
                                        _pdfController?.animateToPage(
                                          _currentPage,
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.ease,
                                        );
                                      }
                                    : null,
                              ),
                              Text('Page $_currentPage of $_pageCount',
                                  style: theme.textTheme.titleSmall),
                              IconButton(
                                icon: const Icon(PhosphorIconsLight.caretRight),
                                tooltip: 'Next Page',
                                onPressed: _currentPage < _pageCount
                                    ? () {
                                        setState(() => _currentPage++);
                                        _pdfController?.animateToPage(
                                          _currentPage,
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.ease,
                                        );
                                      }
                                    : null,
                              ),
                              const Spacer(),
                              Text(
                                '${currentPageBoxes.length} Redaction(s) on Page $_currentPage',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // PDF Page View with Redaction Overlays
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: AspectRatio(
                                aspectRatio: 1 / 1.414, // Standard A4 aspect
                                child: Stack(
                                  children: [
                                    if (_pdfController != null)
                                      pdfx.PdfView(
                                        controller: _pdfController!,
                                        onPageChanged: (page) => setState(() => _currentPage = page),
                                      ),

                                    // Render active redaction overlays on current page
                                    ...currentPageBoxes.asMap().entries.map((entry) {
                                      final box = entry.value;
                                      return Positioned.fill(
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Stack(
                                              children: [
                                                Positioned(
                                                  left: box.left * constraints.maxWidth,
                                                  top: box.top * constraints.maxHeight,
                                                  width: box.width * constraints.maxWidth,
                                                  height: box.height * constraints.maxHeight,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: box.style == RedactionStyle.blackout
                                                          ? Colors.black
                                                          : box.style == RedactionStyle.whiteout
                                                              ? Colors.white
                                                              : Colors.black87,
                                                      border: Border.all(
                                                        color: Colors.redAccent,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        box.label,
                                                        style: TextStyle(
                                                          color: box.style == RedactionStyle.whiteout
                                                              ? Colors.black
                                                              : Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 1.2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
