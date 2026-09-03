import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_splitter_service.dart';

class SplitterScreen extends StatefulWidget {
  const SplitterScreen({super.key});

  @override
  State<SplitterScreen> createState() => _SplitterScreenState();
}

class _SplitterScreenState extends State<SplitterScreen> {
  String? _selectedPdfPath;
  SplitMode _mode = SplitMode.singlePages;
  int _pagesPerChunk = 2;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document to Split',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
      });
    }
  }

  Future<void> _processSplit() async {
    if (_selectedPdfPath == null) return;

    final outputDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Destination Folder for Split PDFs',
    );

    if (outputDir != null) {
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Splitting PDF document pages...';
      });

      try {
        final resultPaths = await PdfSplitterService.splitPdf(
          inputPdfPath: _selectedPdfPath!,
          outputDirectory: outputDir,
          mode: _mode,
          pagesPerChunk: _pagesPerChunk,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Exporting chunk $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully split PDF into ${resultPaths.length} file(s) in:\n$outputDir';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'PDF split failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Splitter & Range Extractor'),
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
                      'Split Options',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<SplitMode>(
                      title: const Text('Split Every Page to Separate File'),
                      subtitle: const Text('Creates individual 1-page PDF documents'),
                      value: SplitMode.singlePages,
                      groupValue: _mode,
                      onChanged: (val) {
                        if (val != null) setState(() => _mode = val);
                      },
                    ),
                    RadioListTile<SplitMode>(
                      title: const Text('Split into Equal Chunks'),
                      subtitle: Text('Groups of $_pagesPerChunk page(s) per file'),
                      value: SplitMode.chunkEveryN,
                      groupValue: _mode,
                      onChanged: (val) {
                        if (val != null) setState(() => _mode = val);
                      },
                    ),
                    if (_mode == SplitMode.chunkEveryN)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            const Text('Pages per document chunk: '),
                            DropdownButton<int>(
                              value: _pagesPerChunk,
                              items: [2, 3, 5, 10, 20]
                                  .map((n) => DropdownMenuItem(value: n, child: Text('$n pages')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _pagesPerChunk = val);
                              },
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
                onPressed: _selectedPdfPath != null ? _processSplit : null,
                icon: const Icon(Icons.call_split_outlined),
                label: const Text('Split PDF Document'),
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
