import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_margin_crop_service.dart';

class CropScreen extends StatefulWidget {
  const CropScreen({super.key});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  String? _selectedPdfPath;
  double _topMm = 0.0;
  double _bottomMm = 0.0;
  double _leftMm = 0.0;
  double _rightMm = 0.0;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document to Trim or Adjust Margins',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
      });
    }
  }

  Future<void> _processCrop() async {
    if (_selectedPdfPath == null) return;

    final originalName = p.basename(_selectedPdfPath!);
    final defaultName = 'cropped_${originalName}';

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Cropped PDF As',
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
        _statusMessage = 'Trimming whitespace borders and applying margin offsets...';
      });

      try {
        await PdfMarginCropService.processMarginCrop(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          config: MarginCropConfig(
            topMm: _topMm,
            bottomMm: _bottomMm,
            leftMm: _leftMm,
            rightMm: _rightMm,
          ),
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Cropping page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully cropped PDF saved to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Margin crop failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Margin Adjustment & Page Cropper'),
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
                      'Crop Margins (Millimeters)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Top Margin Trim: ${_topMm.toStringAsFixed(1)} mm'),
                              Slider(
                                value: _topMm,
                                min: 0.0,
                                max: 50.0,
                                divisions: 100,
                                label: '${_topMm.toStringAsFixed(1)} mm',
                                onChanged: (val) => setState(() => _topMm = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bottom Margin Trim: ${_bottomMm.toStringAsFixed(1)} mm'),
                              Slider(
                                value: _bottomMm,
                                min: 0.0,
                                max: 50.0,
                                divisions: 100,
                                label: '${_bottomMm.toStringAsFixed(1)} mm',
                                onChanged: (val) => setState(() => _bottomMm = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Left Margin Trim: ${_leftMm.toStringAsFixed(1)} mm'),
                              Slider(
                                value: _leftMm,
                                min: 0.0,
                                max: 50.0,
                                divisions: 100,
                                label: '${_leftMm.toStringAsFixed(1)} mm',
                                onChanged: (val) => setState(() => _leftMm = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Right Margin Trim: ${_rightMm.toStringAsFixed(1)} mm'),
                              Slider(
                                value: _rightMm,
                                min: 0.0,
                                max: 50.0,
                                divisions: 100,
                                label: '${_rightMm.toStringAsFixed(1)} mm',
                                onChanged: (val) => setState(() => _rightMm = val),
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
                onPressed: _selectedPdfPath != null ? _processCrop : null,
                icon: const Icon(Icons.crop_outlined),
                label: const Text('Apply Crop & Save PDF'),
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
