import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/conversion_options.dart';
import '../services/image_to_pdf_service.dart';
import '../services/pdf_converter_service.dart';

enum ConversionMode { pdfToImages, imagesToPdf }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ConversionMode _mode = ConversionMode.pdfToImages;

  // PDF to Image controllers
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final TextEditingController _pageRangeController =
      TextEditingController(text: 'all');

  // Images to PDF controllers & state
  List<String> _selectedImagePaths = [];
  final TextEditingController _imgPdfOutputController = TextEditingController();

  ConversionOptions _options = const ConversionOptions();
  bool _isConverting = false;
  bool _isDragging = false;
  double _progress = 0.0;
  String _statusText = 'Ready to convert';
  String? _lastOutputPath;
  PdfController? _pdfPreviewController;

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    _pageRangeController.dispose();
    _imgPdfOutputController.dispose();
    _pdfPreviewController?.dispose();
    super.dispose();
  }

  void _onInputChanged(String val) {
    _updatePreviewController(val.trim());
  }

  void _updatePreviewController(String inputPath) {
    _pdfPreviewController?.dispose();
    _pdfPreviewController = null;

    if (inputPath.isNotEmpty &&
        FileSystemEntity.isFileSync(inputPath) &&
        inputPath.toLowerCase().endsWith('.pdf')) {
      setState(() {
        _pdfPreviewController = PdfController(
          document: PdfDocument.openFile(inputPath),
        );
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _browseInputFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Select Input PDF File',
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      _inputController.text = selectedPath;
      _onInputChanged(selectedPath);

      if (_outputController.text.isEmpty) {
        final parent = p.dirname(selectedPath);
        final baseName = p.basenameWithoutExtension(selectedPath);
        _outputController.text = p.join(parent, "${baseName}_images");
      }
    }
  }

  Future<void> _browseInputFolder() async {
    final selectedFolder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Folder Containing PDFs',
    );

    if (selectedFolder != null) {
      _inputController.text = selectedFolder;
      _onInputChanged(selectedFolder);

      if (_outputController.text.isEmpty) {
        _outputController.text = p.join(selectedFolder, "converted_images");
      }
    }
  }

  Future<void> _browseOutputFolder() async {
    final selectedFolder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Output Destination Folder',
    );

    if (selectedFolder != null) {
      _outputController.text = selectedFolder;
    }
  }

  // Images to PDF Pickers
  Future<void> _browseImages() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      dialogTitle: 'Select Images to Combine',
    );

    if (result != null) {
      final paths = result.files.map((f) => f.path).whereType<String>().toList();
      setState(() {
        _selectedImagePaths = [..._selectedImagePaths, ...paths];
      });

      if (_imgPdfOutputController.text.isEmpty && paths.isNotEmpty) {
        final parent = p.dirname(paths.first);
        _imgPdfOutputController.text = p.join(parent, "combined_document.pdf");
      }
    }
  }

  Future<void> _browseImgPdfOutput() async {
    var result = await FilePicker.saveFile(
      dialogTitle: 'Save Compiled PDF As',
      fileName: 'combined_document.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      if (!result.toLowerCase().endsWith('.pdf')) {
        result = '$result.pdf';
      }
      _imgPdfOutputController.text = result;
    }
  }

  Future<void> _openOutputInExplorer(String targetPath) async {
    final path = FileSystemEntity.isDirectorySync(targetPath)
        ? targetPath
        : p.dirname(targetPath);
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else {
      final uri = Uri.directory(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _startConversion() async {
    if (_mode == ConversionMode.pdfToImages) {
      await _startPdfToImageConversion();
    } else {
      await _startImageToPdfConversion();
    }
  }

  Future<void> _startPdfToImageConversion() async {
    final inputPath = _inputController.text.trim();
    final outputPath = _outputController.text.trim();

    final inputType = await FileSystemEntity.type(inputPath);
    if (inputPath.isEmpty || inputType == FileSystemEntityType.notFound) {
      _showErrorDialog('Please select a valid input PDF file or folder.');
      return;
    }

    if (outputPath.isEmpty) {
      _showErrorDialog('Please select a valid output destination folder.');
      return;
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _statusText = 'Starting conversion...';
      _lastOutputPath = outputPath;
      _options = _options.copyWith(pageRange: _pageRangeController.text);
    });

    try {
      if (FileSystemEntity.isFileSync(inputPath)) {
        final savedFiles = await PdfConverterService.convertPdfFile(
          pdfPath: inputPath,
          outputDir: outputPath,
          options: _options,
          onProgress: (current, total, savedPath) {
            setState(() {
              _progress = current / total;
              _statusText =
                  'Saved page $current/$total: ${p.basename(savedPath)}';
            });
          },
        );

        setState(() {
          _progress = 1.0;
          _statusText = 'Conversion Complete!';
        });

        _showSuccessDialog(
          'Successfully converted ${savedFiles.length} image(s) to:\n$outputPath',
          outputPath,
        );
      } else if (FileSystemEntity.isDirectorySync(inputPath)) {
        final results = await PdfConverterService.convertDirectory(
          inputDir: inputPath,
          outputDir: outputPath,
          options: _options,
          onProgress: (fileName, current, total, savedPath) {
            setState(() {
              _statusText = 'Processing $fileName ($current/$total)';
            });
          },
        );

        final totalImages =
            results.values.fold(0, (sum, list) => sum + list.length);

        setState(() {
          _progress = 1.0;
          _statusText = 'Conversion Complete!';
        });

        _showSuccessDialog(
          'Successfully converted ${results.length} PDF file(s) into $totalImages image(s) to:\n$outputPath',
          outputPath,
        );
      }
    } catch (e) {
      setState(() {
        _progress = 0.0;
        _statusText = 'Error occurred during conversion.';
      });
      _showErrorDialog('Conversion failed:\n$e');
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  Future<void> _startImageToPdfConversion() async {
    if (_selectedImagePaths.isEmpty) {
      _showErrorDialog('Please select at least one image file.');
      return;
    }

    final outputPath = _imgPdfOutputController.text.trim();
    if (outputPath.isEmpty) {
      _showErrorDialog('Please specify an output PDF file path.');
      return;
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _statusText = 'Creating PDF from images...';
      _lastOutputPath = outputPath;
    });

    try {
      final savedPdf = await ImageToPdfService.convertImagesToPdf(
        imagePaths: _selectedImagePaths,
        outputPdfPath: outputPath,
        onProgress: (current, total, imagePath) {
          setState(() {
            _progress = current / total;
            _statusText = 'Added image $current/$total: ${p.basename(imagePath)}';
          });
        },
      );

      setState(() {
        _progress = 1.0;
        _statusText = 'PDF Generation Complete!';
      });

      _showSuccessDialog(
        'Successfully combined ${_selectedImagePaths.length} image(s) into PDF:\n$savedPdf',
        savedPdf,
      );
    } catch (e) {
      setState(() {
        _progress = 0.0;
        _statusText = 'Error generating PDF.';
      });
      _showErrorDialog('PDF creation failed:\n$e');
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(PhosphorIconsLight.warningCircle, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message, String outputFolder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(PhosphorIconsLight.checkCircle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openOutputInExplorer(outputFolder);
            },
            icon: const Icon(PhosphorIconsLight.folderOpen),
            label: const Text('Open Folder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DropTarget(
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          if (details.files.isNotEmpty) {
            final paths = details.files.map((f) => f.path).toList();
            if (_mode == ConversionMode.pdfToImages) {
              _inputController.text = paths.first;
              _onInputChanged(paths.first);
            } else {
              setState(() {
                _selectedImagePaths = [..._selectedImagePaths, ...paths];
              });
            }
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Flat, borderless header banner matching dr_copilot's
                // DashboardStyleAppBar: background blends into the page,
                // no elevation, bold flush-left title.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsLight.arrowsLeftRight,
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Convert Hub',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Convert PDFs into high-resolution images or compile images into PDF documents',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Pill Segmented Mode Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeTab(
                              mode: ConversionMode.pdfToImages,
                              icon: PhosphorIconsLight.filePdf,
                              label: 'PDF ➔ Images',
                              theme: theme,
                            ),
                            const SizedBox(width: 4),
                            _buildModeTab(
                              mode: ConversionMode.imagesToPdf,
                              icon: PhosphorIconsLight.images,
                              label: 'Images ➔ PDF',
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Body
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _mode == ConversionMode.pdfToImages
                        ? _buildPdfToImagesView(theme)
                        : _buildImagesToPdfView(theme),
                  ),
                ),
              ],
            ),

            // Drag & Drop Overlay
            if (_isDragging)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: theme.colorScheme.primary.withValues(alpha: 0.92),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsLight.cloudArrowUp,
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Drop PDF or Image files here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Files will be loaded instantly into the converter queue',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required ConversionMode mode,
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Mode 1: PDF to Images View ---
  Widget _buildPdfToImagesView(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Controls Panel
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  stepNumber: '1',
                  title: 'Select Input Source',
                  icon: PhosphorIconsLight.folderOpen,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onChanged: _onInputChanged,
                          decoration: const InputDecoration(
                            hintText: 'Select PDF file or drag & drop here...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _browseInputFile,
                        icon: const Icon(PhosphorIconsLight.file, size: 18),
                        label: const Text('File'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _browseInputFolder,
                        icon: const Icon(PhosphorIconsLight.folder, size: 18),
                        label: const Text('Folder'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _buildCard(
                  stepNumber: '2',
                  title: 'Output Destination',
                  icon: PhosphorIconsLight.export,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _outputController,
                          decoration: const InputDecoration(
                            hintText: 'Select output folder path...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _browseOutputFolder,
                        icon: const Icon(PhosphorIconsLight.folderPlus, size: 18),
                        label: const Text('Browse'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _buildCard(
                  stepNumber: '3',
                  title: 'Quality & Format Options',
                  icon: PhosphorIconsLight.slidersHorizontal,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _options.format,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Export Format',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'png', child: Text('PNG (Lossless)')),
                                DropdownMenuItem(value: 'jpeg', child: Text('JPEG (Compressed)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _options = _options.copyWith(format: val);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _options.dpi,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Resolution (DPI)',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 72, child: Text('72 DPI (Web/Low)')),
                                DropdownMenuItem(value: 150, child: Text('150 DPI (Standard)')),
                                DropdownMenuItem(value: 300, child: Text('300 DPI (High Print)')),
                                DropdownMenuItem(value: 600, child: Text('600 DPI (Ultra HD)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _options = _options.copyWith(dpi: val);
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pageRangeController,
                        decoration: const InputDecoration(
                          labelText: 'Page Selection / Range',
                          hintText: 'e.g. all, 1-5, 2, 4, 8-10',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Transparent background',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Preserves transparency for PNG output. Defaults to solid white.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _options.transparent,
                          onChanged: _options.format.toLowerCase() == 'png'
                              ? (val) {
                                  setState(() {
                                    _options = _options.copyWith(transparent: val);
                                  });
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildProgressAndConvertButton('Convert PDF to Images'),
              ],
            ),
          ),
        ),

        // Right Preview Panel
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(PhosphorIconsLight.eye, color: theme.colorScheme.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Live PDF Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),

                      if (_pdfPreviewController != null) ...[
                        PdfPageNumber(
                          controller: _pdfPreviewController!,
                          builder: (context, loadingState, page, pagesCount) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                'Page $page / ${pagesCount ?? 0}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),

                        IconButton(
                          icon: const Icon(PhosphorIconsLight.caretLeft),
                          tooltip: 'Previous Page',
                          color: theme.colorScheme.onSurface,
                          onPressed: () {
                            _pdfPreviewController?.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          },
                        ),

                        IconButton(
                          icon: const Icon(PhosphorIconsLight.caretRight),
                          tooltip: 'Next Page',
                          color: theme.colorScheme.onSurface,
                          onPressed: () {
                            _pdfPreviewController?.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _pdfPreviewController != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: PdfView(
                            controller: _pdfPreviewController!,
                            scrollDirection: Axis.vertical,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIconsLight.filePdf,
                                  size: 48,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Document Selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select a PDF file on the left to render page preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Mode 2: Images to PDF View ---
  Widget _buildImagesToPdfView(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Image Selector & Options
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  stepNumber: '1',
                  title: 'Select Source Images',
                  icon: PhosphorIconsLight.images,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _browseImages,
                            icon: const Icon(PhosphorIconsLight.imageSquare, size: 18),
                            label: const Text('Add Image Files'),
                          ),
                          const SizedBox(width: 12),
                          if (_selectedImagePaths.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _selectedImagePaths.clear()),
                              icon: const Icon(PhosphorIconsLight.trash, size: 18, color: Colors.redAccent),
                              label: const Text('Clear Queue', style: TextStyle(color: Colors.redAccent)),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_selectedImagePaths.length} Image(s)',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _buildCard(
                  stepNumber: '2',
                  title: 'Output Destination File',
                  icon: PhosphorIconsLight.filePdf,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _imgPdfOutputController,
                          decoration: const InputDecoration(
                            hintText: 'Select destination file path (e.g., document.pdf)...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _browseImgPdfOutput,
                        icon: const Icon(PhosphorIconsLight.floppyDisk, size: 18),
                        label: const Text('Save As'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildProgressAndConvertButton('Compile Images into PDF'),
              ],
            ),
          ),
        ),

        // Right Image Queue Preview Panel
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(PhosphorIconsLight.imagesSquare, color: theme.colorScheme.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Image Page Queue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Drag & Drop supported',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _selectedImagePaths.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _selectedImagePaths.length,
                          itemBuilder: (ctx, idx) {
                            final path = _selectedImagePaths[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(path),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Icon(PhosphorIconsLight.imageBroken),
                                  ),
                                ),
                                title: Text(
                                  p.basename(path),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'PDF Page #${idx + 1}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(PhosphorIconsLight.x, size: 18),
                                  color: Colors.redAccent.withValues(alpha: 0.8),
                                  tooltip: 'Remove',
                                  onPressed: () {
                                    setState(() {
                                      _selectedImagePaths.removeAt(idx);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIconsLight.imageSquare,
                                  size: 48,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Images Added',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add images to combine into a compiled PDF document',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressAndConvertButton(String buttonText) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _isConverting ? _progress : 0.0,
              backgroundColor: theme.dividerColor,
              color: theme.colorScheme.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _isConverting ? PhosphorIconsLight.arrowsClockwise : PhosphorIconsLight.info,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              if (_lastOutputPath != null && !_isConverting)
                TextButton.icon(
                  onPressed: () => _openOutputInExplorer(_lastOutputPath!),
                  icon: const Icon(PhosphorIconsLight.folderOpen, size: 16),
                  label: const Text('Open Folder', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isConverting ? null : _startConversion,
              icon: _isConverting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(PhosphorIconsLight.lightning, size: 24),
              label: Text(
                _isConverting ? 'Processing Conversion...' : buttonText,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String stepNumber,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}


