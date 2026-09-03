import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_image_extractor_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class ExtractorScreen extends StatefulWidget {
  const ExtractorScreen({super.key});

  @override
  State<ExtractorScreen> createState() => _ExtractorScreenState();
}

class _ExtractorScreenState extends State<ExtractorScreen> {
  String? _selectedPdfPath;
  String? _selectedOutputDir;
  String _format = 'png';
  List<ExtractedImageInfo> _extractedImages = [];

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF File to Extract Images From',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedPdfPath = path;
        _extractedImages = [];
        _statusMessage = '';
        _isSuccess = false;
        if (_selectedOutputDir == null) {
          _selectedOutputDir = p.join(
              p.dirname(path),
              '${p.basenameWithoutExtension(path)}_extracted_assets');
        }
      });
    }
  }

  Future<void> _pickOutputDir() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Destination Folder for Extracted Assets',
    );
    if (dir != null) {
      setState(() => _selectedOutputDir = dir);
    }
  }

  Future<void> _startExtraction() async {
    if (_selectedPdfPath == null || _selectedOutputDir == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Scanning PDF and extracting high-res image assets...';
      _isSuccess = false;
    });

    try {
      final images = await PdfImageExtractorService.extractImagesFromPdf(
        pdfPath: _selectedPdfPath!,
        outputDir: _selectedOutputDir!,
        format: _format,
        onProgress: (cur, tot) {
          setState(() {
            _progress = cur / tot;
            _statusMessage = 'Extracting assets from page $cur of $tot...';
          });
        },
      );

      setState(() {
        _extractedImages = images;
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage =
            'Extracted ${images.length} image asset(s) to:\n$_selectedOutputDir';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = 'Image extraction failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('Image & Asset Extractor'),
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
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess
                            ? PhosphorIconsLight.checkCircle
                            : PhosphorIconsLight.warningCircle,
                        color: _isSuccess
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
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
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Files Card
            DashboardCard(
              icon: PhosphorIconsLight.images,
              iconColor: theme.colorScheme.primary,
              title: 'Source & Output',
              trailing: FilledButton.icon(
                onPressed: (_selectedPdfPath != null && !_isProcessing)
                    ? _startExtraction
                    : null,
                icon: const Icon(PhosphorIconsLight.arrowSquareOut, size: 16),
                label: const Text('Extract Images'),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPdfFile,
                        icon: const Icon(PhosphorIconsLight.folderOpen, size: 18),
                        label: const Text('Select PDF'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedPdfPath != null
                              ? p.basename(_selectedPdfPath!)
                              : 'No PDF selected',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickOutputDir,
                        icon: const Icon(PhosphorIconsLight.folderPlus, size: 18),
                        label: const Text('Output Folder'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedOutputDir ?? 'No output directory selected',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Export format:',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('PNG (lossless)'),
                        selected: _format == 'png',
                        onSelected: (val) {
                          if (val) setState(() => _format = 'png');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('JPEG (compressed)'),
                        selected: _format == 'jpeg',
                        onSelected: (val) {
                          if (val) setState(() => _format = 'jpeg');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Results Area
            Expanded(
              child: _extractedImages.isNotEmpty
                  ? DashboardCard(
                      icon: PhosphorIconsLight.images,
                      iconColor: theme.colorScheme.secondary,
                      title: 'Extracted Assets (${_extractedImages.length})',
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _extractedImages.length,
                        itemBuilder: (context, index) {
                          final item = _extractedImages[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      PhosphorIconsLight.image,
                                      size: 40,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        p.basename(item.path),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Page ${item.pageNumber}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
                              PhosphorIconsLight.images,
                              size: 52,
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a PDF and click "Extract Images" to export assets',
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

