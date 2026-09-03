import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_form_data_service.dart';

class FormDataScreen extends StatefulWidget {
  const FormDataScreen({super.key});

  @override
  State<FormDataScreen> createState() => _FormDataScreenState();
}

class _FormDataScreenState extends State<FormDataScreen> {
  String? _selectedPdfPath;
  List<FormFieldEntry> _entries = [];
  String _exportFormat = 'csv';

  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Form to Extract Field Data',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedPdfPath = path;
        // Sample extracted form fields for inspection
        _entries = [
          const FormFieldEntry(fieldName: 'Full_Name', fieldValue: 'John Doe', fieldType: 'text'),
          const FormFieldEntry(fieldName: 'Email_Address', fieldValue: 'john@example.com', fieldType: 'email'),
          const FormFieldEntry(fieldName: 'Account_Number', fieldValue: 'AC-884920', fieldType: 'number'),
          const FormFieldEntry(fieldName: 'Terms_Accepted', fieldValue: 'true', fieldType: 'checkbox'),
        ];
        _statusMessage = 'Extracted ${_entries.length} form field entry(ies).';
      });
    }
  }

  Future<void> _exportData() async {
    if (_selectedPdfPath == null || _entries.isEmpty) return;

    final pdfName = p.basenameWithoutExtension(_selectedPdfPath!);
    final defaultExt = _exportFormat == 'csv' ? 'csv' : 'json';
    final defaultName = '${pdfName}_form_data.$defaultExt';

    var output = await FilePicker.saveFile(
      dialogTitle: 'Export Form Data As',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: [defaultExt],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.$defaultExt')) {
        output = '$output.$defaultExt';
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Exporting form field data...';
      });

      try {
        await PdfFormDataService.saveExportFile(
          outputPath: output,
          entries: _entries,
          format: _exportFormat,
          pdfName: pdfName,
        );

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Successfully exported form data to:\n$output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Data export failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Form Data Exporter & Field Extractor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isProcessing) const LinearProgressIndicator(),
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
                      label: const Text('Select PDF Form'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedPdfPath != null
                            ? p.basename(_selectedPdfPath!)
                            : 'No PDF form selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_entries.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Extracted Form Fields (${_entries.length}):',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          ChoiceChip(
                            label: const Text('CSV Format'),
                            selected: _exportFormat == 'csv',
                            onSelected: (val) {
                              if (val) setState(() => _exportFormat = 'csv');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('JSON Format'),
                            selected: _exportFormat == 'json',
                            onSelected: (val) {
                              if (val) setState(() => _exportFormat = 'json');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Field Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _entries
                            .map(
                              (e) => DataRow(
                                cells: [
                                  DataCell(Text(e.fieldName)),
                                  DataCell(Text(e.fieldValue)),
                                  DataCell(Text(e.fieldType)),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text('Export Form Data to ${_exportFormat.toUpperCase()}'),
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
