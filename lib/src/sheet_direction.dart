import 'package:flutter/widgets.dart';

/// Direction where the sheet anchors from the screen edge.
enum SheetDirection { left, right, top, bottom }

/// All direction-dependent geometry, encoded ONCE.
///
/// Five separate switches over this enum used to live in the widget
/// (rect, radius, edge strip, icon positioning, content padding). Any
/// sign flip or offset fix now lands here instead of in five places.
extension SheetDirectionX on SheetDirection {
  bool get isHorizontal =>
      this == SheetDirection.left || this == SheetDirection.right;
  bool get isVertical =>
      this == SheetDirection.top || this == SheetDirection.bottom;

  /// Left/top sheets slide toward LARGER coordinates as they open;
  /// right/bottom toward smaller. Raw drag deltas and velocities
  /// must be signed accordingly.
  bool get opensTowardLarger =>
      this == SheetDirection.left || this == SheetDirection.top;

  /// Signed contribution of [raw] (axis pixel delta or velocity)
  /// toward "more open".
  double openingComponent(double raw) => opensTowardLarger ? raw : -raw;

  /// Rect of the sheet at animation progress [t] (0 collapsed,
  /// 1 fully open) with visible extent [expanded].
  Rect panelRect(Size size, double t, double expanded) {
    final off = expanded * (1 - t);
    return switch (this) {
      SheetDirection.left => Rect.fromLTWH(-off, 0, expanded, size.height),
      SheetDirection.right => Rect.fromLTWH(
        size.width - expanded + off,
        0,
        expanded,
        size.height,
      ),
      SheetDirection.top => Rect.fromLTWH(0, -off, size.width, expanded),
      SheetDirection.bottom => Rect.fromLTWH(
        0,
        size.height - expanded + off,
        size.width,
        expanded,
      ),
    };
  }

  /// Rounded corners on the inner edge (facing the screen interior
  /// when open).
  BorderRadius get panelRadius => switch (this) {
    SheetDirection.left => const BorderRadius.horizontal(
      right: Radius.circular(16),
    ),
    SheetDirection.right => const BorderRadius.horizontal(
      left: Radius.circular(16),
    ),
    SheetDirection.top => const BorderRadius.vertical(
      bottom: Radius.circular(16),
    ),
    SheetDirection.bottom => const BorderRadius.vertical(
      top: Radius.circular(16),
    ),
  };

  /// Edge-grab strip along the sheet's inner boundary — what the user
  /// pulls on when the sheet is open. [child] must not itself be a
  /// Positioned; this returns one.
  Positioned edgeStrip(double width, Widget child) => switch (this) {
    SheetDirection.left => Positioned(
      top: 0, bottom: 0, right: 0, width: width, child: child),
    SheetDirection.right => Positioned(
      top: 0, bottom: 0, left: 0, width: width, child: child),
    SheetDirection.top => Positioned(
      left: 0, right: 0, bottom: 0, height: width, child: child),
    SheetDirection.bottom => Positioned(
      left: 0, right: 0, top: 0, height: width, child: child),
  };

  /// Positions a square (rail button or fan icon) offset [fromEdge]
  /// from the anchor edge and [alongEdge] along it. [child] must not
  /// itself be a Positioned; this returns one.
  Positioned edgeIcon(
    double fromEdge,
    double alongEdge,
    double size,
    Widget child,
  ) => switch (this) {
    SheetDirection.left => Positioned(
      left: fromEdge, top: alongEdge, width: size, height: size, child: child),
    SheetDirection.right => Positioned(
      right: fromEdge, top: alongEdge, width: size, height: size, child: child),
    SheetDirection.top => Positioned(
      top: fromEdge, left: alongEdge, width: size, height: size, child: child),
    SheetDirection.bottom => Positioned(
      bottom: fromEdge, left: alongEdge, width: size, height: size, child: child),
  };

  /// Safe-area content padding, with an extra [bottomInset] applied to
  /// bottom sheets only (keyboard awareness).
  EdgeInsets contentPadding(EdgeInsets safe, double bottomInset) =>
      switch (this) {
        SheetDirection.left => EdgeInsets.only(right: safe.right),
        SheetDirection.right => EdgeInsets.only(left: safe.left),
        SheetDirection.top => EdgeInsets.only(
          left: safe.left,
          right: safe.right,
        ),
        SheetDirection.bottom => EdgeInsets.only(
          left: safe.left,
          right: safe.right,
          bottom: bottomInset,
        ),
      };
}