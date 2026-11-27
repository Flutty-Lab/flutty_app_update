import 'package:flutty_app_update/src/app_update_service.dart';
import 'package:flutty_app_update/src/material.dart';

/// Builds the update action of an [UpdateBanner].
///
/// The [onUpdate] callback and [label] are the values the banner would have
/// passed to its default Material button, so a custom design system does not
/// need to reach back to the update service.
typedef UpdateBannerActionBuilder = Widget Function(
  BuildContext context,
  VoidCallback onUpdate,
  String label,
);

/// Builds the dismiss action of an [UpdateBanner].
///
/// The [onDismiss] callback records the dismissal before hiding the banner;
/// [tooltip] is the configured dismiss tooltip, if any.
typedef UpdateBannerDismissBuilder = Widget Function(
  BuildContext context,
  VoidCallback onDismiss,
  String? tooltip,
);

/// Dismissible banner shown while [UpdateStatus.recommended] applies.
///
/// Reads the dismissal state from the [service] on first build and
/// remembers the user's choice through it — the banner stays hidden until
/// a *different* version becomes recommended. Place it inside a widget
/// rebuilt on `AppUpdateService.statusChanges` (e.g. the root of the tab
/// bar).
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    required this.service,
    required this.message,
    this.updateLabel,
    this.dismissTooltip,
    this.onDismissed,
    this.actionBuilder,
    this.dismissBuilder,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  /// The service the banner asks for dismissal state, store opening and
  /// dismissal recording.
  final AppUpdateService service;

  /// Nudge text — e.g. "A new version is available."
  final String message;

  /// CTA label — shown only when `service.canOpenStore` is `true`.
  final String? updateLabel;

  /// Tooltip of the close button.
  final String? dismissTooltip;

  /// Called after the user dismissed the banner (e.g. extra reporting).
  final VoidCallback? onDismissed;

  /// Replaces the default Material update action when provided.
  ///
  /// The builder receives the store callback and the action label. `null`
  /// keeps the default [TextButton].
  final UpdateBannerActionBuilder? actionBuilder;

  /// Replaces the default Material close button when provided.
  ///
  /// The builder receives the dismissal callback and the configured tooltip.
  /// `null` keeps the default [IconButton].
  final UpdateBannerDismissBuilder? dismissBuilder;

  /// Banner background — defaults to `colorScheme.secondaryContainer`.
  final Color? backgroundColor;

  /// Banner foreground — defaults to `colorScheme.onSecondaryContainer`.
  final Color? foregroundColor;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  /// `null` while the dismissal state loads — keeps the banner from
  /// flashing for users who already dismissed this version.
  bool? _visible;

  @override
  void initState() {
    super.initState();
    widget.service.isRecommendedDismissed.then(
      (dismissed) {
        if (mounted) setState(() => _visible = !dismissed);
      },
      onError: (_) {
        // A store failure must not hide the prompt forever — show it.
        if (mounted) setState(() => _visible = true);
      },
    );
  }

  Future<void> _dismiss() async {
    await widget.service.dismissRecommended();
    if (!mounted) return;
    setState(() => _visible = false);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = widget.backgroundColor ?? colors.secondaryContainer;
    final foregroundColor =
        widget.foregroundColor ?? colors.onSecondaryContainer;
    return Material(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.system_update, size: 20, color: foregroundColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: foregroundColor),
              ),
            ),
            if (widget.service.canOpenStore && widget.updateLabel != null)
              widget.actionBuilder?.call(
                    context,
                    widget.service.openStore,
                    widget.updateLabel!,
                  ) ??
                  TextButton(
                    onPressed: widget.service.openStore,
                    child: Text(widget.updateLabel!),
                  ),
            widget.dismissBuilder?.call(
                  context,
                  _dismiss,
                  widget.dismissTooltip,
                ) ??
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: widget.dismissTooltip,
                  color: foregroundColor,
                  onPressed: _dismiss,
                ),
          ],
        ),
      ),
    );
  }
}
