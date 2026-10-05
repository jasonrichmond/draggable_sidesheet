import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draggable_sidesheet/draggable_sidesheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('rail tap toggles the sheet open and closed', (tester) async {
    final controller = PanelController();
    await tester.pumpWidget(_wrap(DraggableSideSheet(
      direction: SheetDirection.left,
      controller: controller,
      child: const Text('Panel content'),
    )));

    expect(controller.isOpen, isFalse);
    await tester.tap(find.byKey(const Key('ds_rail')));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    
    await tester.tap(find.byKey(const Key('ds_rail')));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('partial drag settles closed when released below halfway', (tester) async {
    final controller = PanelController();
    await tester.pumpWidget(_wrap(DraggableSideSheet(
      direction: SheetDirection.left,
      controller: controller,
      child: const Text('Panel content'),
    )));

    controller.open();
    await tester.pumpAndSettle();
    
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final expanded = size.width * 0.7; // expandedSize 0.7 from the default
    final gesture = await tester.startGesture(
        Offset(expanded - 16, size.height / 2));
    await gesture.moveBy(const Offset(-400, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  test('SheetDirection extension helpers', () {
    expect(SheetDirection.left.isHorizontal, isTrue);
    expect(SheetDirection.bottom.isVertical, isTrue);
    expect(SheetDirection.right.isHorizontal, isTrue);
    expect(SheetDirection.top.isVertical, isTrue);
  });

  testWidgets('rail tap toggles the sheet open and closed', (tester) async {
  final controller = PanelController();
  await tester.pumpWidget(_wrap(DraggableSideSheet(
    direction: SheetDirection.left,
    controller: controller,
    child: const Text('Panel content'),
  )));

  debugPrint('BEFORE FIRST TAP: isOpen=${controller.isOpen}');
  expect(controller.isOpen, isFalse);
  
  await tester.tap(find.byKey(const Key('ds_rail')));
  await tester.pumpAndSettle();
  debugPrint('AFTER OPEN: isOpen=${controller.isOpen}');
  expect(controller.isOpen, isTrue);
  
  debugPrint('BEFORE SECOND TAP: isOpen=${controller.isOpen}');
  await tester.tap(find.byKey(const Key('ds_rail')));
  debugPrint('AFTER SECOND TAP (before settle): isOpen=${controller.isOpen}');
  await tester.pumpAndSettle();
  debugPrint('AFTER SETTLE: isOpen=${controller.isOpen}');
  expect(controller.isOpen, isFalse);
});
}