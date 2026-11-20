## 0.1.0

- Package creation: `AppUpdateService` (remote-config driven `UpdateStatus { upToDate, recommended, required }`, startup `check` + resume `refresh`, production-only gate with a `app_update_in_non_prod` dart-define escape hatch), `AppUpdateConfig` + `MapAppUpdateConfig`, `AppUpdateConfigKeys`, `AppVersion` comparison, `UpdateDismissalStore` persisted in SharedPreferences, `ForceUpdateView` + `UpdateBanner` UI, `AppUpdateAnalytics` interface. Extracted and generalized from Appels Pro.
