import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_color_inverter_service.dart';

class ColorInverterScreen extends StatefulWidget {
  const ColorInverterScreen({super.key});

  @override
  State<ColorInverterScreen> createState() => _ColorInverterScreenState();
}

class _ColorInverterScreenState extends State<ColorInverterScreen> {
  String? _selectedPdfPath;
  ColorInversionConfig _config = const ColorInversionConfig();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document for Night Mode Transformation',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = 'Selected: ${p.basename(_selectedPdfPath!)}';
      });
    }
  }

  Future<void> _processInvert() async {
    if (_selectedPdfPath == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Rendering pages with dark color scheme...';
    });

    try {
      final outputPath = await PdfColorInverterService.generateInvertedPdf(
        inputPdfPath: _selectedPdfPath!,
        config: _config,
        onProgress: (current, total) {
          setState(() {
            _progress = current / total;
            _statusMessage = 'Processing page $current of $total...';
          });
        },
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Saved night mode PDF: ${p.basename(outputPath)}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Night mode PDF generated: ${p.basename(outputPath)}'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error processing PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Night Mode & High-Contrast Inverter'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: _isProcessing ? null : _pickPdfFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.nightlight_round,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedPdfPath != null
                                ? p.basename(_selectedPdfPath!)
                                : 'Select or Drag & Drop PDF Document',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPdfPath != null
                                ? _selectedPdfPath!
                                : 'Converts bright white pages into eye-friendly dark and low-light palettes',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Reading Theme & Color Palette',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ColorInversionTheme.values.map((themeOption) {
                    final isSelected = _config.theme == themeOption;
                    return ChoiceChip(
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              themeOption.label,
                              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            ),
                            Text(
                              themeOption.description,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _config = _config.copyWith(theme: themeOption);
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                if (_isProcessing) ...[
                  LinearProgressIndicator(value: _progress, minHeight: 8),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
                ElevatedButton.icon(
                  onPressed: (_selectedPdfPath == null || _isProcessing) ? null : _processInvert,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Convert to Night Reading PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_statusMessage.isNotEmpty && !_isProcessing) ...[
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
