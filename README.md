# flutty_app_update

Forced and recommended app updates driven by remote config:

- the installed version drops below `minimum_required_version` → a
  **blocking page** leaves no choice but to update,
- it drops below `recommended_version` → a **dismissible banner** nudges
  the user (never re-shown for the same version),
- anything unreadable or unreachable → the app keeps running. An update
  mechanism must never break the app.

Extracted and generalized from a production app (Appels Pro).

## Remote parameters

| Parameter | Effect |
|---|---|
| `minimum_required_version` | `x.y.z` or `x.y.z+build` floor below which the app blocks. Empty = no blocking. |
| `recommended_version` | Floor below which the banner shows. Empty = no banner. |
| `update_url_android` | CTA link on Android. Empty = deduced from the package name. |
| `update_url_ios` | CTA link on iOS — required, nothing can be deduced from the bundle id. Empty = no button. |

Parameter names are configurable via `AppUpdateConfigKeys`.

## Setup

```dart
final updateService = AppUpdateService(
  config: myRemoteConfig,             // implements AppUpdateConfig
  appVersion: '${info.version}+${info.buildNumber}',
  isProduction: flavor.isProduction,
  storePlatform: Platform.isAndroid
      ? AppStorePlatform.android
      : AppStorePlatform.ios,
  androidPackageName: info.packageName,
  openUrl: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
  analytics: myAnalytics,             // optional AppUpdateAnalytics
);

// In the bootstrap, in parallel with the other inits, awaited before runApp:
final updateCheck = updateService.check();
// … later, on every return to the foreground (lifecycle observer):
updateService.refresh();
```

`AppUpdateConfig` is the seam for your remote store — a Firebase Remote
Config adapter is three methods (`init`/`refresh`/`getString`); an
in-memory `MapAppUpdateConfig` ships with the package for tests and
compiled-in configs.

### Production gate

Everything is inert unless `isProduction` is `true` — a floor set by
mistake must not soft-brick dev or staging builds (the CTA would point to
store pages that don't exist). To exercise the full flow on a non-prod
build:

```bash
flutter run --dart-define=app_update_in_non_prod=true
```

## Blocking page

`ForceUpdateView` is pure presentation — the app owns the route:

```dart
@RoutePage()
class ForceUpdatePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: ForceUpdateView(
          title: 'Update required',
          message: 'This version is no longer supported.',
          updateLabel: 'Update',
          manualHint: 'Update the app from your store.',
          onUpdate: service.canOpenStore ? service.openStore : null,
        ),
      );
}
```

Redirect to it when `service.status == UpdateStatus.required` (e.g. in
the router's initial-route/deep-link decision) and navigate on
`statusChanges` so a floor raised mid-session takes over the stack.

## Recommended banner

`UpdateBanner` manages its own visibility through the service:

```dart
// Inside a widget rebuilt on service.statusChanges:
if (service.status == UpdateStatus.recommended)
  UpdateBanner(
    service: service,
    message: 'A new version is available.',
    updateLabel: 'Update',
    dismissTooltip: 'Later',
  ),
```

Closing it records the *current* recommended version in
`SharedPreferencesUpdateDismissalStore` — the banner only reappears when
a different version gets recommended. Dismissal is device-local by
design; inject another `UpdateDismissalStore` to change that.

## Analytics

Implement `AppUpdateAnalytics` to receive `updatePromptShown(status)`,
`updateBannerDismissed(version)` and `updateStoreOpened()`. Nothing
reports unless you wire it — `NoopAppUpdateAnalytics` is the default.
