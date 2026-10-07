/// Lenient JSON readers. The API may return null, missing or differently
/// typed optional values; these never throw.
library;

int? readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? readDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// For calendar-date fields (due/start date). The API sends them as UTC
/// midnight (`2026-10-10T00:00:00Z`); converting that to local time would
/// show Oct 9 west of UTC, so the date is taken as written and returned as
/// a local midnight with no time component.
DateTime? readDateOnly(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

Map<String, dynamic>? readMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> readMapList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// Returns the first non-null value among [keys], so one parser can accept
/// both `dueDate` (list route) and `due_date` (detail route).
dynamic firstOf(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}
