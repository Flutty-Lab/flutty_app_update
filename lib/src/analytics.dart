import 'package:flutty_app_update/src/update_status.dart';

/// Analytics sink for update prompts — each app implements it with its own
/// reporting (only statuses and versions flow through, never free text).
abstract interface class AppUpdateAnalytics {
  /// The blocking page or the banner became visible for [status].
  void updatePromptShown(UpdateStatus status);

  /// The recommended banner was dismissed for [version].
  void updateBannerDismissed(String version);

  /// The "Update" call-to-action was tapped.
  void updateStoreOpened();
}

/// Default [AppUpdateAnalytics] — reports nothing.
final class NoopAppUpdateAnalytics implements AppUpdateAnalytics {
  const NoopAppUpdateAnalytics();

  @override
  void updatePromptShown(UpdateStatus status) {}

  @override
  void updateBannerDismissed(String version) {}

  @override
  void updateStoreOpened() {}
}
