import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draggable_sidesheet/draggable_sidesheet.dart';

void main() {
  // The coordinator defaults to a STATIC shared instance — it leaks
  // owners across tests in the same process. Reset before each.
  setUp(() {
    SheetCoordinator.resetShared();
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  List<SheetTab> threeTabs({Widget Function(int)? body}) => [
    SheetTab(
      icon: Icons.inbox,
      label: 'Inbox',
      badge: 3,
      child: body?.call(0) ?? const Text('Inbox body'),
    ),
    SheetTab(
      icon: Icons.person,
      label: 'Invites',
      child: body?.call(1) ?? const Text('Invites body'),
    ),
    SheetTab(
      icon: Icons.star,
      label: 'Favorites',
      child: body?.call(2) ?? const Text('Favorites body'),
    ),
  ];

  // ---- Legacy single-sheet mode (regression guards) ----

  testWidgets('rail tap toggles the sheet open and closed', (tester) async {
    final controller = PanelController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          controller: controller,
          child: const Text('Panel content'),
        ),
      ),
    );

    expect(controller.isOpen, isFalse);
    await tester.tap(find.byKey(const Key('ds_rail')));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);

    await tester.tap(find.byKey(const Key('ds_rail')));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('partial drag settles closed below halfway', (tester) async {
    final controller = PanelController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          controller: controller,
          child: const Text('Panel content'),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final expanded = size.width * 0.7;
    final gesture = await tester.startGesture(
      Offset(expanded - 16, size.height / 2),
    );
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

  // ---- Tab-mode: controller semantics ----

  testWidgets('tapTab promotes a rear tab and opens it', (tester) async {
    final group = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: threeTabs(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ds_tab_1')));
    await tester.pumpAndSettle();
    expect(group.openTabs, {1});
    expect(group.topmostOpen, 1);
  });

  testWidgets('tapTab on the frontmost open tab closes it', (tester) async {
    final group = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: threeTabs(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ds_tab_2')));
    await tester.pumpAndSettle();
    expect(group.openTabs, {2});

    // Tap it again — toggles closed, fully collapsed.
    await tester.tap(find.byKey(const Key('ds_tab_2')));
    await tester.pumpAndSettle();
    expect(group.isCollapsed, isTrue);
  });

  testWidgets('tapping a LOWER tab slides the covering sheets off '
      '(closeAbove) — the lower sheet stays open underneath', (tester) async {
    final group = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: threeTabs(),
        ),
      ),
    );

    // Open tabs 0 then 2: tab 2 covers tab 0.
    group.open(0);
    await tester.pumpAndSettle();
    group.open(2);
    await tester.pumpAndSettle();
    expect(group.openTabs, {0, 2});

    // Tap tab 0: everything above 0 must close; 0 itself stays open.
    await tester.tap(find.byKey(const Key('ds_tab_0')));
    await tester.pumpAndSettle();
    expect(group.openTabs, {0});
    expect(group.topmostOpen, 0);
  });

  testWidgets('scrim tap closes everything (closeAll)', (tester) async {
    final group = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: threeTabs(),
          // Non-transparent scrim so there's something to hit-test.
          scrimColor: const Color(0x66000000),
        ),
      ),
    );

    group.open(0);
    group.open(1);
    group.open(2);
    await tester.pumpAndSettle();
    expect(group.openTabs, {0, 1, 2});

    // Tap a point well inside the scrim area (right side of the screen).
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width - 50, size.height / 2));
    await tester.pumpAndSettle();
    expect(group.isCollapsed, isTrue);
  });

  testWidgets('drag a collapsed icon opens THAT sheet (finger-following)', (
    tester,
  ) async {
    final group = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: threeTabs(),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('ds_tab_1')));
    final gesture = await tester.startGesture(center);
    // Step the drag — real moves at advancing timestamps. A single
    // 400px jump produces a degenerate velocity estimate.
    for (var step = 0; step < 15; step++) {
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(group.isOpen(1), isTrue);
    expect(group.openTabs, {1});
  });

  testWidgets('drag while sheets are open closes the frontmost — '
      'and never changes which tabs are "open" besides that', (tester) async {
    final group = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: threeTabs(),
        ),
      ),
    );

    group.open(0);
    group.open(2);
    await tester.pumpAndSettle();

    // Start a pan on any icon while open — must close topmost (2).
    final tab = find.byKey(const Key('ds_tab_0'));
    final gesture = await tester.startGesture(tester.getCenter(tab));
    await gesture.moveBy(const Offset(-200, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(group.openTabs, {0}, reason: 'drag must close only the topmost');
  });

  // ---- State preservation ----

  testWidgets('tab content state survives covering and uncovering', (
    tester,
  ) async {
    final group = PanelGroupController();
    final scroller = ScrollController();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(
          direction: SheetDirection.left,
          groupController: group,
          tabs: [
            SheetTab(
              icon: Icons.inbox,
              label: 'Inbox',
              child: ListView.builder(
                controller: scroller,
                itemCount: 50,
                itemBuilder: (_, k) => ListTile(title: Text('item $k')),
              ),
            ),
            SheetTab(
              icon: Icons.person,
              label: 'Invites',
              child: const Text('Invites'),
            ),
          ],
        ),
      ),
    );

    group.open(0);
    await tester.pumpAndSettle();
    scroller.jumpTo(750);
    await tester.pump();

    // Cover with tab 1, then reveal tab 0 again — offset must survive.
    group.open(1);
    await tester.pumpAndSettle();
    group.tapTab(0);
    await tester.pumpAndSettle();

    expect(
      scroller.offset,
      750,
      reason: 'scroll position must survive cover/uncover',
    );
  });

  // ---- Coordinator: cross-edge exclusivity ----

  testWidgets('opening one edge closes the other (global exclusivity)', (
    tester,
  ) async {
    final left = PanelGroupController();
    final right = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            DraggableSideSheet(
              direction: SheetDirection.left,
              groupController: left,
              tabs: threeTabs(),
            ),
            DraggableSideSheet(
              direction: SheetDirection.right,
              groupController: right,
              tabs: threeTabs(),
            ),
          ],
        ),
      ),
    );

    left.open(0);
    await tester.pumpAndSettle();
    expect(left.openTabs, {0});

    // Now open right — left must be closed by the coordinator.
    right.open(1);
    await tester.pumpAndSettle();
    expect(
      left.isCollapsed,
      isTrue,
      reason: 'foreign claim must close other edges',
    );
    expect(right.openTabs, {1});
  });

  testWidgets('single-sheet mode also defers to the coordinator', (
    tester,
  ) async {
    final top = PanelController();
    final right = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            DraggableSideSheet(
              direction: SheetDirection.right,
              groupController: right,
              tabs: threeTabs(),
            ),
            DraggableSideSheet(
              direction: SheetDirection.top,
              controller: top,
              child: const Text('top panel'),
            ),
          ],
        ),
      ),
    );

    top.open();
    await tester.pumpAndSettle();
    expect(top.isOpen, isTrue);

    right.open(0);
    await tester.pumpAndSettle();
    expect(
      top.isOpen,
      isFalse,
      reason: 'single sheet must release to a foreign group claim',
    );
  });

  testWidgets('releasing the last owner restores all icon clusters', (
    tester,
  ) async {
    final left = PanelGroupController();
    final right = PanelGroupController();
    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            DraggableSideSheet(
              direction: SheetDirection.left,
              groupController: left,
              tabs: threeTabs(),
            ),
            DraggableSideSheet(
              direction: SheetDirection.right,
              groupController: right,
              tabs: threeTabs(),
            ),
          ],
        ),
      ),
    );

    right.open(0);
    await tester.pumpAndSettle();

    // Left fan exists but is faded out (opacity animating/at 0).
    // Animate through the 180ms fade.
    await tester.pump(const Duration(milliseconds: 300));

    // Close everything on the right — left cluster must become
    // visible AND tappable again.
    right.closeAll();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    // Tappability proves the IgnorePointer lifted.
    await tester.tap(find.byKey(const Key('ds_tab_0')).first);
    await tester.pumpAndSettle();
    expect(left.openTabs, {0});
  });

  // ---- Accessibility (closes a known gap from the handover) ----

  testWidgets('fan tabs carry semantics labels', (tester) async {
    // Enable BEFORE pumping — semantics are only assembled on frames
    // that run after the handle exists.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        DraggableSideSheet(direction: SheetDirection.left, tabs: threeTabs()),
      ),
    );
    await tester.pump(); // belt-and-braces: flush semantics for the new tree

    expect(find.bySemanticsLabel('Inbox, 3 unread'), findsOneWidget);
    expect(find.bySemanticsLabel('Invites'), findsOneWidget);
    expect(find.bySemanticsLabel('Favorites'), findsOneWidget);
    handle.dispose();
  });
}