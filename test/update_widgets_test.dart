import 'package:flutty_app_update/flutty_app_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutty_app_update/src/material.dart';

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
    Widget view({
      VoidCallback? onUpdate,
      ForceUpdateButtonBuilder? updateButtonBuilder,
      ForceUpdateIconBadgeBuilder? iconBadgeBuilder,
      EdgeInsetsGeometry? contentPadding,
    }) => MaterialApp(
      home: Scaffold(
        body: ForceUpdateView(
          title: 'Update required',
          message: 'This version is no longer supported.',
          updateLabel: 'Update',
          manualHint: 'Update the app from your store.',
          onUpdate: onUpdate,
          updateButtonBuilder: updateButtonBuilder,
          iconBadgeBuilder: iconBadgeBuilder,
          contentPadding: contentPadding,
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

    testWidgets('uses the Material CTA and badge by default', (tester) async {
      await tester.pumpWidget(view(onUpdate: () {}));

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsOneWidget);
    });

    testWidgets('uses a custom update button instead of the default CTA', (
      tester,
    ) async {
      var tapped = 0;
      String? receivedLabel;
      await tester.pumpWidget(
        view(
          onUpdate: () => tapped++,
          updateButtonBuilder: (context, onUpdate, label) {
            receivedLabel = label;
            return ElevatedButton(
              onPressed: onUpdate,
              child: Text('Custom $label'),
            );
          },
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Custom Update'), findsOneWidget);
      expect(receivedLabel, 'Update');
      await tester.tap(find.text('Custom Update'));
      expect(tapped, 1);
    });

    testWidgets('uses a custom icon badge instead of the default badge', (
      tester,
    ) async {
      IconData? receivedIcon;
      await tester.pumpWidget(
        view(
          onUpdate: () {},
          iconBadgeBuilder: (context, icon) {
            receivedIcon = icon;
            return const SizedBox(key: ValueKey('custom-badge'));
          },
        ),
      );

      expect(find.byKey(const ValueKey('custom-badge')), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsNothing);
      expect(receivedIcon, Icons.system_update);
    });

    testWidgets('uses custom content padding when provided', (tester) async {
      const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 20);
      await tester.pumpWidget(view(onUpdate: () {}, contentPadding: padding));

      final paddingWidget = tester
          .element(find.byType(Column))
          .findAncestorWidgetOfExactType<Padding>();
      expect(paddingWidget?.padding, padding);
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

    testWidgets('text stays readable under a dark app theme', (tester) async {
      // Consuming apps theme with Flutter's ThemeData — the view must read
      // it. With a different Theme implementation (e.g. material_ui's) the
      // lookup falls back to a light theme and paints dark text on the
      // app's dark surface.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: ForceUpdateView(
              title: 'Update required',
              message: 'This version is no longer supported.',
            ),
          ),
        ),
      );

      for (final content in [
        'Update required',
        'This version is no longer supported.',
      ]) {
        final context = tester.element(find.text(content));
        final resolved = DefaultTextStyle.of(context).style
            .merge(tester.widget<Text>(find.text(content)).style);
        expect(
          resolved.color!.computeLuminance(),
          greaterThan(0.5),
          reason: '"$content" must be a light color on a dark theme',
        );
      }
    });
  });

  group('UpdateBanner', () {
    Widget banner(
      AppUpdateService service, {
      VoidCallback? onDismissed,
      UpdateBannerActionBuilder? actionBuilder,
      UpdateBannerDismissBuilder? dismissBuilder,
      Color? backgroundColor,
      Color? foregroundColor,
    }) => MaterialApp(
      home: Scaffold(
        body: UpdateBanner(
          service: service,
          message: 'A new version is available.',
          updateLabel: 'Update',
          dismissTooltip: 'Later',
          onDismissed: onDismissed,
          actionBuilder: actionBuilder,
          dismissBuilder: dismissBuilder,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
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

    testWidgets('uses the Material actions by default', (tester) async {
      final service = _recommendedService(openUrl: (uri) async => true);
      await service.check();
      await tester.pumpWidget(banner(service));
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('uses a custom action instead of the default CTA', (
      tester,
    ) async {
      final opened = <Uri>[];
      String? receivedLabel;
      final service = _recommendedService(
        openUrl: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await service.check();
      await tester.pumpWidget(
        banner(
          service,
          actionBuilder: (context, onUpdate, label) {
            receivedLabel = label;
            return ElevatedButton(
              onPressed: onUpdate,
              child: Text('Custom $label'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Custom Update'), findsOneWidget);
      expect(receivedLabel, 'Update');
      await tester.tap(find.text('Custom Update'));
      expect(opened, hasLength(1));
    });

    testWidgets('uses a custom dismiss action instead of the default close', (
      tester,
    ) async {
      final store = _MemoryDismissalStore();
      String? receivedTooltip;
      final service = _recommendedService(
        store: store,
        openUrl: (uri) async => true,
      );
      await service.check();
      await tester.pumpWidget(
        banner(
          service,
          dismissBuilder: (context, onDismiss, tooltip) {
            receivedTooltip = tooltip;
            return TextButton(
              onPressed: onDismiss,
              child: const Text('Custom close'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
      expect(receivedTooltip, 'Later');
      await tester.tap(find.text('Custom close'));
      await tester.pumpAndSettle();

      expect(store.stored, '2.0.0');
      expect(find.text('A new version is available.'), findsNothing);
    });

    testWidgets('uses custom background and foreground colors', (tester) async {
      final service = _recommendedService(openUrl: (uri) async => true);
      await service.check();
      await tester.pumpWidget(
        banner(
          service,
          backgroundColor: Colors.amber,
          foregroundColor: Colors.deepPurple,
        ),
      );
      await tester.pumpAndSettle();

      final rowElement = tester.element(
        find.descendant(
          of: find.byType(UpdateBanner),
          matching: find.byType(Row),
        ),
      );
      final material = rowElement.findAncestorWidgetOfExactType<Material>();
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(UpdateBanner),
          matching: find.byIcon(Icons.system_update),
        ),
      );
      expect(material?.color, Colors.amber);
      expect(icon.color, Colors.deepPurple);
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
