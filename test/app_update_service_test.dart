import 'package:flutty_app_update/flutty_app_update.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableConfig implements AppUpdateConfig {
  _MutableConfig(this.values);

  final Map<String, String> values;
  bool throwing = false;
  var inits = 0;
  var refreshes = 0;

  @override
  Future<void> init() async {
    inits++;
    if (throwing) throw StateError('config init failed');
  }

  @override
  Future<void> refresh() async {
    refreshes++;
    if (throwing) throw StateError('config refresh failed');
  }

  @override
  String getString(String key) => values[key] ?? '';
}

class _MemoryDismissalStore implements UpdateDismissalStore {
  String? stored;

  @override
  Future<String?> dismissedVersion() async => stored;

  @override
  Future<void> dismiss(String version) async => stored = version;
}

class _RecordingAnalytics implements AppUpdateAnalytics {
  final events = <String>[];

  @override
  void updatePromptShown(UpdateStatus status) =>
      events.add('prompt:${status.name}');

  @override
  void updateBannerDismissed(String version) =>
      events.add('dismissed:$version');

  @override
  void updateStoreOpened() => events.add('store');
}

void main() {
  late _MutableConfig config;
  late _MemoryDismissalStore store;
  late _RecordingAnalytics analytics;
  final opened = <Uri>[];

  AppUpdateService service({
    bool isProduction = true,
    String appVersion = '1.0.0+1',
    AppStorePlatform platform = AppStorePlatform.other,
    String? androidPackageName,
    UrlLauncher? openUrl,
  }) => AppUpdateService(
    config: config,
    appVersion: appVersion,
    isProduction: isProduction,
    dismissalStore: store,
    analytics: analytics,
    storePlatform: platform,
    androidPackageName: androidPackageName,
    openUrl: openUrl,
  );

  setUp(() {
    config = _MutableConfig({});
    store = _MemoryDismissalStore();
    analytics = _RecordingAnalytics();
    opened.clear();
  });

  group('status evaluation', () {
    test('empty config keeps the app up to date', () async {
      final s = service();
      await s.check();
      expect(s.status, UpdateStatus.upToDate);
      expect(config.inits, 1);
    });

    test('below minimum_required_version → required', () async {
      config.values['minimum_required_version'] = '1.1.0';
      final s = service();
      await s.check();
      expect(s.status, UpdateStatus.required);
      expect(analytics.events, ['prompt:required']);
    });

    test('below recommended_version only → recommended', () async {
      config.values['recommended_version'] = '2.0.0';
      final s = service();
      await s.check();
      expect(s.status, UpdateStatus.recommended);
      expect(s.recommendedVersion, '2.0.0');
      expect(analytics.events, ['prompt:recommended']);
    });

    test('required wins over recommended', () async {
      config.values['recommended_version'] = '1.1.0';
      config.values['minimum_required_version'] = '1.2.0';
      final s = service();
      await s.check();
      expect(s.status, UpdateStatus.required);
    });

    test('equal to the floor is up to date', () async {
      config.values['minimum_required_version'] = '1.0.0';
      config.values['recommended_version'] = '1.0.0';
      final s = service();
      await s.check();
      expect(s.status, UpdateStatus.upToDate);
    });

    test('unreadable parameters never block', () async {
      config.values['minimum_required_version'] = 'not-a-version';
      config.values['recommended_version'] = '???';
      final s = service();
      await s.check();
      expect(s.status, UpdateStatus.upToDate);
    });

    test('a throwing config leaves the app up to date', () async {
      config.values['minimum_required_version'] = '9.9.9';
      config.throwing = true;
      final s = service();
      await s.check();
      await s.refresh();
      expect(s.status, UpdateStatus.upToDate);
    });
  });

  group('production gate', () {
    test('outside production everything stays up to date', () async {
      config.values['minimum_required_version'] = '9.9.9';
      config.values['recommended_version'] = '9.9.9';
      final s = service(isProduction: false);
      await s.check();
      await s.refresh();
      expect(s.isEnabled, isFalse);
      expect(s.status, UpdateStatus.upToDate);
      expect(analytics.events, isEmpty);
    });
  });

  group('statusChanges', () {
    test('emits on every transition, both directions', () async {
      config.values['recommended_version'] = '2.0.0';
      final s = service();
      final emitted = <UpdateStatus>[];
      final sub = s.statusChanges.listen(emitted.add);

      await s.check();
      config.values.remove('recommended_version');
      await s.refresh();

      expect(emitted, [UpdateStatus.recommended, UpdateStatus.upToDate]);
      await sub.cancel();
    });

    test('an unchanged status does not re-emit', () async {
      config.values['recommended_version'] = '2.0.0';
      final s = service();
      final emitted = <UpdateStatus>[];
      final sub = s.statusChanges.listen(emitted.add);

      await s.check();
      await s.refresh();

      expect(emitted, [UpdateStatus.recommended]);
      expect(analytics.events, ['prompt:recommended']);
      await sub.cancel();
    });
  });

  group('dismissal', () {
    test('dismissRecommended stores the current floor and reports', () async {
      config.values['recommended_version'] = '2.0.0';
      final s = service();
      await s.check();

      await s.dismissRecommended();

      expect(store.stored, '2.0.0');
      expect(await s.isRecommendedDismissed, isTrue);
      expect(analytics.events, contains('dismissed:2.0.0'));
    });

    test('a newer recommended floor is not dismissed', () async {
      store.stored = '2.0.0';
      config.values['recommended_version'] = '2.1.0';
      final s = service();
      await s.check();
      expect(await s.isRecommendedDismissed, isFalse);
    });

    test('no recommended floor means nothing is dismissed', () async {
      final s = service();
      await s.check();
      expect(await s.isRecommendedDismissed, isFalse);
      await s.dismissRecommended();
      expect(store.stored, isNull);
    });
  });

  group('store url', () {
    test('android deduces the Play page from the package name', () async {
      final s = service(
        platform: AppStorePlatform.android,
        androidPackageName: 'com.example.app',
      );
      await s.check();
      expect(
        s.storeUrl,
        'https://play.google.com/store/apps/details?id=com.example.app',
      );
    });

    test('a configured url wins over the deduction', () async {
      config.values['update_url_android'] = 'https://custom.link/app';
      final s = service(
        platform: AppStorePlatform.android,
        androidPackageName: 'com.example.app',
      );
      await s.check();
      expect(s.storeUrl, 'https://custom.link/app');
    });

    test('ios needs the configured url — nothing is deduced', () async {
      final s = service(platform: AppStorePlatform.ios);
      await s.check();
      expect(s.storeUrl, isNull);

      config.values['update_url_ios'] = 'https://apps.apple.com/app/id42';
      await s.refresh();
      expect(s.storeUrl, 'https://apps.apple.com/app/id42');
    });

    test('windows needs the configured url — nothing is deduced', () async {
      final s = service(platform: AppStorePlatform.windows);
      await s.check();
      expect(s.storeUrl, isNull);

      config.values['update_url_windows'] =
          'https://apps.microsoft.com/detail/42';
      await s.refresh();
      expect(s.storeUrl, 'https://apps.microsoft.com/detail/42');
    });

    test('other platforms never get a store url', () async {
      final s = service();
      await s.check();
      expect(s.storeUrl, isNull);
      expect(s.canOpenStore, isFalse);
    });
  });

  group('openStore', () {
    test('launches the url and reports once', () async {
      final s = service(
        platform: AppStorePlatform.android,
        androidPackageName: 'com.example.app',
        openUrl: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await s.check();
      expect(s.canOpenStore, isTrue);

      await s.openStore();

      expect(opened, hasLength(1));
      expect(
        opened.single.toString(),
        'https://play.google.com/store/apps/details?id=com.example.app',
      );
      expect(analytics.events, contains('store'));
    });

    test('without a launcher there is no call and no CTA', () async {
      final s = service(
        platform: AppStorePlatform.android,
        androidPackageName: 'com.example.app',
      );
      await s.check();
      expect(s.storeUrl, isNotNull);
      expect(s.canOpenStore, isFalse);
      await s.openStore();
      expect(opened, isEmpty);
    });

    test('a throwing launcher is swallowed', () async {
      final s = service(
        platform: AppStorePlatform.android,
        androidPackageName: 'com.example.app',
        openUrl: (uri) => throw StateError('no handler'),
      );
      await s.check();
      await s.openStore();
    });
  });
}
