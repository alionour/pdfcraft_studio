import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_manipulation_service.dart';
import 'theme/dashboard_style_app_bar.dart';

class OrganizeScreen extends StatefulWidget {
  const OrganizeScreen({super.key});

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Page Organize State
  String? _loadedPdfPath;
  List<PageItemInfo> _pageItems = [];
  bool _isLoadingPages = false;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  // Merge State
  final List<String> _mergePdfPaths = [];

  // Split State
  String? _splitPdfPath;
  String _splitMode = 'single_pages'; // 'single_pages', 'every_n', 'ranges'
  int _everyNPages = 2;
  final TextEditingController _rangeController = TextEditingController(text: '1-2; 3-5');
  final TextEditingController _splitOutputDirController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rangeController.dispose();
    _splitOutputDirController.dispose();
    super.dispose();
  }

  Future<void> _pickOrganizePdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _loadedPdfPath = path;
        _isLoadingPages = true;
        _pageItems.clear();
      });

      try {
        final doc = await pdfx.PdfDocument.openFile(path);
        final count = doc.pagesCount;
        await doc.close();

        final items = <PageItemInfo>[];
        for (int i = 0; i < count; i++) {
          items.add(PageItemInfo(originalIndex: i, pdfPath: path));
        }

        setState(() {
          _pageItems = items;
          _isLoadingPages = false;
        });
      } catch (e) {
        setState(() {
          _isLoadingPages = false;
          _statusMessage = 'Error loading PDF: $e';
        });
      }
    }
  }

  Future<void> _saveOrganizedPdf() async {
    if (_loadedPdfPath == null || _pageItems.isEmpty) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Organized PDF',
      fileName: 'organized_${p.basename(_loadedPdfPath!)}',
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
        _statusMessage = 'Exporting organized PDF...';
      });

      try {
        await PdfManipulationService.saveOrganizedPdf(
          pages: _pageItems,
          outputPdfPath: output,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Processing page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully saved to $output!';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Failed to save organized PDF: $e';
        });
      }
    }
  }

  Future<void> _pickMergePdfs() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _mergePdfPaths.addAll(result.paths.whereType<String>());
      });
    }
  }

  Future<void> _runMerge() async {
    if (_mergePdfPaths.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDF files to merge.')),
      );
      return;
    }

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Merged PDF',
      fileName: 'merged_document.pdf',
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
        _statusMessage = 'Merging PDF files...';
      });

      try {
        await PdfManipulationService.mergePdfs(
          pdfPaths: _mergePdfPaths,
          outputPdfPath: output,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Merging page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully merged into $output!';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Failed to merge PDFs: $e';
        });
      }
    }
  }

  Future<void> _pickSplitPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      final parent = p.dirname(selectedPath);
      final baseName = p.basenameWithoutExtension(selectedPath);
      setState(() {
        _splitPdfPath = selectedPath;
        _splitOutputDirController.text = p.join(parent, "${baseName}_split");
      });
    }
  }

  Future<void> _browseSplitOutputDir() async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Output Directory for Split PDFs',
    );
    if (folder != null) {
      setState(() {
        _splitOutputDirController.text = folder;
      });
    }
  }

  Future<void> _runSplit() async {
    if (_splitPdfPath == null) return;

    var outputFolder = _splitOutputDirController.text.trim();
    if (outputFolder.isEmpty) {
      final folder = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Output Directory for Split PDFs',
      );
      if (folder == null) return;
      outputFolder = folder;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Splitting PDF...';
    });

    try {
      final generated = await PdfManipulationService.splitPdf(
        pdfPath: _splitPdfPath!,
        outputDir: outputFolder,
        splitMode: _splitMode,
        rangeString: _rangeController.text,
        everyNPages: _everyNPages,
        onProgress: (cur, tot) {
          setState(() {
            _progress = cur / tot;
            _statusMessage = 'Splitting page $cur of $tot...';
          });
        },
      );

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Successfully split into ${generated.length} files in $outputFolder!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Failed to split PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('PDF Organize & Edit Suite'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(PhosphorIconsLight.gridFour), text: 'Page Organizer'),
            Tab(icon: Icon(PhosphorIconsLight.gitMerge), text: 'Merge PDFs'),
            Tab(icon: Icon(PhosphorIconsLight.scissors), text: 'Split PDF'),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
        ),
      ),
      body: Column(
        children: [
          if (_isProcessing)
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrganizerTab(),
                _buildMergeTab(),
                _buildSplitTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizerTab() {
    if (_loadedPdfPath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No PDF Loaded for Page Reordering & Rotation',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickOrganizePdf,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open PDF File'),
            ),
          ],
        ),
      );
    }

    if (_isLoadingPages) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                'File: ${p.basename(_loadedPdfPath!)} (${_pageItems.length} pages)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    for (var item in _pageItems) {
                      item.rotationAngle = (item.rotationAngle + 90) % 360;
                    }
                  });
                },
                icon: const Icon(PhosphorIconsLight.arrowClockwise, size: 16),
                label: const Text('Rotate All'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveOrganizedPdf,
                icon: const Icon(PhosphorIconsLight.floppyDisk, size: 16),
                label: const Text('Export PDF'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _pageItems.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _pageItems.removeAt(oldIndex);
                _pageItems.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final item = _pageItems[index];
              return Card(
                key: ValueKey(item.originalIndex),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text('Original Page ${item.originalIndex + 1}'),
                  subtitle: Text('Rotation: ${item.rotationAngle}°'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(PhosphorIconsLight.arrowClockwise),
                        tooltip: 'Rotate 90°',
                        onPressed: () {
                          setState(() {
                            item.rotationAngle = (item.rotationAngle + 90) % 360;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          item.isSelected
                              ? PhosphorIconsLight.checkSquare
                              : PhosphorIconsLight.square,
                          color: item.isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        tooltip: item.isSelected ? 'Include Page' : 'Exclude Page',
                        onPressed: () {
                          setState(() {
                            item.isSelected = !item.isSelected;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          PhosphorIconsLight.trash,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'Remove Page',
                        onPressed: () {
                          setState(() {
                            _pageItems.removeAt(index);
                          });
                        },
                      ),
                      const Icon(PhosphorIconsLight.dotsSixVertical),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMergeTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _pickMergePdfs,
                icon: const Icon(PhosphorIconsLight.plus, size: 16),
                label: const Text('Add PDF Files'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _mergePdfPaths.isEmpty ? null : () => setState(() => _mergePdfPaths.clear()),
                icon: const Icon(PhosphorIconsLight.trash, size: 16),
                label: const Text('Clear List'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _mergePdfPaths.isEmpty
                ? const Center(
                    child: Text('No PDF files added for merging. Click "Add PDF Files" to start.'),
                  )
                : ReorderableListView.builder(
                    itemCount: _mergePdfPaths.length,
                    onReorder: (oldIdx, newIdx) {
                      setState(() {
                        if (newIdx > oldIdx) newIdx -= 1;
                        final path = _mergePdfPaths.removeAt(oldIdx);
                        _mergePdfPaths.insert(newIdx, path);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = _mergePdfPaths[index];
                      return Card(
                        key: ValueKey(path),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(p.basename(path)),
                          subtitle: Text(
                            path,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  PhosphorIconsLight.trash,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _mergePdfPaths.removeAt(index);
                                  });
                                },
                              ),
                              const Icon(PhosphorIconsLight.dotsSixVertical),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _mergePdfPaths.length >= 2 ? _runMerge : null,
            icon: const Icon(PhosphorIconsLight.gitMerge, size: 18),
            label: const Text('Merge PDFs'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _pickSplitPdf,
                icon: const Icon(PhosphorIconsLight.folderOpen, size: 18),
                label: const Text('Select PDF to Split'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _splitPdfPath != null ? p.basename(_splitPdfPath!) : 'No PDF selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _splitOutputDirController,
            decoration: InputDecoration(
              labelText: 'Output Destination Directory',
              hintText: 'Select or type output folder path',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(PhosphorIconsLight.folderOpen),
                tooltip: 'Browse Folder',
                onPressed: _browseSplitOutputDir,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Split Mode:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          RadioListTile<String>(
            title: const Text('Split into single page PDFs'),
            subtitle: const Text('Extract every single page as an individual PDF document'),
            value: 'single_pages',
            groupValue: _splitMode,
            onChanged: (val) => setState(() => _splitMode = val!),
          ),
          RadioListTile<String>(
            title: const Text('Split every N pages'),
            subtitle: Row(
              children: [
                const Text('Group every '),
                DropdownButton<int>(
                  value: _everyNPages,
                  items: [2, 3, 5, 10, 20]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (val) => setState(() => _everyNPages = val!),
                ),
                const Text(' pages into a separate file'),
              ],
            ),
            value: 'every_n',
            groupValue: _splitMode,
            onChanged: (val) => setState(() => _splitMode = val!),
          ),
          RadioListTile<String>(
            title: const Text('Split by custom page ranges'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                controller: _rangeController,
                decoration: const InputDecoration(
                  labelText: 'Ranges separated by semicolon (e.g. 1-3; 4-6)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            value: 'ranges',
            groupValue: _splitMode,
            onChanged: (val) => setState(() => _splitMode = val!),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _splitPdfPath != null ? _runSplit : null,
              icon: const Icon(PhosphorIconsLight.scissors, size: 18),
              label: const Text('Split PDF Now'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ),
        ],
      ),
    );
  }
}

