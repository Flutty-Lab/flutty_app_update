import 'package:flutty_app_update/flutty_app_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _MemoryDismissalStore implements UpdateDismissalStore {
  _MemoryDismissalStore([this.stored]);

  String? stored;

  @override
  Future<String?> dismissedVersion() async => stored;

  @override
  Future<void> dismiss(String version) async => stored = version;
}

AppUpdateService _recommendedService({
  _MemoryDismissalStore? store,
  UrlLauncher? openUrl,
}) => AppUpdateService(
  config: const MapAppUpdateConfig({'recommended_version': '2.0.0'}),
  appVersion: '1.0.0+1',
  isProduction: true,
  dismissalStore: store ?? _MemoryDismissalStore(),
  storePlatform: AppStorePlatform.android,
  androidPackageName: 'com.example.app',
  openUrl: openUrl,
);

void main() {
  group('ForceUpdateView', () {
    Widget view({VoidCallback? onUpdate}) => MaterialApp(
      home: Scaffold(
        body: ForceUpdateView(
          title: 'Update required',
          message: 'This version is no longer supported.',
          updateLabel: 'Update',
          manualHint: 'Update the app from your store.',
          onUpdate: onUpdate,
        ),
      ),
    );

    testWidgets('shows title, message and a working CTA', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(view(onUpdate: () => tapped++));

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      await tester.tap(find.text('Update'));
      expect(tapped, 1);
    });

    testWidgets('without a store action the manual hint replaces the CTA', (
      tester,
    ) async {
      await tester.pumpWidget(view());

      expect(find.text('Update'), findsNothing);
      expect(find.text('Update the app from your store.'), findsOneWidget);
    });

    testWidgets('the screen cannot be popped', (tester) async {
      await tester.pumpWidget(view(onUpdate: () {}));
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    });
  });

  group('UpdateBanner', () {
    Widget banner(AppUpdateService service, {VoidCallback? onDismissed}) =>
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              service: service,
              message: 'A new version is available.',
              updateLabel: 'Update',
              dismissTooltip: 'Later',
              onDismissed: onDismissed,
            ),
          ),
        );

    testWidgets('shows the message and opens the store from the CTA', (
      tester,
    ) async {
      final opened = <Uri>[];
      final service = _recommendedService(
        openUrl: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await service.check();
      await tester.pumpWidget(banner(service));
      await tester.pumpAndSettle();

      expect(find.text('A new version is available.'), findsOneWidget);
      await tester.tap(find.text('Update'));
      expect(opened, hasLength(1));
    });

    testWidgets('closing dismisses the current version for good', (
      tester,
    ) async {
      final store = _MemoryDismissalStore();
      var dismissedCalls = 0;
      final service = _recommendedService(
        store: store,
        openUrl: (uri) async => true,
      );
      await service.check();
      await tester.pumpWidget(
        banner(service, onDismissed: () => dismissedCalls++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Later'));
      await tester.pumpAndSettle();

      expect(store.stored, '2.0.0');
      expect(dismissedCalls, 1);
      expect(find.text('A new version is available.'), findsNothing);
    });

    testWidgets('an already dismissed version renders nothing', (tester) async {
      final service = _recommendedService(
        store: _MemoryDismissalStore('2.0.0'),
      );
      await service.check();
      await tester.pumpWidget(banner(service));
      await tester.pumpAndSettle();

      expect(find.text('A new version is available.'), findsNothing);
    });
  });
}
