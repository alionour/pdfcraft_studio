import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/pdf_bookmark_service.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  String? _selectedPdfPath;
  int _totalPages = 0;
  List<PdfBookmarkNode> _bookmarks = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _pageController = TextEditingController(text: '1');

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  @override
  void dispose() {
    _titleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document to Add Bookmarks',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final doc = await pdfx.PdfDocument.openFile(path);
      final count = doc.pagesCount;
      await doc.close();

      setState(() {
        _selectedPdfPath = path;
        _totalPages = count;
        _bookmarks = [
          PdfBookmarkNode(title: 'Cover Page', pageNumber: 1),
          if (count >= 2) PdfBookmarkNode(title: 'Chapter 1', pageNumber: 2),
        ];
      });
    }
  }

  void _addBookmark() {
    final title = _titleController.text.trim();
    final pageNum = int.tryParse(_pageController.text.trim());

    if (title.isNotEmpty && pageNum != null && pageNum >= 1 && pageNum <= _totalPages) {
      setState(() {
        _bookmarks.add(PdfBookmarkNode(title: title, pageNumber: pageNum));
        _bookmarks.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
        _titleController.clear();
      });
    }
  }

  void _removeBookmark(int index) {
    setState(() {
      _bookmarks.removeAt(index);
    });
  }

  Future<void> _saveBookmarkedPdf() async {
    if (_selectedPdfPath == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save PDF with Bookmarks As',
      fileName: 'bookmarked_${p.basename(_selectedPdfPath!)}',
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
        _statusMessage = 'Embedding bookmarks and outlines into PDF...';
      });

      try {
        await PdfBookmarkService.embedBookmarks(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          bookmarks: _bookmarks,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Embedding outlines into page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully embedded bookmarks and saved to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Bookmark embedding failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Bookmarks & Table of Contents Manager'),
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
                            ? '${p.basename(_selectedPdfPath!)} ($_totalPages Pages)'
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
              // Add Bookmark Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Section Bookmark Entry',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Bookmark Title (e.g. Executive Summary)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _pageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Page (1-$_totalPages)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _addBookmark,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Entry'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Bookmark Outline List
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table of Contents Outlines (${_bookmarks.length}):',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_bookmarks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No bookmarks added yet. Add section entries above.'),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bookmarks.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final bm = _bookmarks[index];
                            return ListTile(
                              leading: const Icon(Icons.bookmark_outline, color: Colors.blue),
                              title: Text(
                                bm.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Page ${bm.pageNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _removeBookmark(index),
                                  ),
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
                  onPressed: _saveBookmarkedPdf,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save PDF with Embedded Bookmarks'),
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
