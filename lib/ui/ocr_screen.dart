import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_ocr_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  String? _selectedPdfPath;
  OcrResult? _ocrResult;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _ocrResult = null;
        _statusMessage = '';
        _isSuccess = false;
      });
    }
  }

  Future<void> _runTextExtraction() async {
    if (_selectedPdfPath == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Extracting document text content...';
      _isSuccess = false;
    });

    try {
      final res = await PdfOcrService.extractText(
        pdfPath: _selectedPdfPath!,
        onProgress: (cur, tot) {
          setState(() {
            _progress = cur / tot;
            _statusMessage = 'Extracting text from page $cur of $tot...';
          });
        },
      );

      setState(() {
        _ocrResult = res;
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = 'Extraction complete! ${res.pageTexts.length} pages of text extracted.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = 'Text extraction failed: $e';
      });
    }
  }

  Future<void> _exportAsText(String ext) async {
    if (_ocrResult == null) return;

    final output = await FilePicker.saveFile(
      dialogTitle: 'Save Extracted Text',
      fileName: 'extracted_${p.basenameWithoutExtension(_selectedPdfPath!)}.$ext',
      type: FileType.custom,
      allowedExtensions: [ext],
    );

    if (output != null) {
      await PdfOcrService.exportTextToFile(
        textContent: _ocrResult!.combinedText,
        outputFilePath: output,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $output')),
      );
    }
  }

  Future<void> _exportSearchablePdf() async {
    if (_selectedPdfPath == null || _ocrResult == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Searchable PDF',
      fileName: 'searchable_${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) {
        output = '$output.pdf';
      }
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Building searchable PDF with embedded text layer...';
        _isSuccess = false;
      });

      try {
        await PdfOcrService.createSearchablePdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          pageTexts: _ocrResult!.pageTexts,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Embedding text into page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Searchable PDF created: $output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Failed to create searchable PDF: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('OCR & Text Extraction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress + Status Banner
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? PhosphorIconsLight.checkCircle : PhosphorIconsLight.info,
                        color: _isSuccess
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isSuccess
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Source Document Card
            DashboardCard(
              icon: PhosphorIconsLight.filePdf,
              iconColor: theme.colorScheme.error,
              title: 'Source Document',
              trailing: FilledButton.icon(
                onPressed: _selectedPdfPath != null && !_isProcessing
                    ? _runTextExtraction
                    : null,
                icon: const Icon(PhosphorIconsLight.textAa, size: 16),
                label: const Text('Extract Text'),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPdfFile,
                    icon: const Icon(PhosphorIconsLight.folderOpen, size: 18),
                    label: const Text('Select PDF'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedPdfPath != null ? p.basename(_selectedPdfPath!) : 'No PDF selected',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Results Area
            Expanded(
              child: _ocrResult != null
                  ? DashboardCard(
                      icon: PhosphorIconsLight.fileText,
                      iconColor: theme.colorScheme.tertiary,
                      title: 'Extracted Text (${_ocrResult!.pageTexts.length} pages)',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _exportAsText('txt'),
                            icon: const Icon(PhosphorIconsLight.fileText, size: 14),
                            label: const Text('TXT'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _exportAsText('md'),
                            icon: const Icon(PhosphorIconsLight.fileMd, size: 14),
                            label: const Text('MD'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _exportSearchablePdf,
                            icon: const Icon(PhosphorIconsLight.magnifyingGlass, size: 14),
                            label: const Text('Searchable PDF'),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 340,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.15),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _ocrResult!.combinedText,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PhosphorIconsLight.textAa,
                              size: 52,
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a PDF and click "Extract Text" to begin',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
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

