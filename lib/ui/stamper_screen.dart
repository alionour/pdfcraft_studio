import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_stamper_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class StamperScreen extends StatefulWidget {
  const StamperScreen({super.key});

  @override
  State<StamperScreen> createState() => _StamperScreenState();
}

class _StamperScreenState extends State<StamperScreen> {
  String? _selectedPdfPath;
  final TextEditingController _stampTextController =
      TextEditingController(text: 'Page {page} of {total}');
  final TextEditingController _pageRangeController =
      TextEditingController(text: 'all');

  StampPosition _position = StampPosition.footerRight;
  double _fontSize = 10.0;
  PdfColor _color = PdfColors.black;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void dispose() {
    _stampTextController.dispose();
    _pageRangeController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select Input PDF to Stamp',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _statusMessage = '';
        _isSuccess = false;
      });
    }
  }

  Future<void> _applyStamp() async {
    if (_selectedPdfPath == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Stamped PDF As',
      fileName: 'stamped_${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) output = '$output.pdf';

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Stamping page numbers and headers...';
        _isSuccess = false;
      });

      try {
        final options = StampOptions(
          text: _stampTextController.text,
          position: _position,
          fontSize: _fontSize,
          color: _color,
          pageRange: _pageRangeController.text,
        );

        await PdfStamperService.stampPdf(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          options: options,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Stamping page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Stamped PDF saved successfully';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Stamping failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('Page Numbering & Headers'),
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

            // Stamp Options Card
            DashboardCard(
              icon: PhosphorIconsLight.hash,
              iconColor: theme.colorScheme.primary,
              title: 'Stamp Text & Variables',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _stampTextController,
                    decoration: const InputDecoration(
                      labelText: 'Stamp Content / Template',
                      hintText: 'e.g. Page {page} of {total} or Confidential',
                      helperText: 'Available variables: {page}, {total}, {pdf_name}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<StampPosition>(
                          value: _position,
                          decoration: const InputDecoration(
                            labelText: 'Position',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: StampPosition.headerLeft,
                              child: Text('Header - Left'),
                            ),
                            DropdownMenuItem(
                              value: StampPosition.headerCenter,
                              child: Text('Header - Center'),
                            ),
                            DropdownMenuItem(
                              value: StampPosition.headerRight,
                              child: Text('Header - Right'),
                            ),
                            DropdownMenuItem(
                              value: StampPosition.footerLeft,
                              child: Text('Footer - Left'),
                            ),
                            DropdownMenuItem(
                              value: StampPosition.footerCenter,
                              child: Text('Footer - Center'),
                            ),
                            DropdownMenuItem(
                              value: StampPosition.footerRight,
                              child: Text('Footer - Right'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _position = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: _fontSize,
                          decoration: const InputDecoration(
                            labelText: 'Font Size',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 8.0, child: Text('8 pt')),
                            DropdownMenuItem(value: 10.0, child: Text('10 pt')),
                            DropdownMenuItem(value: 12.0, child: Text('12 pt')),
                            DropdownMenuItem(value: 14.0, child: Text('14 pt')),
                            DropdownMenuItem(value: 16.0, child: Text('16 pt')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _fontSize = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pageRangeController,
                    decoration: const InputDecoration(
                      labelText: 'Page Range to Stamp',
                      hintText: 'all, 1-5, 2,4',
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
                onPressed: (_selectedPdfPath != null && !_isProcessing) ? _applyStamp : null,
                icon: const Icon(PhosphorIconsLight.hash, size: 18),
                label: const Text('Apply Stamps & Save PDF'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

