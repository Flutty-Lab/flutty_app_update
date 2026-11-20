import 'package:material_ui/material_ui.dart';

/// Blocking content shown when the installed version is below the minimum
/// required floor ([UpdateStatus.required]).
///
/// No way out on purpose: no back gesture, no "later" button. The only
/// exit is updating from the store, then relaunching. Pure presentation —
/// wrap it in the app's own page/route and wire [onUpdate] to
/// `AppUpdateService.openStore`.
class ForceUpdateView extends StatelessWidget {
  const ForceUpdateView({
    required this.title,
    required this.message,
    this.updateLabel,
    this.manualHint,
    this.onUpdate,
    this.icon = Icons.system_update,
    super.key,
  });

  /// Headline — e.g. "Update required".
  final String title;

  /// Explanation below the title.
  final String message;

  /// CTA label — shown only when [onUpdate] is provided.
  final String? updateLabel;

  /// Fallback line shown instead of the CTA when [onUpdate] is `null`
  /// (no usable store link) — e.g. "Update the app from your store."
  final String? manualHint;

  /// Store action behind the CTA — `null` hides the button entirely.
  final VoidCallback? onUpdate;

  /// Icon at the top of the screen.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Blocks the Android back gesture/button: the screen must not be
      // leavable until the app is updated.
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IconBadge(icon: icon),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              if (onUpdate != null && updateLabel != null)
                FilledButton(onPressed: onUpdate, child: Text(updateLabel!))
              else if (manualHint != null)
                Text(
                  manualHint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The update icon in a tinted disc — the visual hook at the top.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 36, color: colors.onPrimaryContainer),
      ),
    );
  }
}
