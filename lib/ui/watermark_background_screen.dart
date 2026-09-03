import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_watermark_background_service.dart';

class WatermarkBackgroundScreen extends StatefulWidget {
  const WatermarkBackgroundScreen({super.key});

  @override
  State<WatermarkBackgroundScreen> createState() => _WatermarkBackgroundScreenState();
}

class _WatermarkBackgroundScreenState extends State<WatermarkBackgroundScreen> {
  String? _selectedPdfPath;
  WatermarkConfig _config = const WatermarkConfig();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document for Watermarking',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = 'Selected document for watermarking.';
      });
    }
  }

  Future<void> _processApply() async {
    if (_selectedPdfPath == null) return;

    final defaultName = PdfWatermarkBackgroundService.formatWatermarkedFileName(_selectedPdfPath!);

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Watermarked PDF As',
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
        _statusMessage = 'Applying watermark overlay to document pages...';
      });

      try {
        await PdfWatermarkBackgroundService.applyWatermarkAndBackground(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          config: _config,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Processing page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully applied watermark to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Watermarking failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Background & Watermark Colorizer'),
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
            if (_selectedPdfPath != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Watermark Configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _config.text,
                        decoration: const InputDecoration(
                          labelText: 'Watermark Text',
                          hintText: 'e.g., CONFIDENTIAL, DRAFT, DO NOT COPY',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _config = _config.copyWith(text: val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Opacity: ${(_config.opacity * 100).round()}%'),
                                Slider(
                                  value: _config.opacity,
                                  min: 0.1,
                                  max: 1.0,
                                  divisions: 9,
                                  onChanged: (val) {
                                    setState(() {
                                      _config = _config.copyWith(opacity: val);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Font Size: ${_config.fontSize.round()} pt'),
                                Slider(
                                  value: _config.fontSize,
                                  min: 24,
                                  max: 96,
                                  divisions: 12,
                                  onChanged: (val) {
                                    setState(() {
                                      _config = _config.copyWith(fontSize: val);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processApply,
                  icon: const Icon(Icons.branding_watermark_outlined),
                  label: const Text('Apply Watermark & Background'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
