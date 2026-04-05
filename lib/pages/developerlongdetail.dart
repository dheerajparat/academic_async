import 'package:academic_async/models/developer_profile.dart';
import 'package:academic_async/widgets/settings/community_link_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeveloperLongDetail extends StatelessWidget {
  const DeveloperLongDetail({
    super.key,
    required this.id,
    required this.developer,
    required this.imageUrl,
  });

  final String id;
  final DeveloperProfile developer;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Uri? emailUri = developer.emailUri;
    final Uri? githubUri = developer.githubUri;

    return Scaffold(
      appBar: AppBar(
        title: Text(developer.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: 'image_$id',
              child: CircleAvatar(
                radius: Get.width / 3,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
                child: imageUrl == null ? const Icon(Icons.person) : null,
              ),
            ),
            const SizedBox(height: 24),
            Hero(
              tag: 'name_$id',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  developer.name,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  if (developer.email.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: emailUri == null
                          ? Text(developer.email)
                          : CommunityLinkText(
                              label: developer.email,
                              onTap: () => launchCommunityUri(
                                emailUri,
                                label: developer.email,
                              ),
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
                  if (developer.email.isNotEmpty && developer.github.isNotEmpty)
                    const Divider(height: 1),
                  if (developer.github.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.code_rounded),
                      title: githubUri == null
                          ? Text(developer.githubDisplayLabel)
                          : CommunityLinkText(
                              label: developer.githubDisplayLabel,
                              onTap: () => launchCommunityUri(
                                githubUri,
                                label: 'GitHub',
                              ),
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                      subtitle: githubUri == null
                          ? null
                          : CommunityLinkText(
                              label: githubUri.toString(),
                              onTap: () => launchCommunityUri(
                                githubUri,
                                label: 'GitHub',
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
