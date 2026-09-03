import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_accessibility_service.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  String? _selectedPdfPath;
  AccessibilityPreset _preset = AccessibilityPreset.softAmber;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document for Accessibility Adjustment',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
      });
    }
  }

  Future<void> _processAccessibility() async {
    if (_selectedPdfPath == null) return;

    final originalName = p.basename(_selectedPdfPath!);
    final defaultName = 'accessible_${originalName}';

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Accessible PDF As',
      fileName: defaultName,
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
        _statusMessage = 'Applying accessibility legibility presets...';
      });

      try {
        await PdfAccessibilityService.processAccessiblePdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          preset: _preset,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Adjusting legibility on page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully processed accessible PDF saved to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Accessibility transformation failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Accessibility & Legibility Enhancer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isProcessing)
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            if (_statusMessage.isNotEmpty)
              Container(
                color: theme.primaryColor.withOpacity(0.1),
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickPdfFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select PDF File'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedPdfPath != null
                            ? p.basename(_selectedPdfPath!)
                            : 'No PDF selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Accessibility Mode Preset',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<AccessibilityPreset>(
                      title: const Text('Warm Amber Tint (Eye Care / Dyslexia Friendly)'),
                      subtitle: const Text('Reduces harsh blue light glare and improves reading comfort over long periods.'),
                      value: AccessibilityPreset.softAmber,
                      groupValue: _preset,
                      onChanged: (val) {
                        if (val != null) setState(() => _preset = val);
                      },
                    ),
                    RadioListTile<AccessibilityPreset>(
                      title: const Text('High-Contrast Monochrome (Low Vision Support)'),
                      subtitle: const Text('Maximizes text-to-background contrast ratio for users with low visual acuity.'),
                      value: AccessibilityPreset.highContrastMono,
                      groupValue: _preset,
                      onChanged: (val) {
                        if (val != null) setState(() => _preset = val);
                      },
                    ),
                    RadioListTile<AccessibilityPreset>(
                      title: const Text('Legibility Sharpen Boost (Faded Document Repair)'),
                      subtitle: const Text('Enhances thin stroke fonts and low-contrast scanned text.'),
                      value: AccessibilityPreset.legibilityBoost,
                      groupValue: _preset,
                      onChanged: (val) {
                        if (val != null) setState(() => _preset = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedPdfPath != null ? _processAccessibility : null,
                icon: const Icon(Icons.accessibility_new_outlined),
                label: const Text('Apply Accessibility Preset & Save PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
