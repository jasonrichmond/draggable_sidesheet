import 'package:flutter/widgets.dart';

/// One tab in a [DraggableSideSheet] tab fan.
///
/// The panel geometry, drag handling and animation are shared by all tabs;
/// a SheetTab only describes appearance and content. Children stay mounted
/// across open/close AND across tab switches (each tab is a real stacked
/// sheet, not content-swapping), so scroll positions and form state survive
/// everything.
class SheetTab {
  const SheetTab({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.child,
    this.badge,
    this.backgroundColor,
    this.iconColor,
  }) : assert(
          icon != null || iconWidget != null,
          'Provide either icon or iconWidget.',
        );

  /// Standard icon for this tab's fan button. Ignored when
  /// [iconWidget] is provided.
  final IconData? icon;

  /// Fully custom fan-button visual (e.g. an animated GIF), taking
  /// precedence over [icon]. Rendered inside a square of half the
  /// button size — build your widget un-sized; it gets fitted.
  final Widget? iconWidget;

  /// Human-readable name. Doubles as the screen-reader label.
  final String label;

  /// Panel content for this tab. Stays mounted at all times.
  final Widget child;

  /// Optional numeric badge, composed into the semantics label
  /// (e.g. 'Inbox, 3 unread'). Renders as a corner pill.
  final int? badge;

  /// Per-tab overrides; fall back to the widget-level rail colors when null.
  final Color? backgroundColor;
  final Color? iconColor;
}