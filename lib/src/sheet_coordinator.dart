import 'package:flutter/foundation.dart';

/// Coordinates exclusivity across ALL [DraggableSideSheet] widgets in an
/// app — across edges (top/left/right/bottom) and across tab-groups.
///
/// A widget with open sheets "claims" the coordinator; every other
/// registered sheet hears the claim and animates itself closed. Icon
/// fans/rails of non-owners fade out while someone else is open, so
/// icons can never sit on top of another edge's sheets.
///
/// Uses a static shared instance by default (every sheet in the app
/// participates in one exclusive set). Inject separate instances via the
/// `coordinator` parameter to create independent islands.
class SheetCoordinator extends ChangeNotifier {
  SheetCoordinator();

  /// App-wide default. Shared by every sheet that doesn't inject one.
  static final SheetCoordinator shared = SheetCoordinator();

  final Set<Object> _openOwners = {};

  /// True when ANY registered widget has open sheets.
  bool get anyOpen => _openOwners.isNotEmpty;

  /// True when [owner] is among the currently-open widgets.
  bool isOwner(Object owner) => _openOwners.contains(owner);

  /// Called by a widget when it goes from collapsed to having open sheets.
  void claim(Object owner) {
    if (_openOwners.length == 1 && _openOwners.contains(owner)) return;
      _openOwners
      ..clear()
      ..add(owner);
    notifyListeners();
  }

  /// Called by a widget when it fully collapses again.
  void release(Object owner) {
    if (_openOwners.remove(owner)) notifyListeners();
  }

  /// Test helper: clears ownership without notifying.
  @visibleForTesting
  static void resetShared() => shared._openOwners.clear();
}