import 'package:academic_async/services/attendance_location_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AttendanceScanPage extends StatefulWidget {
  const AttendanceScanPage({super.key});

  @override
  State<AttendanceScanPage> createState() => _AttendanceScanPageState();
}

class _AttendanceScanPageState extends State<AttendanceScanPage> {
  bool _didScan = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Attendance QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_didScan) {
                return;
              }
              final Barcode? barcode = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first
                  : null;
              final String raw = barcode?.rawValue?.trim() ?? '';
              if (raw.isEmpty) {
                return;
              }
              _didScan = true;
              Get.back<String>(result: raw);
            },
            errorBuilder: (context, error) {
              final bool permissionDenied =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: colors.onPrimary,
                          size: 34,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          permissionDenied
                              ? 'Camera permission is required to scan attendance QR.'
                              : 'Camera is unavailable right now.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () => Get.back<void>(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.onPrimary,
                              ),
                              child: const Text('Close'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                await AttendanceLocationService.openApplicationSettings();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.all(16),
              child: Text(
                'Align the QR inside camera frame',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
