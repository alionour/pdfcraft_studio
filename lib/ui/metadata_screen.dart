import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_metadata_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class MetadataScreen extends StatefulWidget {
  const MetadataScreen({super.key});

  @override
  State<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends State<MetadataScreen> {
  String? _selectedPdfPath;
  PdfMetadataInfo? _metadata;
  bool _stripMetadata = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _creatorController = TextEditingController();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _subjectController.dispose();
    _keywordsController.dispose();
    _creatorController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF File to Inspect Metadata',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedPdfPath = path;
        _isProcessing = true;
        _statusMessage = 'Reading document properties...';
        _isSuccess = false;
      });

      try {
        final info = await PdfMetadataService.readMetadata(path);
        setState(() {
          _metadata = info;
          _titleController.text = info.title;
          _authorController.text = info.author;
          _subjectController.text = info.subject;
          _keywordsController.text = info.keywords;
          _creatorController.text = info.creator;
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Metadata loaded successfully.';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Failed to read metadata: $e';
        });
      }
    }
  }

  Future<void> _saveUpdatedPdf() async {
    if (_selectedPdfPath == null || _metadata == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Updated PDF As',
      fileName: 'meta_${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) output = '$output.pdf';

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = _stripMetadata
            ? 'Stripping sensitive metadata...'
            : 'Writing updated metadata fields...';
        _isSuccess = false;
      });

      try {
        final updatedInfo = _metadata!.copyWith(
          title: _titleController.text,
          author: _authorController.text,
          subject: _subjectController.text,
          keywords: _keywordsController.text,
          creator: _creatorController.text,
        );

        await PdfMetadataService.updateMetadata(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          newMetadata: updatedInfo,
          stripMetadata: _stripMetadata,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Processing page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = _stripMetadata
              ? 'Metadata stripped and saved successfully'
              : 'Metadata updated and saved successfully';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Metadata save operation failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('Metadata & Privacy Inspector'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress + Status Banner
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess
                            ? PhosphorIconsLight.checkCircle
                            : PhosphorIconsLight.warningCircle,
                        color: _isSuccess
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isSuccess
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Source File Card
            DashboardCard(
              icon: PhosphorIconsLight.filePdf,
              iconColor: theme.colorScheme.error,
              title: 'Source File',
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: _pickPdfFile,
                    icon: const Icon(PhosphorIconsLight.folderOpen, size: 18),
                    label: const Text('Select PDF'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedPdfPath != null
                          ? p.basename(_selectedPdfPath!)
                          : 'No PDF selected',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (_metadata != null) ...[
              const SizedBox(height: 20),

              // Summary Stats Card
              DashboardCard(
                icon: PhosphorIconsLight.info,
                iconColor: theme.colorScheme.secondary,
                title: 'Document Properties',
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        theme,
                        label: 'Total Pages',
                        value: '${_metadata!.totalPages}',
                        icon: PhosphorIconsLight.filePdf,
                      ),
                    ),
                    Expanded(
                      child: _buildStatTile(
                        theme,
                        label: 'File Size',
                        value: PdfMetadataService.formatBytes(_metadata!.fileSizeBytes),
                        icon: PhosphorIconsLight.hardDrive,
                      ),
                    ),
                    Expanded(
                      child: _buildStatTile(
                        theme,
                        label: 'Page Size',
                        value: _metadata!.pageSizeInfo,
                        icon: PhosphorIconsLight.frameCorners,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Edit Metadata Card
              DashboardCard(
                icon: PhosphorIconsLight.pencilSimple,
                iconColor: theme.colorScheme.primary,
                title: 'Edit Document Metadata',
                trailing: FilterChip(
                  avatar: const Icon(PhosphorIconsLight.shieldCheck, size: 14),
                  label: const Text('Sanitize All'),
                  selected: _stripMetadata,
                  onSelected: (val) => setState(() => _stripMetadata = val),
                ),
                child: _stripMetadata
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIconsLight.shieldWarning,
                              color: Colors.orange[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Privacy Mode: All metadata (title, author, creation info, tracking data) will be stripped from the saved document.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Document Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _authorController,
                                  decoration: const InputDecoration(
                                    labelText: 'Author / Owner',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _subjectController,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject / Description',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _keywordsController,
                            decoration: const InputDecoration(
                              labelText: 'Keywords (comma-separated)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _creatorController,
                            decoration: const InputDecoration(
                              labelText: 'Creator Application',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: !_isProcessing ? _saveUpdatedPdf : null,
                  icon: Icon(
                    _stripMetadata
                        ? PhosphorIconsLight.shieldCheck
                        : PhosphorIconsLight.floppyDisk,
                    size: 18,
                  ),
                  label: Text(
                    _stripMetadata ? 'Sanitize & Save Clean PDF' : 'Save Updated Metadata PDF',
                  ),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

