import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_filter_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String? _selectedPdfPath;
  FilterMode _mode = FilterMode.darkMode;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF File to Apply Color Filter',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = '';
        _isSuccess = false;
      });
    }
  }

  Future<void> _applyFilter() async {
    if (_selectedPdfPath == null) return;

    String prefix = 'dark_';
    if (_mode == FilterMode.grayscale) prefix = 'gray_';
    if (_mode == FilterMode.sepia) prefix = 'sepia_';

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Filtered PDF As',
      fileName: '$prefix${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) output = '$output.pdf';

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Applying color filter to PDF pages...';
        _isSuccess = false;
      });

      try {
        await PdfFilterService.convertPdfWithFilter(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          mode: _mode,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Processing page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Filtered PDF saved successfully';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Color filter operation failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('Color Filters & Dark Mode'),
      ),
      body: SingleChildScrollView(
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

            // Source File Card
            DashboardCard(
              icon: PhosphorIconsLight.filePdf,
              iconColor: theme.colorScheme.error,
              title: 'Source File',
              child: Row(
                children: [
                  FilledButton.icon(
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
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Filter Mode Card
            DashboardCard(
              icon: PhosphorIconsLight.palette,
              iconColor: theme.colorScheme.primary,
              title: 'Color Filter Mode',
              child: Column(
                children: [
                  RadioListTile<FilterMode>(
                    title: const Text('High-Contrast Dark Mode'),
                    subtitle: const Text('Inverts page luminance for comfortable low-light reading'),
                    value: FilterMode.darkMode,
                    groupValue: _mode,
                    onChanged: (val) {
                      if (val != null) setState(() => _mode = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<FilterMode>(
                    title: const Text('Grayscale / Monochrome'),
                    subtitle: const Text('Converts to 8-bit grayscale to save color ink'),
                    value: FilterMode.grayscale,
                    groupValue: _mode,
                    onChanged: (val) {
                      if (val != null) setState(() => _mode = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<FilterMode>(
                    title: const Text('Warm Sepia Tone'),
                    subtitle: const Text('Applies vintage sepia tone for reduced eye strain'),
                    value: FilterMode.sepia,
                    groupValue: _mode,
                    onChanged: (val) {
                      if (val != null) setState(() => _mode = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_selectedPdfPath != null && !_isProcessing) ? _applyFilter : null,
                icon: const Icon(PhosphorIconsLight.palette, size: 18),
                label: const Text('Apply Filter & Save PDF'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

