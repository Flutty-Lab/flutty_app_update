/// Names of the remote parameters the service reads, overridable per app —
/// the defaults match the convention documented in the README.
class AppUpdateConfigKeys {
  const AppUpdateConfigKeys({
    this.minimumRequiredVersion = 'minimum_required_version',
    this.recommendedVersion = 'recommended_version',
    this.updateUrlAndroid = 'update_url_android',
    this.updateUrlIos = 'update_url_ios',
    this.updateUrlWindows = 'update_url_windows',
  });

  /// Floor below which the blocking page shows (e.g. "1.3.0").
  /// Empty = no blocking.
  final String minimumRequiredVersion;

  /// Floor below which the dismissible banner shows. Empty = no banner.
  final String recommendedVersion;

  /// URL opened by the "Update" button on Android.
  /// Empty = deduced from the package name (Play Store page).
  final String updateUrlAndroid;

  /// URL opened by the "Update" button on iOS (needs the numeric App Store
  /// id — nothing can be deduced from the bundle id). Empty = no button.
  final String updateUrlIos;

  /// URL opened by the "Update" button on Windows — an MSIX build has no
  /// deducible store page, so point it at a download page or a store.ms
  /// link. Empty = no button.
  final String updateUrlWindows;
}

/// Source of the update parameters — typically Firebase Remote Config, but
/// any store able to answer `getString` works (Remote Config stays an app
/// dependency, the package never imports it).
abstract interface class AppUpdateConfig {
  /// Applies defaults then fetches remote values. Implementations should
  /// never throw: a network failure leaves the defaults in place.
  Future<void> init();

  /// Fetches again, within the source's own throttling rules (Remote Config
  /// serves the cached value below its minimum fetch interval).
  Future<void> refresh();

  /// The activated value for [key], `''` when unset.
  String getString(String key);
}

/// In-memory [AppUpdateConfig] — handy for tests, examples and apps whose
/// update parameters are compiled in rather than fetched.
final class MapAppUpdateConfig implements AppUpdateConfig {
  const MapAppUpdateConfig(this.values);

  /// Activated values served by [getString].
  final Map<String, String> values;

  @override
  Future<void> init() async {}

  @override
  Future<void> refresh() async {}

  @override
  String getString(String key) => values[key] ?? '';
}
