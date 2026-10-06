import 'package:flutter/material.dart';

/// One tab in a [DraggableSideSheet] tab fan.
///
/// The panel geometry, drag handling and animation are shared by all tabs;
/// a SheetTab only describes appearance and content. Children stay mounted
/// across open/close AND across tab switches (IndexedStack), so scroll
/// positions and form state survive everything.
class SheetTab {
  const SheetTab({
    required this.icon,
    required this.label,
    required this.child,
    this.badge,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;

  /// Human-readable name. Doubles as the screen-reader label (closes
  /// the accessibility gap from the handover notes).
  final String label;

  /// Panel content for this tab. Stays mounted at all times.
  final Widget child;

  /// Optional numeric badge (same semantics as railBadge on single sheets).
  final int? badge;

  /// Per-tab overrides; fall back to the widget-level rail colors when null.
  final Color? backgroundColor;
  final Color? iconColor;
}