import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pdf_security_service.dart';
import 'theme/dashboard_style_app_bar.dart';
import 'widgets/dashboard_card.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected PDF
  String? _selectedPdfPath;

  // Watermark Options State
  bool _enableWatermark = false;
  bool _isTextWatermark = true;
  final TextEditingController _watermarkTextController =
      TextEditingController(text: 'CONFIDENTIAL');
  String? _watermarkImagePath;
  double _opacity = 0.3;
  final double _fontSize = 48.0;
  final double _rotationAngle = 45.0;

  // Encryption Password State
  bool _enableEncryption = false;
  final TextEditingController _userPasswordController = TextEditingController();
  final TextEditingController _ownerPasswordController = TextEditingController();

  // Decryption State
  String? _encryptedPdfPath;
  final TextEditingController _decryptPasswordController = TextEditingController();

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _watermarkTextController.dispose();
    _userPasswordController.dispose();
    _ownerPasswordController.dispose();
    _decryptPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickWatermarkImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _watermarkImagePath = result.files.single.path;
      });
    }
  }

  Future<void> _applySecurityAndWatermark() async {
    if (_selectedPdfPath == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Protected/Watermarked PDF',
      fileName: 'protected_${p.basename(_selectedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) output = '$output.pdf';
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Applying security and watermark options...';
        _isSuccess = false;
      });

      try {
        WatermarkOptions? watermarkOpt;
        if (_enableWatermark) {
          watermarkOpt = WatermarkOptions(
            isText: _isTextWatermark,
            text: _watermarkTextController.text,
            imagePath: _watermarkImagePath,
            fontSize: _fontSize,
            opacity: _opacity,
            rotationAngleDegree: _rotationAngle,
          );
        }

        await PdfSecurityService.processSecurityOptions(
          inputPdfPath: _selectedPdfPath!,
          outputPdfPath: output,
          watermark: watermarkOpt,
          userPassword: _enableEncryption ? _userPasswordController.text : null,
          ownerPassword: _enableEncryption ? _ownerPasswordController.text : null,
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
          _statusMessage = 'Successfully processed and saved PDF';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Security operation failed: $e';
        });
      }
    }
  }

  Future<void> _removePassword() async {
    if (_encryptedPdfPath == null) return;

    var output = await FilePicker.saveFile(
      dialogTitle: 'Save Unlocked PDF',
      fileName: 'unlocked_${p.basename(_encryptedPdfPath!)}',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      if (!output.toLowerCase().endsWith('.pdf')) output = '$output.pdf';
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusMessage = 'Unlocking password-protected PDF...';
        _isSuccess = false;
      });

      try {
        await PdfSecurityService.removePassword(
          inputPdfPath: _encryptedPdfPath!,
          outputPdfPath: output,
          password: _decryptPasswordController.text,
          onProgress: (cur, tot) {
            setState(() {
              _progress = cur / tot;
              _statusMessage = 'Unlocking page $cur of $tot...';
            });
          },
        );

        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Successfully unlocked and saved to $output';
        });
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Failed to unlock: Invalid password or unsupported encryption.';
        });
      }
    }
  }

  Widget _buildStatusBanner(ThemeData theme) {
    if (_statusMessage.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardStyleAppBar(
        title: const Text('Security & Watermarking'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(PhosphorIconsLight.shieldCheck),
              text: 'Watermark & Encrypt',
            ),
            Tab(
              icon: Icon(PhosphorIconsLight.lockOpen),
              text: 'Remove Password',
            ),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
        ),
      ),
      body: Column(
        children: [
          if (_isProcessing)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEncryptAndWatermarkTab(theme),
                _buildDecryptTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptAndWatermarkTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(theme),

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

          // Watermark Card
          DashboardCard(
            icon: PhosphorIconsLight.stamp,
            iconColor: theme.colorScheme.secondary,
            title: 'Watermark',
            trailing: Switch(
              value: _enableWatermark,
              onChanged: (val) => setState(() => _enableWatermark = val),
            ),
            child: _enableWatermark
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioListTile<bool>(
                        title: const Text('Text Watermark'),
                        value: true,
                        groupValue: _isTextWatermark,
                        onChanged: (val) => setState(() => _isTextWatermark = val!),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isTextWatermark)
                        TextField(
                          controller: _watermarkTextController,
                          decoration: const InputDecoration(
                            labelText: 'Watermark Text',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      RadioListTile<bool>(
                        title: const Text('Image / Logo Watermark'),
                        value: false,
                        groupValue: _isTextWatermark,
                        onChanged: (val) => setState(() => _isTextWatermark = val!),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (!_isTextWatermark)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickWatermarkImage,
                              icon: const Icon(PhosphorIconsLight.image, size: 18),
                              label: const Text('Pick Logo'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _watermarkImagePath != null
                                    ? p.basename(_watermarkImagePath!)
                                    : 'No image selected',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Opacity: ${(_opacity * 100).toInt()}%',
                              style: theme.textTheme.bodySmall),
                          Expanded(
                            child: Slider(
                              value: _opacity,
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              label: '${(_opacity * 100).toInt()}%',
                              onChanged: (val) => setState(() => _opacity = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Text(
                    'Enable to add a text or image watermark to all pages',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          // Encryption Card
          DashboardCard(
            icon: PhosphorIconsLight.lockKey,
            iconColor: theme.colorScheme.primary,
            title: 'Password Protection',
            trailing: Switch(
              value: _enableEncryption,
              onChanged: (val) => setState(() => _enableEncryption = val),
            ),
            child: _enableEncryption
                ? Column(
                    children: [
                      TextField(
                        controller: _userPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'User Password (required to open PDF)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(PhosphorIconsLight.key),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ownerPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Owner Password (permissions control)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(PhosphorIconsLight.keyhole),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Enable to password-protect the output PDF',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_selectedPdfPath != null && !_isProcessing)
                  ? _applySecurityAndWatermark
                  : null,
              icon: const Icon(PhosphorIconsLight.shieldCheck, size: 18),
              label: const Text('Apply Security & Save PDF'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecryptTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildStatusBanner(theme),

          DashboardCard(
            icon: PhosphorIconsLight.lockOpen,
            iconColor: theme.colorScheme.tertiary,
            title: 'Encrypted PDF',
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (res != null) {
                      setState(() => _encryptedPdfPath = res.files.single.path);
                    }
                  },
                  icon: const Icon(PhosphorIconsLight.folderOpen, size: 18),
                  label: const Text('Select Encrypted PDF'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _encryptedPdfPath != null
                        ? p.basename(_encryptedPdfPath!)
                        : 'No file selected',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          DashboardCard(
            icon: PhosphorIconsLight.key,
            iconColor: theme.colorScheme.primary,
            title: 'Password',
            child: TextField(
              controller: _decryptPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter password to unlock',
                border: OutlineInputBorder(),
                prefixIcon: Icon(PhosphorIconsLight.key),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_encryptedPdfPath != null && !_isProcessing)
                  ? _removePassword
                  : null,
              icon: const Icon(PhosphorIconsLight.lockOpen, size: 18),
              label: const Text('Unlock & Save PDF'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
            ),
          ),
        ],
      ),
    );
  }
}

