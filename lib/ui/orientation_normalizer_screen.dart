import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_orientation_normalizer_service.dart';

class OrientationNormalizerScreen extends StatefulWidget {
  const OrientationNormalizerScreen({super.key});

  @override
  State<OrientationNormalizerScreen> createState() => _OrientationNormalizerScreenState();
}

class _OrientationNormalizerScreenState extends State<OrientationNormalizerScreen> {
  String? _selectedPdfPath;
  TargetPageSize _pageSize = TargetPageSize.a4;
  TargetOrientation _orientation = TargetOrientation.portrait;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document to Normalize',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = 'Loaded document for orientation normalization.';
      });
    }
  }

  Future<void> _processNormalize() async {
    if (_selectedPdfPath == null) return;

    final defaultName = PdfOrientationNormalizerService.formatNormalizedFileName(_selectedPdfPath!);

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Normalized PDF As',
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
        _statusMessage = 'Normalizing page dimensions and orientation...';
      });

      try {
        await PdfOrientationNormalizerService.normalizePdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          targetSize: _pageSize,
          targetOrientation: _orientation,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Standardizing page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully normalized document dimensions:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Normalization failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Orientation & Dimension Normalizer'),
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
                        'Target Page Dimensions & Layout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TargetPageSize>(
                        value: _pageSize,
                        decoration: const InputDecoration(
                          labelText: 'Standard Page Size',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TargetPageSize.a4,
                            child: Text('ISO A4 (210 x 297 mm)'),
                          ),
                          DropdownMenuItem(
                            value: TargetPageSize.letter,
                            child: Text('US Letter (8.5 x 11 in)'),
                          ),
                          DropdownMenuItem(
                            value: TargetPageSize.legal,
                            child: Text('US Legal (8.5 x 14 in)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _pageSize = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TargetOrientation>(
                        value: _orientation,
                        decoration: const InputDecoration(
                          labelText: 'Target Orientation',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TargetOrientation.portrait,
                            child: Text('Portrait (Vertical Standard)'),
                          ),
                          DropdownMenuItem(
                            value: TargetOrientation.landscape,
                            child: Text('Landscape (Horizontal Wide)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _orientation = val);
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
                  onPressed: _processNormalize,
                  icon: const Icon(Icons.aspect_ratio_outlined),
                  label: const Text('Normalize PDF Dimensions'),
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
