import 'package:academic_async/services/attendance_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.data});

  final String data;

  Future<void> _openUrl(String text) async {
    if (!AttendanceGuard.canProceed(actionLabel: 'opening external links')) {
      return;
    }
    final Uri? url = Uri.tryParse(text);
    if (url == null) {
      Get.snackbar('Link', 'Invalid link');
      return;
    }

    final bool opened = await url_launcher.launchUrl(
      url,
      mode: url_launcher.LaunchMode.externalApplication,
    );
    if (!opened) {
      Get.snackbar('Link', 'Could not open the link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Get.theme;
    final ColorScheme colors = theme.colorScheme;
    final String normalizedData = data.replaceAll('\r\n', '\n').trim();

    if (normalizedData.isEmpty) {
      return Text(
        'No release notes available.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    return MarkdownBody(
      data: normalizedData,
      onTapLink: (text, href, title) {
        if (href != null) {
          _openUrl(href);
        }
      },
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p:
            theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.5,
              color: colors.onSurface,
            ) ??
            TextStyle(fontSize: 14, height: 1.5, color: colors.onSurface),
        h1: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colors.primary,
        ),
        h2: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        h3: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        listBullet: const TextStyle(fontSize: 14),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          fontStyle: FontStyle.italic,
          color: colors.onSurfaceVariant,
        ),
        a: TextStyle(
          color: colors.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      imageBuilder: (uri, title, alt) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(uri.toString(), fit: BoxFit.cover),
          ),
        );
      },
      softLineBreak: true,
      shrinkWrap: true,
    );
  }
}
