import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_header_footer_service.dart';

class HeaderFooterScreen extends StatefulWidget {
  const HeaderFooterScreen({super.key});

  @override
  State<HeaderFooterScreen> createState() => _HeaderFooterScreenState();
}

class _HeaderFooterScreenState extends State<HeaderFooterScreen> {
  String? _selectedPdfPath;
  HeaderFooterConfig _config = const HeaderFooterConfig();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document for Headers & Footers',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = 'Selected document for headers and footers.';
      });
    }
  }

  Future<void> _processApply() async {
    if (_selectedPdfPath == null) return;

    final defaultName = PdfHeaderFooterService.formatHeaderFooterFileName(_selectedPdfPath!);

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Custom PDF As',
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
        _statusMessage = 'Adding custom headers and footers to document...';
      });

      try {
        await PdfHeaderFooterService.addHeaderAndFooter(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          config: _config,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Applying to page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully added headers & footers to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Header & footer insertion failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Header & Footer Customizer'),
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
                        'Header & Footer Options',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _config.headerText,
                        decoration: const InputDecoration(
                          labelText: 'Header Text Template',
                          hintText: 'e.g., {pdf_name} - Internal Use Only',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _config = _config.copyWith(headerText: val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _config.footerText,
                        decoration: const InputDecoration(
                          labelText: 'Footer Text Template',
                          hintText: 'e.g., Page {page} of {total}',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _config = _config.copyWith(footerText: val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<HeaderFooterAlignment>(
                        value: _config.alignment,
                        decoration: const InputDecoration(
                          labelText: 'Text Alignment',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: HeaderFooterAlignment.left,
                            child: Text('Left Aligned'),
                          ),
                          DropdownMenuItem(
                            value: HeaderFooterAlignment.center,
                            child: Text('Centered'),
                          ),
                          DropdownMenuItem(
                            value: HeaderFooterAlignment.right,
                            child: Text('Right Aligned'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _config = _config.copyWith(alignment: val));
                          }
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
                  onPressed: _processApply,
                  icon: const Icon(Icons.vertical_align_center),
                  label: const Text('Apply Headers & Footers'),
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
