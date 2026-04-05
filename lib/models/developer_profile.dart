class DeveloperProfile {
  const DeveloperProfile({
    required this.name,
    required this.email,
    required this.github,
  });

  final String name;
  final String email;
  final String github;

  bool get hasContent =>
      name.trim().isNotEmpty ||
      email.trim().isNotEmpty ||
      github.trim().isNotEmpty;

  Map<String, String> toCacheMap() {
    return {'name': name, 'email': email, 'github': github};
  }

  String? get githubUsername {
    var value = github.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        final segments = uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .toList();
        if (segments.isNotEmpty) {
          value = segments.first;
        }
      }
    }

    if (value.startsWith('@')) {
      value = value.substring(1);
    }

    if (value.contains('/')) {
      final segments = value
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.isNotEmpty) {
        value = segments.first;
      }
    }

    value = value.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  String? githubAvatarUrl({int size = 96}) {
    final username = githubUsername;
    if (username == null) {
      return null;
    }
    return 'https://avatars.githubusercontent.com/$username?s=$size&v=4';
  }

  Uri? get emailUri {
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return null;
    }
    return Uri(scheme: 'mailto', path: normalizedEmail);
  }

  Uri? get githubUri {
    final String rawGithub = github.trim();
    if (rawGithub.isEmpty) {
      return null;
    }

    if (rawGithub.startsWith('http://') || rawGithub.startsWith('https://')) {
      return Uri.tryParse(rawGithub);
    }

    if (rawGithub.startsWith('www.')) {
      return Uri.tryParse('https://$rawGithub');
    }

    final String? username = githubUsername;
    if (username == null || username.isEmpty) {
      return null;
    }
    return Uri.parse('https://github.com/$username');
  }

  String get githubDisplayLabel {
    final String? username = githubUsername;
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }
    return github.trim();
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String get heroTagKey {
    final raw = (githubUsername ?? name).trim().toLowerCase();
    if (raw.isEmpty) {
      return 'developer';
    }
    return raw.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  factory DeveloperProfile.fromMap(
    Map<String, dynamic> map, {
    required String fallbackName,
  }) {
    final rawName = map['name']?.toString().trim() ?? '';
    final rawEmail = map['email']?.toString().trim() ?? '';
    final rawGithub = map['github']?.toString().trim() ?? '';
    return DeveloperProfile(
      name: rawName.isEmpty ? fallbackName : rawName,
      email: rawEmail,
      github: rawGithub,
    );
  }

  factory DeveloperProfile.fromCacheMap(Map<String, dynamic> map) {
    return DeveloperProfile(
      name: map['name']?.toString().trim() ?? '',
      email: map['email']?.toString().trim() ?? '',
      github: map['github']?.toString().trim() ?? '',
    );
  }
}
