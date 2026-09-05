import 'dart:io';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_attachment_service.dart';

class AttachmentManagerScreen extends StatefulWidget {
  const AttachmentManagerScreen({super.key});

  @override
  State<AttachmentManagerScreen> createState() => _AttachmentManagerScreenState();
}

class _AttachmentManagerScreenState extends State<AttachmentManagerScreen> with SingleTickerProviderStateMixin {
  String? _pdfPath;
  Uint8List? _pdfBytes;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isDragging = false;

  late TabController _tabController;

  // Inspected attachments
  List<PdfAttachmentInfo> _discoveredAttachments = [];

  // Files to attach
  final List<FileToAttach> _filesToAttach = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _loadPdf(result.files.single.path!);
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading PDF & inspecting embedded files...';
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final attachments = PdfAttachmentService.inspectAttachments(bytes);

      setState(() {
        _pdfPath = path;
        _pdfBytes = bytes;
        _discoveredAttachments = attachments;
        _isLoading = false;
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFilesToAttach() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      for (final platformFile in result.files) {
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          final bytes = await file.readAsBytes();
          final name = p.basename(platformFile.path!);
          _filesToAttach.add(
            FileToAttach(
              name: name,
              description: 'Attached document',
              data: bytes,
            ),
          );
        }
      }
      setState(() {});
    }
  }

  Future<void> _extractSingle(PdfAttachmentInfo attachment) async {
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Destination Directory to Extract "${attachment.name}"',
    );

    if (selectedDirectory == null) return;

    try {
      final file = await PdfAttachmentService.extractAttachment(attachment, selectedDirectory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted to: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _extractAll() async {
    if (_discoveredAttachments.isEmpty) return;

    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Destination Directory to Extract All Attachments',
    );

    if (selectedDirectory == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Extracting all attachments...';
    });

    try {
      final files = await PdfAttachmentService.extractAllAttachments(_discoveredAttachments, selectedDirectory);
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully extracted ${files.length} files to $selectedDirectory'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportManifest(bool isCsv) async {
    if (_discoveredAttachments.isEmpty || _pdfPath == null) return;

    final docName = p.basename(_pdfPath!);
    final defaultFileName = '${p.basenameWithoutExtension(_pdfPath!)}_attachments.${isCsv ? 'csv' : 'json'}';

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save Attachment Manifest',
      fileName: defaultFileName,
    );

    if (savePath == null) return;

    try {
      final manifestString = isCsv
          ? PdfAttachmentService.exportCsvManifest(_discoveredAttachments, documentName: docName)
          : PdfAttachmentService.exportJsonManifest(_discoveredAttachments, documentName: docName);

      final file = File(savePath);
      await file.writeAsString(manifestString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manifest saved to: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export manifest: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _sanitizeAndStripPdf() async {
    if (_pdfBytes == null || _pdfPath == null) return;

    final defaultPath = '${p.withoutExtension(_pdfPath!)}_sanitized_no_attachments.pdf';
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save Sanitized PDF (No Attachments)',
      fileName: p.basename(defaultPath),
    );

    if (savePath == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sanitizing PDF and removing all embedded files...';
    });

    try {
      final cleanedBytes = PdfAttachmentService.stripAttachments(_pdfBytes!);
      final file = File(savePath);
      await file.writeAsBytes(cleanedBytes);

      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sanitized PDF saved: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sanitize PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _embedAndSavePdf() async {
    if (_pdfBytes == null || _pdfPath == null || _filesToAttach.isEmpty) return;

    final defaultPath = '${p.withoutExtension(_pdfPath!)}_with_attachments.pdf';
    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save PDF with Embedded Attachments',
      fileName: p.basename(defaultPath),
    );

    if (savePath == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Embedding ${_filesToAttach.length} attachments into PDF...';
    });

    try {
      final updatedBytes = PdfAttachmentService.attachFilesToPdf(_pdfBytes!, _filesToAttach);
      final file = File(savePath);
      await file.writeAsBytes(updatedBytes);

      setState(() {
        _isLoading = false;
        _statusMessage = null;
        _filesToAttach.clear();
      });

      // Reload to reflect new attachments
      await _loadPdf(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attachments embedded successfully: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to embed attachments: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  IconData _getIconForMime(String mime) {
    if (mime.contains('image')) return PhosphorIconsLight.image;
    if (mime.contains('xml') || mime.contains('json')) return PhosphorIconsLight.code;
    if (mime.contains('sheet') || mime.contains('csv')) return PhosphorIconsLight.table;
    if (mime.contains('pdf')) return PhosphorIconsLight.filePdf;
    if (mime.contains('zip')) return PhosphorIconsLight.archive;
    return PhosphorIconsLight.file;
  }

  Widget _buildSecurityRiskChip(AttachmentSecurityRisk risk, ThemeData theme) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (risk) {
      case AttachmentSecurityRisk.safe:
        bg = Colors.green.withAlpha(35);
        fg = Colors.green.shade800;
        label = 'Safe';
        icon = PhosphorIconsLight.checkCircle;
        break;
      case AttachmentSecurityRisk.caution:
        bg = Colors.amber.withAlpha(45);
        fg = Colors.amber.shade900;
        label = 'Caution';
        icon = PhosphorIconsLight.warning;
        break;
      case AttachmentSecurityRisk.danger:
        bg = Colors.red.withAlpha(45);
        fg = Colors.red.shade800;
        label = 'Risk (Exec/Script)';
        icon = PhosphorIconsLight.shieldWarning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attachments & Portfolio Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(PhosphorIconsLight.tray),
              text: 'Inspect & Extract (${_discoveredAttachments.length})',
            ),
            Tab(
              icon: const Icon(PhosphorIconsLight.paperclip),
              text: 'Embed New Files (${_filesToAttach.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage ?? 'Processing...', style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : DropTarget(
              onDragEntered: (details) => setState(() => _isDragging = true),
              onDragExited: (details) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                if (details.files.isNotEmpty) {
                  final path = details.files.first.path;
                  if (path.toLowerCase().endsWith('.pdf')) {
                    _loadPdf(path);
                  }
                }
              },
              child: Container(
                color: _isDragging ? theme.colorScheme.primary.withAlpha(25) : Colors.transparent,
                child: Column(
                  children: [
                    // Header document picker bar
                    _buildTopHeader(theme),
                    const Divider(height: 1),
                    Expanded(
                      child: _pdfPath == null
                          ? _buildEmptyState(theme)
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildInspectTab(theme),
                                _buildEmbedTab(theme),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
      child: Row(
        children: [
          Icon(PhosphorIconsLight.filePdf, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pdfPath != null ? p.basename(_pdfPath!) : 'No PDF selected',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _pdfPath != null
                      ? '${_discoveredAttachments.length} embedded attachment(s) found'
                      : 'Drag & drop a PDF file or click Browse',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(PhosphorIconsLight.folderOpen),
            label: const Text('Select PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsLight.fileArchive, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Open a PDF to Inspect or Manage Attachments',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Inspect hidden embedded files, XML e-invoices, CAD specs, or sanitize attachments.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(PhosphorIconsLight.plus),
            label: const Text('Select PDF Document'),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectTab(ThemeData theme) {
    if (_discoveredAttachments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsLight.tray, size: 54, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No Embedded Attachments Found',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This PDF does not contain embedded files or portfolio attachments.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    final totalSize = _discoveredAttachments.fold<int>(0, (sum, a) => sum + a.size);
    final totalSizeStr = totalSize < 1024 * 1024
        ? '${(totalSize / 1024).toStringAsFixed(1)} KB'
        : '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';

    return Column(
      children: [
        // Action toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${_discoveredAttachments.length} Attachment(s) • Total Size: $totalSizeStr',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _exportManifest(true),
                icon: const Icon(PhosphorIconsLight.fileCsv, size: 16),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportManifest(false),
                icon: const Icon(PhosphorIconsLight.code, size: 16),
                label: const Text('Export JSON'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _sanitizeAndStripPdf,
                icon: const Icon(PhosphorIconsLight.shieldSlash, size: 16),
                label: const Text('Strip All (Sanitize)'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _extractAll,
                icon: const Icon(PhosphorIconsLight.downloadSimple, size: 16),
                label: const Text('Extract All'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _discoveredAttachments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = _discoveredAttachments[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(60),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_getIconForMime(a.mimeType), color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    a.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _buildSecurityRiskChip(a.securityRisk, theme),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${a.humanSize} • ${a.mimeType}${a.description.isNotEmpty ? ' • ${a.description}' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SHA-256: ${a.sha256.substring(0, 16)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Extract "${a.name}"',
                        onPressed: () => _extractSingle(a),
                        icon: const Icon(PhosphorIconsLight.downloadSimple),
                      ),
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

  Widget _buildEmbedTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Files to Embed (${_filesToAttach.length})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickFilesToAttach,
                icon: const Icon(PhosphorIconsLight.plus, size: 16),
                label: const Text('Add Files'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _filesToAttach.isEmpty ? null : _embedAndSavePdf,
                icon: const Icon(PhosphorIconsLight.floppyDisk, size: 16),
                label: const Text('Save PDF with Attachments'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_filesToAttach.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsLight.paperclip, size: 54, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No Files Queued to Attach',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click "Add Files" to choose spreadsheets, data files, or documents to bundle inside this PDF.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickFilesToAttach,
                    icon: const Icon(PhosphorIconsLight.plus),
                    label: const Text('Choose Files to Attach'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filesToAttach.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = _filesToAttach[index];
                final sizeStr = file.data.length < 1024 * 1024
                    ? '${(file.data.length / 1024).toStringAsFixed(1)} KB'
                    : '${(file.data.length / (1024 * 1024)).toStringAsFixed(2)} MB';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: ListTile(
                    leading: const Icon(PhosphorIconsLight.paperclip),
                    title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$sizeStr • Ready to bundle'),
                    trailing: IconButton(
                      icon: const Icon(PhosphorIconsLight.trash, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _filesToAttach.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
