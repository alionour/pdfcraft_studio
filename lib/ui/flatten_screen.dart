import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_flatten_service.dart';

class FlattenScreen extends StatefulWidget {
  const FlattenScreen({super.key});

  @override
  State<FlattenScreen> createState() => _FlattenScreenState();
}

class _FlattenScreenState extends State<FlattenScreen> {
  String? _selectedPdfPath;
  FlattenQuality _quality = FlattenQuality.high;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Form or Document to Flatten',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
      });
    }
  }

  Future<void> _flattenPdf() async {
    if (_selectedPdfPath == null) return;

    final defaultName = PdfFlattenService.formatFlattenedFileName(p.basename(_selectedPdfPath!));
    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Flattened PDF As',
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
        _statusMessage = 'Flattening form fields and annotations into static graphics...';
      });

      try {
        await PdfFlattenService.flattenPdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          quality: _quality,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Flattening page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully flattened PDF saved to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Form flattening failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Form Field & Annotation Flattening'),
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
                      label: const Text('Select PDF Form'),
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
                      'Flattening Resolution & Options',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<FlattenQuality>(
                      title: const Text('High Resolution (300 DPI - Recommended for Printing)'),
                      subtitle: const Text('Ensures sharp vector text, crisp signatures, and crystal clear graphics.'),
                      value: FlattenQuality.high,
                      groupValue: _quality,
                      onChanged: (val) {
                        if (val != null) setState(() => _quality = val);
                      },
                    ),
                    RadioListTile<FlattenQuality>(
                      title: const Text('Standard Resolution (150 DPI - Compact File Size)'),
                      subtitle: const Text('Faster processing and smaller file size for email sharing.'),
                      value: FlattenQuality.standard,
                      groupValue: _quality,
                      onChanged: (val) {
                        if (val != null) setState(() => _quality = val);
                      },
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Flattening converts all fillable form inputs, checkboxes, digital signatures, and comments into uneditable background graphics.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedPdfPath != null ? _flattenPdf : null,
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('Flatten Form & Lock Document'),
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
