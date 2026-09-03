import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/pdf_table_extractor_service.dart';

class TableExtractorScreen extends StatefulWidget {
  const TableExtractorScreen({super.key});

  @override
  State<TableExtractorScreen> createState() => _TableExtractorScreenState();
}

class _TableExtractorScreenState extends State<TableExtractorScreen> {
  String? _selectedPdfPath;
  List<ExtractedTableData> _extractedTables = [];

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select PDF Document to Extract Tables',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
        _extractedTables.clear();
        _statusMessage = 'Loaded document for table extraction.';
      });
    }
  }

  Future<void> _processExtract() async {
    if (_selectedPdfPath == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Parsing tables from PDF document...';
    });

    try {
      final tables = await PdfTableExtractorService.extractTablesFromPdf(
        inputPdfPath: _selectedPdfPath!,
        onProgress: (cur, tot) {
          setState(() {
            _progress = cur / tot;
            _statusMessage = 'Scanning page $cur of $tot for tabular structures...';
          });
        },
      );

      setState(() {
        _isProcessing = false;
        _extractedTables = tables;
        _statusMessage = 'Extracted tables from ${tables.length} document pages!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Table extraction failed: $e';
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_selectedPdfPath == null || _extractedTables.isEmpty) return;

    final allRows = <List<String>>[];
    for (final table in _extractedTables) {
      allRows.addAll(table.rows);
    }

    final csvContent = PdfTableExtractorService.exportToCsv(allRows);
    final defaultName = PdfTableExtractorService.formatExtractedTableFileName(_selectedPdfPath!, 'csv');

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Extracted CSV Table As',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.csv')) {
        output = '$output.csv';
      }
      final file = File(output);
      await file.writeAsString(csvContent);
      setState(() {
        _statusMessage = 'Exported CSV table to:\n$output';
      });
    }
  }

  Future<void> _exportJson() async {
    if (_selectedPdfPath == null || _extractedTables.isEmpty) return;

    final allRows = <List<String>>[];
    for (final table in _extractedTables) {
      allRows.addAll(table.rows);
    }

    final jsonContent = PdfTableExtractorService.exportToJson(allRows);
    final defaultName = PdfTableExtractorService.formatExtractedTableFileName(_selectedPdfPath!, 'json');

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Extracted JSON Table As',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.json')) {
        output = '$output.json';
      }
      final file = File(output);
      await file.writeAsString(jsonContent);
      setState(() {
        _statusMessage = 'Exported JSON table to:\n$output';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Page Table Extractor & CSV Converter'),
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
                            ? p.basename(_selectedPdfPath!)
                            : 'No PDF selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedPdfPath != null)
                      ElevatedButton.icon(
                        onPressed: _processExtract,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Scan & Extract Tables'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_extractedTables.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.download),
                      label: const Text('Export to CSV'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportJson,
                      icon: const Icon(Icons.code),
                      label: const Text('Export to JSON'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Extracted Table Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._extractedTables.map((tbl) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Page ${tbl.pageNumber} Table',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: tbl.rows.first
                                .map((col) => DataColumn(label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold))))
                                .toList(),
                            rows: tbl.rows
                                .skip(1)
                                .map((row) => DataRow(cells: row.map((cell) => DataCell(Text(cell))).toList()))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
