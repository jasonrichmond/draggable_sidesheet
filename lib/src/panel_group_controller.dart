import 'package:flutter/foundation.dart';

/// Multi-sheet intent controller. Owns WHICH sheets are open — nothing else.
///
/// Invariant (same as PanelController's): the animation never writes here.
/// Only user gestures and controller calls mutate state. "Frontmost" is
/// always DERIVED (highest open index), never stored, so it cannot desync.
class PanelGroupController extends ChangeNotifier {
  PanelGroupController([this.debugLabel]);

  final String? debugLabel;

  final Set<int> _open = {};

  /// Read-only view of currently-open sheet indices.
  Set<int> get openTabs => Set.unmodifiable(_open);

  bool isOpen(int index) => _open.contains(index);

  /// Highest open index, or null when fully collapsed. Derived, never stored.
  int? get topmostOpen =>
      _open.isEmpty ? null : _open.reduce((a, b) => a > b ? a : b);

  /// True when fully collapsed — no differentiation between tabs.
  bool get isCollapsed => _open.isEmpty;

  void open(int index) {
    if (!_open.add(index)) return;
    notifyListeners();
  }

  void close(int index) {
    if (!_open.remove(index)) return;
    notifyListeners();
  }

  /// Closes every open sheet ABOVE [index]. Sheets below are untouched —
  /// they stay open underneath (the folder reveal).
  void closeAbove(int index) {
    final doomed = _open.where((i) => i > index).toList();
    if (doomed.isEmpty) return;
    _open.removeAll(doomed);
    notifyListeners();
  }

  /// Closes everything at once (scrim tap).
  void closeAll() {
    if (_open.isEmpty) return;
    _open.clear();
    notifyListeners();
  }

  /// Icon TAP semantics:
  ///  - tapping the frontmost open sheet closes it (reveal what's beneath)
  ///  - tapping any other sheet clears everything above it and opens it
  void tapTab(int index) {
    if (_open.contains(index) && topmostOpen == index) {
      close(index);
    } else {
      closeAbove(index);
      open(index);
    }
  }

  /// Closes just the frontmost sheet.
  void closeTopmost() {
    final t = topmostOpen;
    if (t != null) close(t);
  }

  /// Outcome report from user-driven motion of sheet [index].
  /// Silent (no notify) when the state wouldn't change.
  void settle(int index, {required bool open}) {
    if (open == _open.contains(index)) return;
    open ? _open.add(index) : _open.remove(index);
    notifyListeners();
  }

  @override
  String toString() =>
      'PanelGroupController(${debugLabel ?? 'unlabelled'}, open: $_open)';

  bool anyOpenAbove(int index) => _open.any((i) => i > index);

  @internal
  Set<int> get openTabsRef => _open;
}
