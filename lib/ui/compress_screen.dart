import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_compress_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _selectedPdfPath;
  int? _originalSizeBytes;

  CompressionPreset _selectedPreset = CompressionPreset.medium;
  double _customDpi = 150.0;

  bool _isCompressing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final file = File(path);
      final size = await file.length();

      setState(() {
        _selectedPdfPath = path;
        _originalSizeBytes = size;
        _statusMessage = '';
        _isSuccess = false;
      });
    }
  }

  Future<void> _runCompression() async {
    if (_selectedPdfPath == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Compressed PDF',
      fileName: 'compressed_${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) {
        output = '$output.pdf';
      }
      setState(() {
        _isCompressing = true;
        _progress = 0.0;
        _statusMessage = 'Compressing PDF file...';
        _isSuccess = false;
      });

      try {
        await PdfCompressService.compressPdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          preset: _selectedPreset,
          customDpi: _customDpi,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Compressing page $cur of $tot...';
            });
          },
        );

        final newFile = File(output);
        final newSize = await newFile.length();
        final reductionPct = _originalSizeBytes != null && _originalSizeBytes! > 0
            ? (((_originalSizeBytes! - newSize) / _originalSizeBytes!) * 100).toStringAsFixed(1)
            : '0';

        setState(() {
          _isCompressing = false;
          _isSuccess = true;
          _statusMessage =
              'Reduced from ${_formatBytes(_originalSizeBytes!)} to ${_formatBytes(newSize)} (−$reductionPct%)';
        });
      } catch (e) {
        setState(() {
          _isCompressing = false;
          _isSuccess = false;
          _statusMessage = 'Compression failed: $e';
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('PDF Compression'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress + Status Banner
            if (_isCompressing)
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
                        _isSuccess ? PhosphorIconsLight.checkCircle : PhosphorIconsLight.warningCircle,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPdfPath != null
                              ? p.basename(_selectedPdfPath!)
                              : 'No file selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_originalSizeBytes != null)
                          Text(
                            'Original size: ${_formatBytes(_originalSizeBytes!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Compression Level Card
            DashboardCard(
              icon: PhosphorIconsLight.arrowsInLineHorizontal,
              iconColor: theme.colorScheme.primary,
              title: 'Compression Level',
              child: Column(
                children: [
                  RadioListTile<CompressionPreset>(
                    title: const Text('Web Quality (Maximum Compression)'),
                    subtitle: const Text('72 DPI — ideal for email & web sharing'),
                    value: CompressionPreset.web,
                    groupValue: _selectedPreset,
                    onChanged: (val) => setState(() => _selectedPreset = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<CompressionPreset>(
                    title: const Text('Medium Quality (Recommended)'),
                    subtitle: const Text('150 DPI — balanced sharpness & file size'),
                    value: CompressionPreset.medium,
                    groupValue: _selectedPreset,
                    onChanged: (val) => setState(() => _selectedPreset = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<CompressionPreset>(
                    title: const Text('High Quality (Minimal Compression)'),
                    subtitle: const Text('200 DPI — preserves HD graphics & crisp layout'),
                    value: CompressionPreset.high,
                    groupValue: _selectedPreset,
                    onChanged: (val) => setState(() => _selectedPreset = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<CompressionPreset>(
                    title: const Text('Custom DPI Scale'),
                    subtitle: _selectedPreset == CompressionPreset.custom
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target DPI: ${_customDpi.round()}'),
                              Slider(
                                value: _customDpi,
                                min: 50,
                                max: 300,
                                divisions: 25,
                                label: '${_customDpi.round()} DPI',
                                onChanged: (val) => setState(() => _customDpi = val),
                              ),
                            ],
                          )
                        : const Text('Specify exact custom rendering resolution'),
                    value: CompressionPreset.custom,
                    groupValue: _selectedPreset,
                    onChanged: (val) => setState(() => _selectedPreset = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_selectedPdfPath != null && !_isCompressing) ? _runCompression : null,
                icon: const Icon(PhosphorIconsLight.arrowsInLineHorizontal, size: 18),
                label: const Text('Compress PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

