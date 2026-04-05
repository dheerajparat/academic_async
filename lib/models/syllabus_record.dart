class SyllabusTopic {
  const SyllabusTopic({
    required this.id,
    required this.title,
    this.details = '',
  });

  final String id;
  final String title;
  final String details;
}

class SyllabusUnit {
  const SyllabusUnit({
    required this.id,
    required this.title,
    required this.topics,
  });

  final String id;
  final String title;
  final List<SyllabusTopic> topics;
}

class SyllabusRecord {
  const SyllabusRecord({
    required this.id,
    required this.title,
    required this.forSemesterIds,
    required this.units,
  });

  final String id;
  final String title;
  final List<String> forSemesterIds;
  final List<SyllabusUnit> units;

  int get totalTopics =>
      units.fold<int>(0, (sum, unit) => sum + unit.topics.length);

  static SyllabusRecord? fromFirestore(String id, Map<String, dynamic> data) {
    final String title = _asString(
      data['title'],
      fallback: _asString(data['name']),
    );
    if (title.isEmpty) {
      return null;
    }

    final List<String> targets = _asStringList(
      data['for'] ?? data['for_semester_ids'] ?? data['semester_ids'],
    );
    final List<SyllabusUnit> units = _parseUnits(
      data['units'] ?? data['unit'] ?? data['umit'],
      defaultPrefix: id,
    );

    if (units.isEmpty) {
      final List<SyllabusTopic> standaloneTopics = _parseTopics(
        data['topics'] ?? data['topic'] ?? data['toics'],
        unitPrefix: '${id}_u0',
      );
      if (standaloneTopics.isNotEmpty) {
        return SyllabusRecord(
          id: id,
          title: title,
          forSemesterIds: targets,
          units: <SyllabusUnit>[
            SyllabusUnit(
              id: '${id}_u0',
              title: _asString(data['unit_title'], fallback: 'Unit 1'),
              topics: standaloneTopics,
            ),
          ],
        );
      }
    }

    return SyllabusRecord(
      id: id,
      title: title,
      forSemesterIds: targets,
      units: units,
    );
  }

  static List<SyllabusUnit> _parseUnits(
    dynamic value, {
    required String defaultPrefix,
  }) {
    final List<SyllabusUnit> parsed = <SyllabusUnit>[];
    if (value is List) {
      for (int i = 0; i < value.length; i++) {
        final SyllabusUnit? unit = _unitFromDynamic(
          value[i],
          index: i,
          fallbackPrefix: defaultPrefix,
        );
        if (unit != null) {
          parsed.add(unit);
        }
      }
      return parsed;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final bool hasDirectShape =
          map.containsKey('title') || map.containsKey('topics');
      if (hasDirectShape) {
        final SyllabusUnit? single = _unitFromDynamic(
          map,
          index: 0,
          fallbackPrefix: defaultPrefix,
        );
        if (single != null) {
          parsed.add(single);
        }
        return parsed;
      }

      int idx = 0;
      for (final entry in map.entries) {
        final String unitTitle = _asString(
          entry.key,
          fallback: 'Unit ${idx + 1}',
        );
        final List<SyllabusTopic> topics = _parseTopics(
          entry.value,
          unitPrefix: '${defaultPrefix}_u$idx',
        );
        if (topics.isEmpty) {
          idx++;
          continue;
        }
        parsed.add(
          SyllabusUnit(
            id: '${defaultPrefix}_u$idx',
            title: unitTitle,
            topics: topics,
          ),
        );
        idx++;
      }
    }

    return parsed;
  }

  static SyllabusUnit? _unitFromDynamic(
    dynamic value, {
    required int index,
    required String fallbackPrefix,
  }) {
    if (value is String) {
      final String unitTitle = value.trim();
      if (unitTitle.isEmpty) {
        return null;
      }
      return SyllabusUnit(
        id: '${fallbackPrefix}_u$index',
        title: unitTitle,
        topics: const [],
      );
    }

    if (value is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(value);
    final String unitTitle = _asString(
      map['title'],
      fallback: _asString(
        map['name'],
        fallback: _asString(map['unit'], fallback: 'Unit ${index + 1}'),
      ),
    );
    final String unitId = _asString(
      map['id'],
      fallback: '${fallbackPrefix}_u$index',
    );
    final List<SyllabusTopic> topics = _parseTopics(
      map['topics'] ?? map['topic'] ?? map['toics'],
      unitPrefix: unitId,
    );

    if (unitTitle.isEmpty || topics.isEmpty) {
      return null;
    }

    return SyllabusUnit(id: unitId, title: unitTitle, topics: topics);
  }

  static List<SyllabusTopic> _parseTopics(
    dynamic value, {
    required String unitPrefix,
  }) {
    final List<dynamic> rawItems;
    if (value is List) {
      rawItems = value;
    } else if (value is Map) {
      rawItems = value.values.toList();
    } else {
      rawItems = const [];
    }

    final List<SyllabusTopic> parsed = <SyllabusTopic>[];
    for (int i = 0; i < rawItems.length; i++) {
      final SyllabusTopic? topic = _topicFromDynamic(
        rawItems[i],
        index: i,
        unitPrefix: unitPrefix,
      );
      if (topic != null) {
        parsed.add(topic);
      }
    }
    return parsed;
  }

  static SyllabusTopic? _topicFromDynamic(
    dynamic value, {
    required int index,
    required String unitPrefix,
  }) {
    if (value is String) {
      final String title = value.trim();
      if (title.isEmpty) {
        return null;
      }
      return SyllabusTopic(id: '${unitPrefix}_t$index', title: title);
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final String title = _asString(
        map['title'],
        fallback: _asString(
          map['name'],
          fallback: _asString(map['topic'], fallback: _asString(map['toic'])),
        ),
      );
      if (title.isEmpty) {
        return null;
      }
      final String details = _asString(
        map['details'],
        fallback: _asString(
          map['description'],
          fallback: _asString(map['content']),
        ),
      );
      final String topicId = _asString(
        map['id'],
        fallback: '${unitPrefix}_t$index',
      );
      return SyllabusTopic(id: topicId, title: title, details: details);
    }
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    final List<dynamic> rawItems;
    if (value is List) {
      rawItems = value;
    } else if (value is Map) {
      rawItems = value.values.toList();
    } else if (value == null) {
      rawItems = const [];
    } else {
      rawItems = <dynamic>[value];
    }

    final Set<String> seen = <String>{};
    final List<String> parsed = <String>[];
    for (final dynamic item in rawItems) {
      final String text = _asString(item);
      if (text.isEmpty || seen.contains(text)) {
        continue;
      }
      seen.add(text);
      parsed.add(text);
    }
    return parsed;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}
