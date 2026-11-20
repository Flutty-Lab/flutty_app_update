# AGENTS.md — flutty_app_update

Flutter package (`pub.dev: flutty_app_update`) for forced and recommended
app updates: a blocking page below a `minimum_required_version` floor, a
dismissible banner below a `recommended_version` floor — both driven by a
remote config the app injects. Lives in the `flutty_core` workspace.
Extracted and generalized from Appels Pro.

## Big picture

- `lib/src/app_update_service.dart` — `AppUpdateService`: single decision
  point (`_evaluate`) behind `check()` (startup) and `refresh()` (resume);
  `status` + `statusChanges` (both directions), `storeUrl`/`openStore`,
  `isRecommendedDismissed`/`dismissRecommended`.
- `lib/src/app_version.dart` — `AppVersion` comparison and
  `isVersionBelow`: unreadable values never block (returns `false`).
- `lib/src/app_update_config.dart` — `AppUpdateConfig` abstraction (the
  app injects its Remote Config), `MapAppUpdateConfig` in-memory impl,
  `AppUpdateConfigKeys` parameter names.
- `lib/src/dismissal_store.dart` — `UpdateDismissalStore` abstraction;
  `SharedPreferencesUpdateDismissalStore` is the only impl (device-local
  by design).
- `lib/src/analytics.dart` — `AppUpdateAnalytics` sink implemented by each
  app; `NoopAppUpdateAnalytics` is the default.
- `lib/src/force_update_view.dart` — pure-presentation blocking content
  (`PopScope canPop: false`); the app wraps it in its own route and wires
  `onUpdate` to `service.openStore`.
- `lib/src/update_banner.dart` — self-managing dismissible banner; place
  it under a widget rebuilt on `statusChanges`.

## Conventions agents should follow

- **Production only by contract**: the whole mechanism is inert unless
  `isProduction` — or the `app_update_in_non_prod` dart-define — allows
  it. Never evaluate before checking `isEnabled`.
- No coupling to app frameworks: no Firebase, GetIt, auto_route or app
  l10n — config values, versions, urls and callbacks are injected.
- No platform plugins in `lib/`: version comes as a `String` (never
  `package_info_plus` — its unconditional `win32` import costs pana
  platform points), url opening goes through the injected `UrlLauncher`.
- Deliberately no `flutty_ds` dependency: the widgets use literal spacing
  constants so consuming apps are not forced onto a specific design
  system version.
- Silent failure is the contract: config init/refresh/throws all land on
  `upToDate` — an update mechanism must never break the app.
- `statusChanges` emits both directions: a lowered/emptied floor hides
  the banner without a restart.
- Code, dartdoc and docs are in English (workspace convention).
- Tests use mocktail + `SharedPreferences.setMockInitialValues` — no
  Firebase, no platform channels needed.

## Tests

```bash
flutter test   # from packages/flutty_app_update
```
