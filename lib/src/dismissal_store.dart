import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for the recommended version the user dismissed — the banner
/// stays hidden until a *different* version becomes recommended.
abstract interface class UpdateDismissalStore {
  /// The recommended version currently dismissed on this device.
  Future<String?> dismissedVersion();

  /// Records [version] as dismissed — idempotent.
  Future<void> dismiss(String version);
}

/// [UpdateDismissalStore] backed by SharedPreferences — the dismissal is
/// deliberately local to the device: it reflects where the banner was
/// closed and has nothing to do server-side.
final class SharedPreferencesUpdateDismissalStore
    implements UpdateDismissalStore {
  const SharedPreferencesUpdateDismissalStore({
    this.key = 'flutty_app_update_dismissed',
  });

  /// Preference key holding the dismissed version — namespace it per app so
  /// it never collides with another consumer of the same store.
  final String key;

  @override
  Future<String?> dismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, version);
  }
}
