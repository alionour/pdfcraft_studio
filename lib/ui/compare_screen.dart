import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_compare_service.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? _pathA;
  String? _pathB;
  PageCompareSummary? _summary;

  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _pickFileA() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select Original PDF Document (Doc A)',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pathA = result.files.single.path;
        _summary = null;
      });
    }
  }

  Future<void> _pickFileB() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select Revised PDF Document (Doc B)',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pathB = result.files.single.path;
        _summary = null;
      });
    }
  }

  Future<void> _compare() async {
    if (_pathA == null || _pathB == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing and comparing document structures...';
    });

    try {
      final summary = await PdfCompareService.comparePdfs(
        pathA: _pathA!,
        pathB: _pathB!,
      );

      setState(() {
        _summary = summary;
        _isProcessing = false;
        _statusMessage = 'Comparison analysis complete!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Comparison failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Comparison & Visual Diff'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isProcessing) const LinearProgressIndicator(),
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
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Original Document (Doc A)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickFileA,
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Select Doc A'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pathA != null ? p.basename(_pathA!) : 'No PDF selected',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revised Document (Doc B)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickFileB,
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Select Doc B'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pathB != null ? p.basename(_pathB!) : 'No PDF selected',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pathA != null && _pathB != null ? _compare : null,
                icon: const Icon(Icons.difference_outlined),
                label: const Text('Compare Documents'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_summary != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comparison Results Summary',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: Icon(
                          _summary!.isPageCountMatching
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                          color: _summary!.isPageCountMatching ? Colors.green : Colors.orange,
                        ),
                        title: Text('Page Count Match: ${_summary!.isPageCountMatching ? "Matching" : "Mismatch"}'),
                        subtitle: Text(
                          'Doc A has ${_summary!.docAPageCount} page(s), Doc B has ${_summary!.docBPageCount} page(s).',
                        ),
                      ),
                    ],
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
