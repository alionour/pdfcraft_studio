import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_font_inspector_service.dart';

class FontInspectorScreen extends StatefulWidget {
  const FontInspectorScreen({super.key});

  @override
  State<FontInspectorScreen> createState() => _FontInspectorScreenState();
}

class _FontInspectorScreenState extends State<FontInspectorScreen> {
  String? _pdfPath;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isDragging = false;

  FontPreflightReport? _report;

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
      _statusMessage = 'Reading PDF and auditing typography structures...';
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final report = PdfFontInspectorService.inspectFonts(bytes);

      setState(() {
        _pdfPath = path;
        _report = report;
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
            content: Text('Failed to inspect PDF fonts: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportReport(bool isCsv) async {
    if (_report == null || _pdfPath == null) return;

    final docName = p.basename(_pdfPath!);
    final defaultFileName = '${p.basenameWithoutExtension(_pdfPath!)}_font_audit.${isCsv ? 'csv' : 'json'}';

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save Font Preflight Report',
      fileName: defaultFileName,
    );

    if (savePath == null) return;

    try {
      final content = isCsv
          ? PdfFontInspectorService.exportCsvReport(_report!, documentName: docName)
          : PdfFontInspectorService.exportJsonReport(_report!, documentName: docName);

      final file = File(savePath);
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Font report saved to: $savePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.amber.shade800;
    return Colors.red;
  }

  String _getScoreLabel(double score) {
    if (score >= 95) return 'Prepress & PDF/A Ready';
    if (score >= 80) return 'High Typography Health';
    if (score >= 60) return 'Moderate (Font Fallbacks)';
    return 'Critical (Broken Display Risk)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Font Inspector & Typography Preflight'),
        actions: [
          if (_report != null) ...[
            OutlinedButton.icon(
              onPressed: () => _exportReport(true),
              icon: const Icon(PhosphorIconsLight.fileCsv, size: 16),
              label: const Text('Export CSV'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _exportReport(false),
              icon: const Icon(PhosphorIconsLight.code, size: 16),
              label: const Text('Export JSON'),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage ?? 'Analyzing fonts...', style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
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
                    _buildTopHeader(theme),
                    const Divider(height: 1),
                    Expanded(
                      child: _report == null ? _buildEmptyState(theme) : _buildReportView(theme),
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
          Icon(PhosphorIconsLight.textT, size: 28, color: theme.colorScheme.primary),
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
                  _report != null
                      ? '${_report!.totalFonts} font(s) detected • Compliance: ${_report!.complianceScore}%'
                      : 'Audit typefaces, embedding flags, subsetting, and searchability',
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
          Icon(PhosphorIconsLight.textT, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Select a PDF to Audit Typography and Embedded Fonts',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify PDF/A font embedding, detect missing typefaces, and audit /ToUnicode CMaps.',
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

  Widget _buildReportView(ThemeData theme) {
    final report = _report!;
    final scoreColor = _getScoreColor(report.complianceScore);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Compliance Overview Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Score Gauge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${report.complianceScore.toInt()}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getScoreLabel(report.complianceScore),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fonts embedding status determines whether this document renders identically on all printers and recipient devices.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Statistics Metric Cards
        Row(
          children: [
            _buildStatCard(
              'Total Fonts',
              '${report.totalFonts}',
              PhosphorIconsLight.textT,
              theme.colorScheme.primary,
              theme,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Embedded',
              '${report.embeddedCount}',
              PhosphorIconsLight.checkCircle,
              Colors.green,
              theme,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Not Embedded',
              '${report.missingCount}',
              PhosphorIconsLight.warningOctagon,
              report.missingCount > 0 ? Colors.red : Colors.grey,
              theme,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Subsets',
              '${report.subsetCount}',
              PhosphorIconsLight.scissors,
              Colors.blue,
              theme,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'ToUnicode',
              '${report.toUnicodeCompliantCount}',
              PhosphorIconsLight.translate,
              Colors.purple,
              theme,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Issues Alert Banner
        if (report.issues.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsLight.warning, size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Text(
                      'Preflight Warnings & Diagnostics (${report.issues.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final issue in report.issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            issue,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Fonts List Title
        Text(
          'Document Fonts Inventory (${report.fonts.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        // Fonts Table / Cards
        for (final font in report.fonts) _buildFontCard(font, theme),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontCard(PdfFontInfo font, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(PhosphorIconsLight.textT, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    font.baseFont,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PostScript ID: ${font.name} • Format: ${font.subtype} • Encoding: ${font.encoding}',
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Embedding Badge
            if (font.isEmbedded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsLight.checkCircle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      font.isSubset ? 'Embedded (Subset)' : 'Embedded (Full)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsLight.warningOctagon, size: 14, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Not Embedded',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red),
                    ),
                  ],
                ),
              ),

            const SizedBox(width: 8),

            // ToUnicode Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: font.hasToUnicode ? Colors.purple.withAlpha(35) : Colors.grey.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    font.hasToUnicode ? PhosphorIconsLight.translate : PhosphorIconsLight.xCircle,
                    size: 14,
                    color: font.hasToUnicode ? Colors.purple : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    font.hasToUnicode ? 'Searchable' : 'No CMap',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: font.hasToUnicode ? Colors.purple : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
