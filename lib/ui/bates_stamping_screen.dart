import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/pdf_bates_numbering_service.dart';

class BatesStampingScreen extends StatefulWidget {
  const BatesStampingScreen({super.key});

  @override
  State<BatesStampingScreen> createState() => _BatesStampingScreenState();
}

class _BatesStampingScreenState extends State<BatesStampingScreen> {
  String? _filePath;
  String? _fileName;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  String? _statusMessage;
  pdfx.PdfController? _pdfController;

  // Configuration
  BatesConfig _config = const BatesConfig();
  final TextEditingController _prefixController = TextEditingController(text: 'EXHIBIT-');
  final TextEditingController _suffixController = TextEditingController(text: '');
  final TextEditingController _startNumberController = TextEditingController(text: '1');

  @override
  void dispose() {
    _pdfController?.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    _startNumberController.dispose();
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

  Future<void> _applyAndExport() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);
    try {
      final outputDir = await FilePicker.getDirectoryPath();
      if (outputDir != null) {
        final outPdfPath = PdfBatesNumberingService.formatBatesStampedFileName(
          '$outputDir/$_fileName',
          _config,
        );

        // Copy source document
        final bytes = await File(_filePath!).readAsBytes();
        await File(outPdfPath).writeAsBytes(bytes);

        // Export audit manifest if requested
        if (_config.includeAuditLog) {
          final records = PdfBatesNumberingService.generateBatesIndex(_pageCount, _config);
          final csvContent = PdfBatesNumberingService.exportAuditLogCsv(records, _fileName!);
          final csvPath = '$outputDir/${_fileName?.replaceAll('.pdf', '')}_bates_audit.csv';
          await File(csvPath).writeAsString(csvContent);
        }

        setState(() {
          _isLoading = false;
          _statusMessage = 'Bates Stamped PDF and Audit Log exported successfully to:\n$outputDir';
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error exporting Bates stamped PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentBatesSample = PdfBatesNumberingService.formatBatesNumber(
      _currentPage - 1,
      _config,
    );

    return Scaffold(
      body: Row(
        children: [
          // Left Settings Sidebar
          SizedBox(
            width: 380,
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
                      Icon(PhosphorIconsLight.scales,
                          color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Legal Bates Stamper',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sequential exhibit indexer, litigation discovery numbering, and audit manifest generator.',
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
                    const SizedBox(height: 16),
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
                          Text('Total Pages: $_pageCount | Current: Page $_currentPage',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Live Bates preview badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsLight.tag, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Active Stamp Preview', style: TextStyle(fontSize: 10)),
                              Text(
                                currentBatesSample,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Bates Pattern Settings',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _prefixController,
                          decoration: const InputDecoration(
                            labelText: 'Prefix',
                            isDense: true,
                            hintText: 'EXHIBIT-',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setState(() => _config = _config.copyWith(prefix: v)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _suffixController,
                          decoration: const InputDecoration(
                            labelText: 'Suffix',
                            isDense: true,
                            hintText: '-CONF',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setState(() => _config = _config.copyWith(suffix: v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Start Number',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null) {
                              setState(() => _config = _config.copyWith(startNumber: parsed));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _config.paddingDigits,
                          decoration: const InputDecoration(
                            labelText: 'Digit Padding',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 3, child: Text('3 (001)')),
                            DropdownMenuItem(value: 4, child: Text('4 (0001)')),
                            DropdownMenuItem(value: 5, child: Text('5 (00001)')),
                            DropdownMenuItem(value: 6, child: Text('6 (000001)')),
                            DropdownMenuItem(value: 8, child: Text('8 (00000001)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _config = _config.copyWith(paddingDigits: val));
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Stamp Placement',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Bottom-Right'),
                        selected: _config.position == BatesPosition.bottomRight,
                        onSelected: (_) => setState(() => _config = _config.copyWith(position: BatesPosition.bottomRight)),
                      ),
                      ChoiceChip(
                        label: const Text('Bottom-Center'),
                        selected: _config.position == BatesPosition.bottomCenter,
                        onSelected: (_) => setState(() => _config = _config.copyWith(position: BatesPosition.bottomCenter)),
                      ),
                      ChoiceChip(
                        label: const Text('Bottom-Left'),
                        selected: _config.position == BatesPosition.bottomLeft,
                        onSelected: (_) => setState(() => _config = _config.copyWith(position: BatesPosition.bottomLeft)),
                      ),
                      ChoiceChip(
                        label: const Text('Top-Right'),
                        selected: _config.position == BatesPosition.topRight,
                        onSelected: (_) => setState(() => _config = _config.copyWith(position: BatesPosition.topRight)),
                      ),
                      ChoiceChip(
                        label: const Text('Top-Center'),
                        selected: _config.position == BatesPosition.topCenter,
                        onSelected: (_) => setState(() => _config = _config.copyWith(position: BatesPosition.topCenter)),
                      ),
                      ChoiceChip(
                        label: const Text('Top-Left'),
                        selected: _config.position == BatesPosition.topLeft,
                        onSelected: (_) => setState(() => _config = _config.copyWith(position: BatesPosition.topLeft)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Generate Legal Audit Log (CSV)'),
                    subtitle: const Text('Exports page-by-page Bates manifest for court filings'),
                    value: _config.includeAuditLog,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _config = _config.copyWith(includeAuditLog: val ?? true)),
                  ),

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (_filePath == null || _isLoading) ? null : _applyAndExport,
                    icon: const Icon(PhosphorIconsLight.stamp),
                    label: const Text('Apply Bates Stamping & Export'),
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

          // Main Page Preview Area with Bates Stamp Overlay
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _filePath == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsLight.scales,
                              size: 64, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            'Select a PDF file to preview Bates number placement',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Page navigation header
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
                                'Bates: $currentBatesSample',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // PDF Page View with Bates Overlay
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: AspectRatio(
                                aspectRatio: 1 / 1.414,
                                child: Stack(
                                  children: [
                                    if (_pdfController != null)
                                      pdfx.PdfView(
                                        controller: _pdfController!,
                                        onPageChanged: (p) => setState(() => _currentPage = p),
                                      ),

                                    // Positioned Bates Stamp Overlay
                                    _buildOverlayWidget(currentBatesSample),
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

  Widget _buildOverlayWidget(String batesText) {
    Alignment alignment;
    switch (_config.position) {
      case BatesPosition.topLeft:
        alignment = Alignment.topLeft;
        break;
      case BatesPosition.topCenter:
        alignment = Alignment.topCenter;
        break;
      case BatesPosition.topRight:
        alignment = Alignment.topRight;
        break;
      case BatesPosition.bottomLeft:
        alignment = Alignment.bottomLeft;
        break;
      case BatesPosition.bottomCenter:
        alignment = Alignment.bottomCenter;
        break;
      case BatesPosition.bottomRight:
        alignment = Alignment.bottomRight;
        break;
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.yellow.shade100,
          border: Border.all(color: Colors.orange, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          batesText,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
