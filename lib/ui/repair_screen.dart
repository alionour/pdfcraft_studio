import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/pdf_repair_diagnostic_service.dart';

class RepairScreen extends StatefulWidget {
  const RepairScreen({super.key});

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen> {
  String? _filePath;
  String? _fileName;
  bool _isLoading = false;
  String? _statusMessage;
  pdfx.PdfController? _pdfController;
  PdfHealthReport? _healthReport;

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _filePath = result.files.single.path;
          _fileName = result.files.single.name;
          _statusMessage = null;
        });

        final bytes = await File(_filePath!).readAsBytes();
        final report = PdfRepairDiagnosticService.diagnosePdfBytes(bytes);

        _pdfController?.dispose();
        _pdfController = null;

        try {
          _pdfController = pdfx.PdfController(
            document: pdfx.PdfDocument.openFile(_filePath!),
          );
        } catch (_) {}

        setState(() {
          _healthReport = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error analyzing file: $e';
      });
    }
  }

  Future<void> _repairAndSave() async {
    if (_filePath == null) return;

    setState(() => _isLoading = true);
    try {
      final outputDir = await FilePicker.getDirectoryPath();
      if (outputDir != null) {
        final outPath = PdfRepairDiagnosticService.formatRepairedFileName(
          '$outputDir/$_fileName',
        );

        final rawBytes = await File(_filePath!).readAsBytes();
        final repairedBytes = PdfRepairDiagnosticService.repairPdfBytes(rawBytes);
        await File(outPath).writeAsBytes(repairedBytes);

        setState(() {
          _isLoading = false;
          _statusMessage = 'Repaired PDF saved successfully to:\n$outPath';
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error repairing file: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Left Diagnostics & Action Sidebar
          SizedBox(
            width: 380,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(right: BorderSide(color: theme.dividerColor)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIconsLight.firstAid,
                          color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PDF Stream Doctor',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Structural syntax linter, header doctor, and EOF / XREF repair utility for damaged PDFs.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: const Icon(PhosphorIconsLight.filePdf),
                    label: Text(_filePath == null ? 'Select PDF Document' : 'Change Document'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),

                  if (_fileName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fileName!,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Version: %PDF-${_healthReport?.pdfVersion ?? "1.4"} | Objects: ${_healthReport?.objectCount ?? 0}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],

                  if (_healthReport != null) ...[
                    const SizedBox(height: 20),
                    // Health Score Gauge Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Document Health',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text(
                                '${_healthReport!.healthScore}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _healthReport!.healthScore >= 90
                                      ? Colors.green
                                      : _healthReport!.healthScore >= 60
                                          ? Colors.orange
                                          : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: _healthReport!.healthScore / 100.0,
                            backgroundColor: theme.dividerColor,
                            color: _healthReport!.healthScore >= 90
                                ? Colors.green
                                : _healthReport!.healthScore >= 60
                                    ? Colors.orange
                                    : Colors.redAccent,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatusBadge(context, 'Header', _healthReport!.hasValidHeader),
                              _buildStatusBadge(context, 'Trailer', _healthReport!.hasValidTrailer),
                              _buildStatusBadge(context, 'EOF Marker', _healthReport!.hasValidEof),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Detected Issues (${_healthReport!.issues.length})',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (_healthReport!.issues.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(PhosphorIconsLight.checkCircle, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No structural anomalies detected. Document adheres to standard PDF specifications.',
                                style: TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._healthReport!.issues.map((issue) {
                        final isCritical = issue.severity == DiagnosticSeverity.critical;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCritical
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCritical
                                    ? PhosphorIconsLight.warningCircle
                                    : PhosphorIconsLight.warning,
                                color: isCritical ? Colors.redAccent : Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      issue.code,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCritical ? Colors.redAccent : Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      issue.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (_filePath == null || _isLoading) ? null : _repairAndSave,
                    icon: const Icon(PhosphorIconsLight.wrench),
                    label: const Text('Repair & Restore Document'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Main Preview / Diagnostic Status Display Area
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _filePath == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsLight.firstAid,
                              size: 64, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            'Select a PDF file to run structural diagnosis & repair corrupted streams',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AspectRatio(
                          aspectRatio: 1 / 1.414,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: _pdfController != null
                                ? pdfx.PdfView(controller: _pdfController!)
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(PhosphorIconsLight.warningOctagon,
                                            size: 48, color: Colors.orange),
                                        const SizedBox(height: 12),
                                        const Text('Document rendering locked due to corrupted streams.'),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Click "Repair & Restore Document" to rebuild header and EOF markers.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String label, bool isOk) {
    return Row(
      children: [
        Icon(
          isOk ? PhosphorIconsLight.checkCircle : PhosphorIconsLight.xCircle,
          size: 16,
          color: isOk ? Colors.green : Colors.redAccent,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isOk ? Colors.green : Colors.redAccent,
          ),
        ),
      ],
    );
  }
}
