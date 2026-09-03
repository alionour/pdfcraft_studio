import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_page_reorder_service.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key});

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  String? _selectedPdfPath;
  List<PageOrderItem> _pageItems = [];

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document to Reorder Pages',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedPdfPath = path;
        // Sample 5 pages initialized
        _pageItems = List.generate(
          5,
          (index) => PageOrderItem(originalPageIndex: index + 1),
        );
        _statusMessage = 'Loaded 5 pages for reordering and rotation.';
      });
    }
  }

  void _rotatePage(int index, int deltaDegrees) {
    setState(() {
      final current = _pageItems[index];
      final newRot = PdfPageReorderService.normalizeRotation(current.rotationDegrees + deltaDegrees);
      _pageItems[index] = current.copyWith(rotationDegrees: newRot);
    });
  }

  void _toggleDelete(int index) {
    setState(() {
      final current = _pageItems[index];
      _pageItems[index] = current.copyWith(isDeleted: !current.isDeleted);
    });
  }

  Future<void> _processSave() async {
    if (_selectedPdfPath == null || _pageItems.isEmpty) return;

    final originalName = p.basename(_selectedPdfPath!);
    final defaultName = 'reordered_$originalName';

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Reordered PDF As',
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
        _statusMessage = 'Rebuilding and applying page rotations...';
      });

      try {
        await PdfPageReorderService.saveReorderedPdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          pageOrder: _pageItems,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Processing page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully saved reordered PDF to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Reordering failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Reorder & Rotation Manager'),
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
            if (_pageItems.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Page Order & Rotations',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pageItems.length,
                        onReorder: (oldIdx, newIdx) {
                          setState(() {
                            if (newIdx > oldIdx) newIdx -= 1;
                            final item = _pageItems.removeAt(oldIdx);
                            _pageItems.insert(newIdx, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _pageItems[index];
                          return ListTile(
                            key: ValueKey(item.originalPageIndex),
                            leading: CircleAvatar(
                              child: Text('${item.originalPageIndex}'),
                            ),
                            title: Text(
                              'Original Page ${item.originalPageIndex}',
                              style: TextStyle(
                                decoration: item.isDeleted ? TextDecoration.lineThrough : null,
                                color: item.isDeleted ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Text('Rotation: ${item.rotationDegrees}°'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.rotate_right),
                                  tooltip: 'Rotate 90° Clockwise',
                                  onPressed: () => _rotatePage(index, 90),
                                ),
                                IconButton(
                                  icon: Icon(
                                    item.isDeleted ? Icons.restore : Icons.delete_outline,
                                    color: item.isDeleted ? Colors.green : Colors.red,
                                  ),
                                  tooltip: item.isDeleted ? 'Restore Page' : 'Remove Page',
                                  onPressed: () => _toggleDelete(index),
                                ),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                          );
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
                  onPressed: _processSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Reordered & Rotated PDF'),
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
