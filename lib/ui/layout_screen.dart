import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_layout_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  String? _selectedPdfPath;
  NUpMode _mode = NUpMode.twoUp;
  bool _drawBorders = true;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select Input PDF for N-Up Layout',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = '';
        _isSuccess = false;
      });
    }
  }

  Future<void> _generateLayout() async {
    if (_selectedPdfPath == null) return;

    final defaultName = _mode == NUpMode.twoUp ? '2up_' : '4up_';
    var output = await FilePicker.saveFile(
      dialogTitle: 'Save N-Up Grid PDF As',
      fileName: '$defaultName${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) output = '$output.pdf';

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Building N-Up layout PDF...';
        _isSuccess = false;
      });

      try {
        await PdfLayoutService.generateNUpPdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          mode: _mode,
          drawBorders: _drawBorders,
          onProgress: (curSheet, totSheets) {
            setState(() {
              _progress = curSheet / totSheets;
              _statusMessage = 'Processing sheet $curSheet of $totSheets...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'N-Up layout PDF created successfully';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'N-Up layout creation failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('N-Up Page Grid Layout'),
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

            const SizedBox(height: 20),

            // Layout Options Card
            DashboardCard(
              icon: PhosphorIconsLight.gridFour,
              iconColor: theme.colorScheme.primary,
              title: 'Layout Grid Options',
              child: Column(
                children: [
                  RadioListTile<NUpMode>(
                    title: const Text('2-Up Layout'),
                    subtitle: const Text('2 pages side-by-side per landscape sheet — great for printing'),
                    value: NUpMode.twoUp,
                    groupValue: _mode,
                    onChanged: (val) {
                      if (val != null) setState(() => _mode = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<NUpMode>(
                    title: const Text('4-Up Layout'),
                    subtitle: const Text('4 pages in 2×2 grid — ideal for cheat sheets & slides'),
                    value: NUpMode.fourUp,
                    groupValue: _mode,
                    onChanged: (val) {
                      if (val != null) setState(() => _mode = val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('Draw Page Border Lines'),
                    subtitle: const Text('Adds light grey outline boxes around each page'),
                    value: _drawBorders,
                    onChanged: (val) => setState(() => _drawBorders = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_selectedPdfPath != null && !_isProcessing) ? _generateLayout : null,
                icon: const Icon(PhosphorIconsLight.gridFour, size: 18),
                label: const Text('Generate N-Up Layout PDF'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

