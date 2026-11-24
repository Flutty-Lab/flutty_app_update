// ignore_for_file: deprecated_member_use
import 'package:flutty_app_update/flutty_app_update.dart';
import 'package:flutter/material.dart';

/// Demo of `flutty_app_update` with a compiled-in config: pick a scenario,
/// the banner and the blocking page react like they would against a real
/// remote config.
void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _values = <String, String>{
    'minimum_required_version': '',
    'recommended_version': '2.0.0',
    'update_url_android':
        'https://play.google.com/store/apps/details?id=com.example.app',
    'update_url_ios': '',
    'update_url_windows': '',
  };

  late final AppUpdateService _service = AppUpdateService(
    config: MapAppUpdateConfig(_values),
    appVersion: '1.0.0+1',
    // Compiled-in escape: the example demonstrates the prompts, it is not
    // a production build.
    isProduction: true,
    storePlatform: AppStorePlatform.android,
    androidPackageName: 'com.example.app',
    openUrl: (uri) async {
      debugPrint('openStore → $uri');
      return true;
    },
  );

  @override
  void initState() {
    super.initState();
    _service.check();
  }

  void _setFloor(String key, String value) =>
      setState(() => _values[key] = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<UpdateStatus>(
        stream: _service.statusChanges,
        initialData: _service.status,
        builder: (context, snapshot) {
          final status = snapshot.data ?? UpdateStatus.upToDate;
          if (status == UpdateStatus.required) {
            return Scaffold(
              body: ForceUpdateView(
                title: 'Update required',
                message: 'This version is no longer supported.',
                updateLabel: 'Update',
                manualHint: 'Update the app from your store.',
                onUpdate: _service.canOpenStore ? _service.openStore : null,
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('flutty_app_update')),
            body: Column(
              children: [
                if (status == UpdateStatus.recommended)
                  UpdateBanner(
                    service: _service,
                    message: 'A new version is available.',
                    updateLabel: 'Update',
                    dismissTooltip: 'Later',
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Installed: 1.0.0+1 — status: ${status.name}'),
                      const SizedBox(height: 16),
                      _floorField(
                        label: 'recommended_version',
                        onChanged: (v) => _setFloor('recommended_version', v),
                        initial: _values['recommended_version']!,
                      ),
                      _floorField(
                        label: 'minimum_required_version',
                        onChanged: (v) =>
                            _setFloor('minimum_required_version', v),
                        initial: _values['minimum_required_version']!,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _floorField({
    required String label,
    required String initial,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initial,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'e.g. 1.5.0 — empty disables',
        ),
        onChanged: (v) async {
          onChanged(v);
          await _service.refresh();
        },
      ),
    );
  }
}
