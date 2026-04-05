import 'dart:async';
import 'dart:convert';

import 'package:academic_async/controllers/routine_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class ImportRoutinePage extends StatefulWidget {
  const ImportRoutinePage({super.key});

  @override
  State<ImportRoutinePage> createState() => _ImportRoutinePageState();
}

class _ImportRoutinePageState extends State<ImportRoutinePage> {
  final RoutineController controller = Get.find<RoutineController>();
  final TextEditingController _urlController = TextEditingController();

  bool _isLoading = false;
  bool _mergeWithExisting = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _setLoadingWhile(Future<void> Function() task) async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await task();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importFromFile() async {
    await _setLoadingWhile(() async {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile file = result.files.single;
      final Uint8List? bytes = file.bytes;
      final String? content = bytes == null
          ? null
          : utf8.decode(bytes, allowMalformed: true);

      if (content == null || content.trim().isEmpty) {
        _showError('The selected file is empty or could not be read.');
        return;
      }

      await _importJson(content);
    });
  }

  Future<void> _importFromUrl() async {
    await _setLoadingWhile(() async {
      final String input = _urlController.text.trim();
      if (input.isEmpty) {
        _showError('Please enter a URL first.');
        return;
      }

      await _importFromUrlValue(input);
    });
  }

  Future<void> _importFromClipboard() async {
    await _setLoadingWhile(() async {
      final ClipboardData? clipboard = await Clipboard.getData('text/plain');
      final String text = clipboard?.text?.trim() ?? '';
      if (text.isEmpty) {
        _showError('No JSON content was found on the clipboard.');
        return;
      }

      await _importJson(text);
    });
  }

  Future<void> _importFromQr() async {
    if (_isLoading) {
      return;
    }

    final String? payload = await Get.to<String>(() => const QrScannerPage());
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    await _setLoadingWhile(() async {
      if (_looksLikeHttpUrl(payload)) {
        await _importFromUrlValue(payload.trim());
      } else {
        await _importJson(payload);
      }
    });
  }

  Future<void> _importFromUrlValue(String input) async {
    final Uri? uri = Uri.tryParse(input);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _showError('Please enter a valid http or https URL.');
      return;
    }

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _showError('The URL request timed out.');
      return;
    } catch (_) {
      _showError('Unable to fetch JSON from the provided URL.');
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _showError('The URL responded with status code ${response.statusCode}.');
      return;
    }

    await _importJson(response.body);
  }

  Future<void> _importJson(String rawJson) async {
    RoutineImportPreview preview;
    try {
      preview = await controller.validateRoutineJson(rawJson);
    } on FormatException catch (error) {
      _showError(error.message);
      return;
    } catch (_) {
      _showError('Unsupported JSON structure.');
      return;
    }

    if (!mounted) {
      return;
    }

    final bool confirmed = await _showConfirmDialog(preview) ?? false;
    if (!mounted || !confirmed) {
      return;
    }

    final RoutineImportResult result = await controller.applyImportedRoutine(
      preview.parsedRoutine,
      mergeWithExisting: _mergeWithExisting,
    );

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      _showError(result.message);
      return;
    }

    Get.snackbar(
      'Import Successful',
      result.message,
      snackPosition: SnackPosition.BOTTOM,
    );
    Get.back();
  }

  Future<bool?> _showConfirmDialog(RoutineImportPreview preview) {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirm Import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periods: ${preview.periodsCount}'),
            Text('Total entries: ${preview.entriesCount}'),
            const SizedBox(height: 12),
            Text(
              _mergeWithExisting
                  ? 'Mode: Merge with the current routine'
                  : 'Mode: Replace the current routine',
            ),
            const SizedBox(height: 12),
            const Text('Do you want to save this routine now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    Get.snackbar(
      'Import Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
    );
  }

  bool _looksLikeHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  Future<void> _copySampleJson() async {
    const String sample = '''
{
  "period1": {
    "monday": "Mathematics",
    "tuesday": "Physics"
  },
  "period2": {
    "wednesday": "English"
  }
}
''';

    await Clipboard.setData(const ClipboardData(text: sample));
    if (!mounted) {
      return;
    }

    Get.snackbar(
      'Template Copied',
      'A sample JSON structure has been copied to the clipboard.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Routine JSON')),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accepted structure',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use either {"period1": {"monday": "Math"}} or {"routine": {...}}.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _copySampleJson,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy sample JSON'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colors.surface,
              child: ListTile(
                leading: Icon(Icons.upload_file_rounded, color: colors.primary),
                trailing: const Icon(Icons.chevron_right_rounded),
                title: const Text('Import from file'),
                subtitle: const Text('Pick a .json file from device storage'),
                onTap: _importFromFile,
              ),
            ),
            Card(
              color: colors.surface,
              child: ListTile(
                leading: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: colors.primary,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                title: const Text('Import from QR code'),
                subtitle: const Text(
                  'Scan JSON content or a URL encoded in a QR',
                ),
                onTap: _importFromQr,
              ),
            ),
            Card(
              color: colors.surface,
              child: ListTile(
                leading: Icon(
                  Icons.content_paste_rounded,
                  color: colors.primary,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                title: const Text('Import from clipboard'),
                subtitle: const Text('Validate and save copied JSON directly'),
                onTap: _importFromClipboard,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Import from URL',
                        hintText: 'https://example.com/routine.json',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _importFromUrl,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Fetch and import'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: colors.surface,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Merge with existing routine'),
                subtitle: const Text(
                  'When enabled, matching period/day values are overwritten and the rest is preserved.',
                ),
                value: _mergeWithExisting,
                onChanged: (bool value) {
                  setState(() => _mergeWithExisting = value);
                },
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    String? value;
    for (final Barcode code in capture.barcodes) {
      final String? raw = code.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        value = raw;
        break;
      }
    }

    if (value == null || value.isEmpty) {
      return;
    }

    _handled = true;
    _scannerController.stop();
    Get.back(result: value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Routine QR')),
      body: MobileScanner(controller: _scannerController, onDetect: _onDetect),
    );
  }
}
