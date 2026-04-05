import 'package:academic_async/models/developer_profile.dart';
import 'package:academic_async/pages/developerlongdetail.dart';
import 'package:academic_async/widgets/settings/community_link_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class CommunityGroup extends StatelessWidget {
  const CommunityGroup({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.developers,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<DeveloperProfile> developers;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SettingsGroup(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading developers...'),
              ],
            ),
          ),
        ],
      );
    }

    if (errorMessage != null && developers.isEmpty) {
      return SettingsGroup(
        children: [
          ListTile(
            leading: const Icon(Icons.error_outline_rounded),
            title: const Text('Unable to load developers'),
            subtitle: Text(errorMessage!),
          ),
        ],
      );
    }

    if (developers.isEmpty) {
      return const SettingsGroup(
        children: [
          ListTile(
            leading: Icon(Icons.group_off_rounded),
            title: Text('No developers found'),
            subtitle: Text(
              'Unable to load developers name, due to internet issue or else.',
            ),
          ),
        ],
      );
    }
    final bool hasStatusMessage = errorMessage != null && developers.isNotEmpty;

    return SettingsGroup(
      children: [
        if (hasStatusMessage) ...[
          ListTile(
            leading: const Icon(Icons.cloud_off_rounded),
            title: const Text('Offline mode'),
            subtitle: Text(errorMessage!),
          ),
          const Divider(height: 1),
        ],
        ExpansionTile(
          title: const Text('Developer Team'),
          leading: const CircleAvatar(child: Icon(Icons.people)),
          subtitle: Text('${developers.length} member(s)'),
          children: [
            for (int i = 0; i < developers.length; i++) ...[
              DeveloperTile(developer: developers[i]),
              if (i < developers.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ],
    );
  }
}

class DeveloperTile extends StatelessWidget {
  const DeveloperTile({super.key, required this.developer});

  final DeveloperProfile developer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String? avatarUrl = developer.githubAvatarUrl(size: 1000);
    final Uri? emailUri = developer.emailUri;
    final Uri? githubUri = developer.githubUri;
    final bool hasSubtitleLinks = emailUri != null || githubUri != null;
    final List<String> fallbackSubtitleLines = <String>[
      if (developer.email.isNotEmpty && emailUri == null) developer.email,
      if (developer.github.isNotEmpty && githubUri == null)
        'GitHub: ${developer.githubDisplayLabel}',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                developer.initials,
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Hero(
        tag: 'name_${developer.heroTagKey}',
        child: Material(
          color: Colors.transparent,
          child: Text(
            developer.name,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fallbackSubtitleLines.isNotEmpty || !hasSubtitleLinks)
              Text(
                fallbackSubtitleLines.isEmpty
                    ? 'Developer profile'
                    : fallbackSubtitleLines.join('\n'),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            if (emailUri != null) ...[
              const SizedBox(height: 6),
              CommunityLinkText(
                label: developer.email,
                onTap: () => launchCommunityUri(
                  emailUri,
                  label: developer.email,
                ),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                  height: 1.4,
                ),
              ),
            ],
            if (githubUri != null) ...[
              const SizedBox(height: 4),
              CommunityLinkText(
                label: 'GitHub: ${developer.githubDisplayLabel}',
                onTap: () => launchCommunityUri(
                  githubUri,
                  label: 'GitHub',
                ),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
      isThreeLine:
          fallbackSubtitleLines.length > 1 || emailUri != null || githubUri != null,
      trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
      onTap: () {
        Get.bottomSheet(
          _buildBottomSheet(context, avatarUrl, colorScheme, textTheme),
          isScrollControlled: true,
        );
      },
    );
  }

  Widget _buildBottomSheet(
    BuildContext context,
    String? avatarUrl,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          InkWell(
            onTap: () => Get.to(
              DeveloperLongDetail(
                id: developer.heroTagKey,
                developer: developer,
                imageUrl: avatarUrl,
              ),
            ),
            child: Hero(
              tag: 'image_${developer.heroTagKey}',
              child: CircleAvatar(
                radius: 80,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(developer.initials, style: textTheme.headlineMedium)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            developer.name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (developer.email.isNotEmpty)
            ListTile(
              leading: Icon(Icons.email_outlined, color: colorScheme.primary),
              title: developer.emailUri == null
                  ? Text(developer.email, style: textTheme.bodyLarge)
                  : CommunityLinkText(
                      label: developer.email,
                      onTap: () => launchCommunityUri(
                        developer.emailUri!,
                        label: developer.email,
                      ),
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
              dense: true,
            ),
          if (developer.github.isNotEmpty)
            ListTile(
              leading: Icon(Icons.code_rounded, color: colorScheme.primary),
              title: developer.githubUri == null
                  ? Text(
                      developer.githubDisplayLabel,
                      style: textTheme.bodyLarge,
                    )
                  : CommunityLinkText(
                      label: developer.githubDisplayLabel,
                      onTap: () => launchCommunityUri(
                        developer.githubUri!,
                        label: 'GitHub',
                      ),
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
              subtitle: developer.githubUri == null
                  ? null
                  : CommunityLinkText(
                      label: developer.githubUri.toString(),
                      onTap: () => launchCommunityUri(
                        developer.githubUri!,
                        label: 'GitHub',
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
              dense: true,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
    );
  }
}

class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgEnd = isDark ? Colors.black : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.onSurface : color,
            width: isSelected ? 2.5 : 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.75), bgEnd],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 5,
                      width: 54,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white70 : Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 5,
                      width: 34,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.check_circle, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
