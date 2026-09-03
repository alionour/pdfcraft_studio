import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_batch_merger_service.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<String> _selectedPdfPaths = [];

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      dialogTitle: 'Select PDF Documents to Merge',
    );

    if (result != null) {
      final paths = result.paths.whereType<String>().toList();
      setState(() {
        _selectedPdfPaths.addAll(paths);
        _statusMessage = 'Selected ${_selectedPdfPaths.length} PDF file(s).';
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedPdfPaths.removeAt(index);
    });
  }

  Future<void> _processMerge() async {
    if (_selectedPdfPaths.isEmpty) return;

    final defaultName = PdfBatchMergerService.formatMergedFileName(_selectedPdfPaths.first);

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Merged PDF As',
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
        _statusMessage = 'Merging PDF documents into a single file...';
      });

      try {
        await PdfBatchMergerService.mergePdfs(
          inputPdfPaths: _selectedPdfPaths,
          outputPdfPath: output,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Combining page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully merged PDF documents into:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Merge failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Batch Merger & Document Joiner'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickPdfFiles,
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Add PDF Files'),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_selectedPdfPaths.length} document(s) added',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_selectedPdfPaths.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setState(() => _selectedPdfPaths.clear()),
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear All'),
                          ),
                      ],
                    ),
                    if (_selectedPdfPaths.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedPdfPaths.length,
                        onReorder: (oldIdx, newIdx) {
                          setState(() {
                            if (newIdx > oldIdx) newIdx -= 1;
                            final path = _selectedPdfPaths.removeAt(oldIdx);
                            _selectedPdfPaths.insert(newIdx, path);
                          });
                        },
                        itemBuilder: (context, index) {
                          final path = _selectedPdfPaths[index];
                          return ListTile(
                            key: ValueKey(path),
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              p.basename(path),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(path),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _removeFile(index),
                                ),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedPdfPaths.isNotEmpty ? _processMerge : null,
                icon: const Icon(Icons.merge_type_outlined),
                label: const Text('Merge PDF Documents'),
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
