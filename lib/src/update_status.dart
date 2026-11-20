/// How the installed version compares to the floors published through
/// remote config.
enum UpdateStatus {
  /// At or above every floor — nothing to show.
  upToDate,

  /// Below the `recommended_version` floor — a dismissible banner nudges
  /// the user toward the store.
  recommended,

  /// Below the `minimum_required_version` floor — a blocking page leaves
  /// no choice but to update.
  required,
}
