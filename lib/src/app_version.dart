/// Application version number in `x.y.z` form, with an optional `+build`
/// suffix (e.g. "1.2.2" or "1.2.2+31"), comparable to another one.
///
/// Used to confront the installed version (the app's `PackageInfo`) against
/// the floors published through remote config — see `AppUpdateService`.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.segments, [this.build]);

  /// Numeric version segments, most significant first
  /// ("1.2.2" → `[1, 2, 2]`).
  final List<int> segments;

  /// Build number (the part after `+`), `null` when absent.
  final int? build;

  /// `null` when [raw] is not a usable version (empty, letters, non-numeric
  /// segment). The caller decides what to do — for update checks, an
  /// unreadable value must never block the user.
  static AppVersion? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final plusIndex = trimmed.indexOf('+');
    final versionPart = plusIndex == -1
        ? trimmed
        : trimmed.substring(0, plusIndex);
    final buildPart = plusIndex == -1 ? null : trimmed.substring(plusIndex + 1);

    final segments = <int>[];
    for (final segment in versionPart.split('.')) {
      final value = int.tryParse(segment.trim());
      if (value == null || value < 0) return null;
      segments.add(value);
    }
    if (segments.isEmpty) return null;

    int? build;
    if (buildPart != null) {
      build = int.tryParse(buildPart.trim());
      if (build == null || build < 0) return null;
    }
    return AppVersion(segments, build);
  }

  /// Missing segments count as 0: "1.2" and "1.2.0" are equal.
  ///
  /// The build number only breaks a tie when **both** versions carry one:
  /// a floor expressed as "1.3.0" targets the whole 1.3.0 line, whatever
  /// the installed build number.
  @override
  int compareTo(AppVersion other) {
    final length = segments.length > other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < length; i++) {
      final mine = i < segments.length ? segments[i] : 0;
      final theirs = i < other.segments.length ? other.segments[i] : 0;
      if (mine != theirs) return mine.compareTo(theirs);
    }
    final myBuild = build;
    final otherBuild = other.build;
    if (myBuild == null || otherBuild == null) return 0;
    return myBuild.compareTo(otherBuild);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  String toString() => segments.join('.') + (build == null ? '' : '+$build');
}

/// `true` when the installed [current] version is strictly below the
/// [reference] floor.
///
/// Returns `false` as soon as either value is unreadable or absent: a
/// mistyped remote parameter must not condemn installations in the field.
bool isVersionBelow({required String current, required String reference}) {
  final currentVersion = AppVersion.tryParse(current);
  final referenceVersion = AppVersion.tryParse(reference);
  if (currentVersion == null || referenceVersion == null) return false;
  return currentVersion < referenceVersion;
}
