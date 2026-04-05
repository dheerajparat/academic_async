import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchCommunityUri(
  Uri uri, {
  required String label,
}) async {
  final List<LaunchMode> modes = switch (uri.scheme) {
    'http' || 'https' => const <LaunchMode>[
      LaunchMode.platformDefault,
      LaunchMode.externalApplication,
    ],
    _ => const <LaunchMode>[
      LaunchMode.platformDefault,
      LaunchMode.externalApplication,
    ],
  };

  for (final LaunchMode mode in modes) {
    try {
      final bool launched = await launchUrl(uri, mode: mode);
      if (launched) {
        return;
      }
    } catch (_) {
      // Try the next mode.
    }
  }

  Get.snackbar('Community', 'Unable to open $label');
}

class CommunityLinkText extends StatelessWidget {
  const CommunityLinkText({
    super.key,
    required this.label,
    required this.onTap,
    this.style,
    this.textAlign,
  });

  final String label;
  final VoidCallback? onTap;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final TextStyle linkStyle =
        style ??
        Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          textAlign: textAlign,
          style: linkStyle,
        ),
      ),
    );
  }
}
