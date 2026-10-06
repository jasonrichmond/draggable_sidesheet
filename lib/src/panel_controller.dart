import 'package:flutter/foundation.dart';

class PanelController extends ChangeNotifier {
  PanelController([this.debugLabel]);

  final String? debugLabel;

  bool _isOpen = false;

  bool get isOpen => _isOpen;

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle() => _isOpen ? close() : open();

void settle({required bool open}) {
  if (_isOpen == open) return;
  _isOpen = open;
  notifyListeners();
}

  @override
  String toString() =>
      'PanelController(${debugLabel ?? 'unlabelled'}, isOpen: $_isOpen)';
}