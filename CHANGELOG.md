## 0.2.0

- Add `AppStorePlatform.windows` and the `update_url_windows` remote
  parameter (`AppUpdateConfigKeys.updateUrlWindows`): an MSIX build has no
  deducible store page, so the Windows CTA is driven entirely by the
  configured URL — a download page or a store.ms link. `AppStorePlatform`
  gains a value: exhaustive switches on it must be updated.

## 0.1.0

- Package creation: `AppUpdateService` (remote-config driven `UpdateStatus { upToDate, recommended, required }`, startup `check` + resume `refresh`, production-only gate with a `app_update_in_non_prod` dart-define escape hatch), `AppUpdateConfig` + `MapAppUpdateConfig`, `AppUpdateConfigKeys`, `AppVersion` comparison, `UpdateDismissalStore` persisted in SharedPreferences, `ForceUpdateView` + `UpdateBanner` UI, `AppUpdateAnalytics` interface. Extracted and generalized from Appels Pro.
