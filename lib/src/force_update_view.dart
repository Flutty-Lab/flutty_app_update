import 'package:flutty_app_update/src/material.dart';

/// Builds the update CTA of a [ForceUpdateView].
///
/// The [onUpdate] callback and [label] are the values the view would have
/// passed to its default Material button, so a custom design system does not
/// need to reach back to the update service.
typedef ForceUpdateButtonBuilder = Widget Function(
  BuildContext context,
  VoidCallback onUpdate,
  String label,
);

/// Builds the icon badge at the top of a [ForceUpdateView].
typedef ForceUpdateIconBadgeBuilder = Widget Function(
  BuildContext context,
  IconData icon,
);

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
    this.updateButtonBuilder,
    this.iconBadgeBuilder,
    this.contentPadding,
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

  /// Replaces the default Material CTA when provided.
  ///
  /// The builder receives the store callback and the CTA label. `null` keeps
  /// the default [FilledButton].
  final ForceUpdateButtonBuilder? updateButtonBuilder;

  /// Replaces the default circular icon badge when provided.
  ///
  /// The builder receives the configured [icon]. `null` keeps the default
  /// Material badge.
  final ForceUpdateIconBadgeBuilder? iconBadgeBuilder;

  /// Padding around the whole content — defaults to `EdgeInsets.all(24)`.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Blocks the Android back gesture/button: the screen must not be
      // leavable until the app is updated.
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: contentPadding ?? const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              iconBadgeBuilder?.call(context, icon) ?? _IconBadge(icon: icon),
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
                updateButtonBuilder?.call(context, onUpdate!, updateLabel!) ??
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
