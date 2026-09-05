import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_page_label_service.dart';

class PageLabelScreen extends StatefulWidget {
  const PageLabelScreen({super.key});

  @override
  State<PageLabelScreen> createState() => _PageLabelScreenState();
}

class _PageLabelScreenState extends State<PageLabelScreen> {
  String? _pdfPath;
  Uint8List? _pdfBytes;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isDragging = false;

  List<PageLabelRange> _ranges = [
    const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.arabic, startNumber: 1),
  ];

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _loadPdf(result.files.single.path!);
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading document and analyzing existing page labels...';
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      int pageCount = 1;
      try {
        final doc = await PdfDocument.openData(bytes);
        pageCount = doc.pagesCount;
        await doc.close();
      } catch (_) {
        final match = RegExp(r'/Count\s+(\d+)').firstMatch(latin1.decode(bytes));
        if (match != null) {
          pageCount = int.tryParse(match.group(1) ?? '1') ?? 1;
        }
      }

      final existingRanges = PdfPageLabelService.parsePageLabels(bytes);

      setState(() {
        _pdfPath = path;
        _pdfBytes = bytes;
        _totalPages = pageCount;
        if (existingRanges.isNotEmpty) {
          _ranges = existingRanges;
        } else {
          _ranges = [
            const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.arabic, startNumber: 1),
          ];
        }
        _isLoading = false;
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _applyPreset(String preset) {
    if (_totalPages <= 0) return;

    setState(() {
      if (preset == 'book') {
        // Book: Roman lower for first 4 pages or 20% of doc, Arabic for rest
        final introLength = _totalPages > 6 ? 4 : 1;
        _ranges = [
          const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.romanLower, startNumber: 1),
          PageLabelRange(startPageIndex: introLength, style: PageNumberingStyle.arabic, startNumber: 1),
        ];
      } else if (preset == 'legal') {
        // Legal: Cover, Brief (Arabic), Appendix (AlphaUpper)
        if (_totalPages >= 6) {
          final appendixStart = _totalPages - 2;
          _ranges = [
            const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.none, prefix: 'Cover'),
            const PageLabelRange(startPageIndex: 1, style: PageNumberingStyle.arabic, startNumber: 1),
            PageLabelRange(startPageIndex: appendixStart, style: PageNumberingStyle.alphaUpper, prefix: 'App-', startNumber: 1),
          ];
        } else {
          _ranges = [
            const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.arabic, startNumber: 1),
          ];
        }
      } else if (preset == 'arabic') {
        _ranges = [
          const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.arabic, startNumber: 1),
        ];
      }
    });
  }

  void _addSection() {
    final nextPageIndex = _ranges.isEmpty ? 0 : (_ranges.last.startPageIndex + 2);
    final validIndex = nextPageIndex < _totalPages ? nextPageIndex : (_totalPages > 0 ? _totalPages - 1 : 0);

    setState(() {
      _ranges.add(
        PageLabelRange(
          startPageIndex: validIndex,
          style: PageNumberingStyle.arabic,
          startNumber: 1,
        ),
      );
      _ranges.sort((a, b) => a.startPageIndex.compareTo(b.startPageIndex));
    });
  }

  void _removeSection(int index) {
    if (_ranges.length <= 1) return;
    setState(() {
      _ranges.removeAt(index);
    });
  }

  Future<void> _savePdfWithLabels() async {
    if (_pdfBytes == null || _pdfPath == null) return;

    final defaultPath = '${p.withoutExtension(_pdfPath!)}_labeled.pdf';
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save PDF with Logical Page Labels',
      fileName: p.basename(defaultPath),
    );

    if (savePath == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Writing /PageLabels dictionary and updating PDF...';
    });

    try {
      final updatedBytes = PdfPageLabelService.applyPageLabels(_pdfBytes!, _ranges);
      final file = File(savePath);
      await file.writeAsBytes(updatedBytes);

      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved with page labels: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _resetToPhysical() async {
    if (_pdfBytes == null || _pdfPath == null) return;

    final defaultPath = '${p.withoutExtension(_pdfPath!)}_reset_labels.pdf';
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save PDF without Custom Page Labels',
      fileName: p.basename(defaultPath),
    );

    if (savePath == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Resetting page labels to physical sheet numbers...';
    });

    try {
      final resetBytes = PdfPageLabelService.resetPageLabels(_pdfBytes!);
      final file = File(savePath);
      await file.writeAsBytes(resetBytes);

      setState(() {
        _isLoading = false;
        _statusMessage = null;
        _ranges = [
          const PageLabelRange(startPageIndex: 0, style: PageNumberingStyle.arabic, startNumber: 1),
        ];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Labels reset: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset labels: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportSchedule(bool isCsv) async {
    if (_pdfPath == null || _totalPages <= 0) return;

    final docName = p.basename(_pdfPath!);
    final defaultFileName = '${p.basenameWithoutExtension(_pdfPath!)}_page_labels.${isCsv ? 'csv' : 'json'}';

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Export Page Labels Schedule',
      fileName: defaultFileName,
    );

    if (savePath == null) return;

    try {
      final content = isCsv
          ? PdfPageLabelService.exportLabelsMappingCsv(_totalPages, _ranges, documentName: docName)
          : PdfPageLabelService.exportLabelsMappingJson(_totalPages, _ranges, documentName: docName);

      final file = File(savePath);
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Page schedule saved: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Labels & Numbering Schemes'),
        actions: [
          if (_pdfPath != null) ...[
            OutlinedButton.icon(
              onPressed: () => _exportSchedule(true),
              icon: const Icon(PhosphorIconsLight.fileCsv, size: 16),
              label: const Text('Export CSV'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _resetToPhysical,
              icon: const Icon(PhosphorIconsLight.arrowCounterClockwise, size: 16),
              label: const Text('Reset Labels'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _savePdfWithLabels,
              icon: const Icon(PhosphorIconsLight.floppyDisk, size: 16),
              label: const Text('Save PDF with Labels'),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage ?? 'Processing...', style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                if (details.files.isNotEmpty) {
                  final path = details.files.first.path;
                  if (path.toLowerCase().endsWith('.pdf')) {
                    _loadPdf(path);
                  }
                }
              },
              child: Container(
                color: _isDragging ? theme.colorScheme.primary.withAlpha(25) : Colors.transparent,
                child: Column(
                  children: [
                    _buildTopHeader(theme),
                    const Divider(height: 1),
                    Expanded(
                      child: _pdfPath == null ? _buildEmptyState(theme) : _buildMainEditor(theme),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
      child: Row(
        children: [
          Icon(PhosphorIconsLight.listNumbers, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pdfPath != null ? p.basename(_pdfPath!) : 'No PDF selected',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _pdfPath != null
                      ? 'Total Sheets: $_totalPages • Sections configured: ${_ranges.length}'
                      : 'Configure /PageLabels dictionary for PDF readers (Acrobat, Edge, Chrome)',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(PhosphorIconsLight.folderOpen),
            label: const Text('Select PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsLight.listNumbers, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Select a PDF to Configure Logical Page Labels',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Set Roman numerals for front matter (i, ii), Arabic for chapters (1, 2), and prefixes for appendices.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(PhosphorIconsLight.plus),
            label: const Text('Select PDF Document'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainEditor(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Numbering Sections Config
        Expanded(
          flex: 6,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Presets Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsLight.magicWand, size: 20),
                      const SizedBox(width: 10),
                      const Text('Quick Presets:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 10),
                      ActionChip(
                        label: const Text('Book / Thesis (i..iv, 1..N)'),
                        onPressed: () => _applyPreset('book'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Legal Brief (Cover, 1..N, App-A)'),
                        onPressed: () => _applyPreset('legal'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Standard Arabic (1..N)'),
                        onPressed: () => _applyPreset('arabic'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Numbering Sections (${_ranges.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _addSection,
                    icon: const Icon(PhosphorIconsLight.plus, size: 16),
                    label: const Text('Add Section'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Section cards
              for (int i = 0; i < _ranges.length; i++) _buildSectionCard(i, theme),
            ],
          ),
        ),

        const VerticalDivider(width: 1),

        // Right Column: Live Sheet-to-Label Preview
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsLight.eye, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Live Page Labels Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      '$_totalPages Sheets',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _totalPages,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final label = PdfPageLabelService.getLabelForPage(index, _ranges);
                    final isSectionStart = _ranges.any((r) => r.startPageIndex == index);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: isSectionStart ? theme.colorScheme.primaryContainer.withAlpha(40) : Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            width: 65,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Sheet ${index + 1}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(PhosphorIconsLight.arrowRight, size: 14, color: Colors.grey),
                          const SizedBox(width: 16),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (isSectionStart) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Section Start',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(int index, ThemeData theme) {
    final range = _ranges[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Section ${index + 1} (From Sheet ${range.startPageIndex + 1})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                if (_ranges.length > 1)
                  IconButton(
                    icon: const Icon(PhosphorIconsLight.trash, size: 18, color: Colors.red),
                    onPressed: () => _removeSection(index),
                    tooltip: 'Remove section',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Start Sheet Index Field
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: '${range.startPageIndex + 1}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start at Sheet',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 1) {
                        setState(() {
                          _ranges[index] = range.copyWith(startPageIndex: parsed - 1);
                          _ranges.sort((a, b) => a.startPageIndex.compareTo(b.startPageIndex));
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Style Dropdown
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<PageNumberingStyle>(
                    initialValue: range.style,
                    decoration: const InputDecoration(
                      labelText: 'Style',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: PageNumberingStyle.arabic, child: Text('Arabic (1, 2, 3)')),
                      DropdownMenuItem(value: PageNumberingStyle.romanLower, child: Text('Roman Lower (i, ii, iii)')),
                      DropdownMenuItem(value: PageNumberingStyle.romanUpper, child: Text('Roman Upper (I, II, III)')),
                      DropdownMenuItem(value: PageNumberingStyle.alphaLower, child: Text('Alpha Lower (a, b, c)')),
                      DropdownMenuItem(value: PageNumberingStyle.alphaUpper, child: Text('Alpha Upper (A, B, C)')),
                      DropdownMenuItem(value: PageNumberingStyle.none, child: Text('Prefix Only (No Number)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _ranges[index] = range.copyWith(style: val);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Prefix Field
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: range.prefix,
                    decoration: const InputDecoration(
                      labelText: 'Prefix',
                      hintText: 'e.g. App-',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _ranges[index] = range.copyWith(prefix: val);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Start Number Field
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: '${range.startNumber}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start #',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 1) {
                        setState(() {
                          _ranges[index] = range.copyWith(startNumber: parsed);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
