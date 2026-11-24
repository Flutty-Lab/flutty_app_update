import 'dart:async';

import 'package:flutty_app_update/src/analytics.dart';
import 'package:flutty_app_update/src/app_update_config.dart';
import 'package:flutty_app_update/src/app_version.dart';
import 'package:flutty_app_update/src/dismissal_store.dart';
import 'package:flutty_app_update/src/update_status.dart';
import 'package:flutter/foundation.dart';

/// Which store the build targets — decides where the "Update" CTA points.
enum AppStorePlatform { android, ios, windows, other }

/// Opens a URL outside the app — inject the app's launcher (e.g.
/// `url_launcher`'s `launchUrl`) so the package stays plugin-free.
typedef UrlLauncher = FutureOr<bool> Function(Uri uri);

/// Decides whether the installed version may keep running, comparing
/// [appVersion] against the floors published through [AppUpdateConfig]:
///
/// - below `minimum_required_version` → [UpdateStatus.required]
///   (blocking page),
/// - below `recommended_version` → [UpdateStatus.recommended]
///   (dismissible banner),
/// - otherwise → [UpdateStatus.upToDate].
///
/// Evaluated twice: at startup ([check], called from the bootstrap, which
/// picks the initial route) and on every return to the foreground
/// ([refresh], wired to the app's lifecycle service) — a floor raised
/// while the app is open takes effect without a restart.
///
/// Silent by construction: no network, empty or mistyped parameters, a
/// throwing config source — everything lands on [UpdateStatus.upToDate].
/// A configuration incident must never make the app unusable.
///
/// **Production only.** Without the [isProduction] gate, a value set by
/// mistake on a shared remote config would block dev and staging builds
/// with an "Update" button pointing to a store page that does not exist —
/// a dead end for testers and developers. [allowOutsideProduction] is the
/// escape hatch for deliberately exercising the flow outside prod.
class AppUpdateService {
  AppUpdateService({
    required this.config,
    required this.appVersion,
    required this.isProduction,
    this.keys = const AppUpdateConfigKeys(),
    this.dismissalStore = const SharedPreferencesUpdateDismissalStore(),
    this.analytics = const NoopAppUpdateAnalytics(),
    this.storePlatform = AppStorePlatform.other,
    this.androidPackageName,
    this.openUrl,
  });

  /// Escape hatch to validate the whole flow on a non-production build:
  /// `--dart-define=app_update_in_non_prod=true`. Never set by CI, so it
  /// has no effect on distributed builds.
  static const bool allowOutsideProduction = bool.fromEnvironment(
    'app_update_in_non_prod',
  );

  /// The remote parameters source.
  final AppUpdateConfig config;

  /// The installed version, `x.y.z` or `x.y.z+build` — computed once by
  /// the app (`PackageInfo`), kept as a value so the package stays free of
  /// platform plugins.
  final String appVersion;

  /// The gates described on the class: `false` outside production builds.
  final bool isProduction;

  /// Remote parameter names.
  final AppUpdateConfigKeys keys;

  /// Remembers which recommended version was dismissed.
  final UpdateDismissalStore dismissalStore;

  /// Analytics sink — [NoopAppUpdateAnalytics] by default.
  final AppUpdateAnalytics analytics;

  /// The store this build's CTA should point at.
  final AppStorePlatform storePlatform;

  /// Application id used to deduce the Android store URL when
  /// [AppUpdateConfigKeys.updateUrlAndroid] is empty — typically
  /// `PackageInfo.packageName`.
  final String? androidPackageName;

  /// Opens the store URL — inject the app's own launcher.
  final UrlLauncher? openUrl;

  UpdateStatus _status = UpdateStatus.upToDate;
  String _recommendedVersion = '';

  final StreamController<UpdateStatus> _statusController =
      StreamController<UpdateStatus>.broadcast();

  /// The current status — starts at [UpdateStatus.upToDate] until the
  /// first evaluation lands.
  UpdateStatus get status => _status;

  /// Emits on every status change, in both directions — a recommended
  /// floor lowered or emptied again hides the banner without a restart.
  Stream<UpdateStatus> get statusChanges => _statusController.stream;

  /// The currently published recommended floor, `''` when unset.
  String get recommendedVersion => _recommendedVersion;

  /// Whether the whole mechanism is armed — production builds only,
  /// unless [allowOutsideProduction] was compiled in.
  bool get isEnabled => allowOutsideProduction || isProduction;

  /// First evaluation, at startup. Designed to run in parallel with the
  /// rest of the bootstrap and be awaited right before `runApp` — the
  /// added launch cost is only what exceeds the other initializations.
  Future<void> check() async {
    try {
      await config.init();
      await _evaluate();
    } catch (e) {
      debugPrint('[AppUpdateService] check failed: $e');
    }
  }

  /// Next evaluations, on return to the foreground.
  Future<void> refresh() async {
    try {
      await config.refresh();
      await _evaluate();
    } catch (e) {
      debugPrint('[AppUpdateService] refresh failed: $e');
    }
  }

  /// Single decision point: [check] and [refresh] both go through here,
  /// so [status] can never leave [UpdateStatus.upToDate] outside the gate.
  Future<void> _evaluate() async {
    if (!isEnabled) {
      debugPrint('[AppUpdateService] skipped outside production');
      return;
    }

    _recommendedVersion = config.getString(keys.recommendedVersion);
    final next =
        isVersionBelow(
          current: appVersion,
          reference: config.getString(keys.minimumRequiredVersion),
        )
        ? UpdateStatus.required
        : isVersionBelow(current: appVersion, reference: _recommendedVersion)
        ? UpdateStatus.recommended
        : UpdateStatus.upToDate;

    debugPrint(
      '[AppUpdateService] installed=$appVersion → status=${next.name}',
    );
    if (next == _status) return;
    _status = next;
    _statusController.add(next);
    if (next != UpdateStatus.upToDate) {
      analytics.updatePromptShown(next);
    }
  }

  /// Whether the currently recommended version was already dismissed on
  /// this device — a *newer* recommended floor re-shows the banner.
  Future<bool> get isRecommendedDismissed async =>
      _recommendedVersion.isNotEmpty &&
      (await dismissalStore.dismissedVersion()) == _recommendedVersion;

  /// Records the current recommended version as dismissed — see
  /// [UpdateDismissalStore].
  Future<void> dismissRecommended() async {
    if (_recommendedVersion.isEmpty) return;
    await dismissalStore.dismiss(_recommendedVersion);
    analytics.updateBannerDismissed(_recommendedVersion);
  }

  /// The store link for the running platform, `null` when none is usable —
  /// the UI then shows instructions rather than a dead button.
  String? get storeUrl {
    switch (storePlatform) {
      case AppStorePlatform.android:
        final url = config.getString(keys.updateUrlAndroid);
        if (url.isNotEmpty) return url;
        // Without a configured value, the Play Store page is deduced from
        // the package name (which carries `.dev`/`.stg` suffixes outside
        // production, where no page exists — configure the parameter then).
        final packageName = androidPackageName;
        if (packageName == null || packageName.isEmpty) return null;
        return 'https://play.google.com/store/apps/details?id=$packageName';
      case AppStorePlatform.ios:
        // No URL can be deduced from the bundle id (the numeric page id is
        // required): no parameter, no link.
        final url = config.getString(keys.updateUrlIos);
        return url.isEmpty ? null : url;
      case AppStorePlatform.windows:
        // An MSIX build has no deducible store page: the link — a download
        // page or a store.ms URL — must come from remote config.
        final url = config.getString(keys.updateUrlWindows);
        return url.isEmpty ? null : url;
      case AppStorePlatform.other:
        return null;
    }
  }

  /// `true` when tapping the CTA can actually open something — the
  /// fallback text shows instead otherwise.
  bool get canOpenStore => storeUrl != null && openUrl != null;

  /// Opens the store page through the injected [openUrl].
  Future<void> openStore() async {
    final url = storeUrl;
    final launcher = openUrl;
    if (url == null || launcher == null) return;
    analytics.updateStoreOpened();
    try {
      await launcher(Uri.parse(url));
    } catch (e) {
      debugPrint('[AppUpdateService] openStore failed: $e');
    }
  }

  void dispose() => _statusController.close();
}
