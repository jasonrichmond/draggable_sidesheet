# draggable_sidesheet

A multi-directional draggable panel for Flutter. Sheets anchor to any screen
edge — left, right, top, or bottom — and slide over your content instead of
consuming navigation real estate. Ideal for map-first apps, dashboards, and any
layout where a persistent bottom nav bar gets in the way.

![demo](doc/demo.gif)

## Features

- **Four anchor directions** — `left`, `right`, `top`, `bottom`
- **Persistent rail trigger** — a floating button that always stays visible,
  rides the panel's edge, and both *taps* to toggle and *drags* to pull the
  panel open or closed
- **Tab groups (folder behavior)** — pass `tabs:` instead of `child:` and each
  tab becomes a real stacked sheet with its own icon, badge, label, and
  content. Pull one out; the others stay docked on the edge
- **Cover & reveal** — tap a lower tab and the sheets above it slide off;
  sheets below stay open underneath, like digging to a folder divider
- **Cross-edge exclusivity** — a shared `SheetCoordinator` guarantees only one
  edge has sheets open at a time; foreign icon clusters fade out so icons never
  obstruct another edge's sheets
- **Parked icon fan** — when any sheet is open, the whole tab fan slides out
  past the outermost sheet edge and stays parked there until the last sheet
  closes. Fully collapsed, all icons render equal weight
- **State preserved** — every tab's content stays mounted across open/close
  *and* cover/reveal cycles (scroll positions, form input, stream state)
- **Edge dragging** — grab the panel's leading edge via an invisible drag strip
- **Fling detection & snap decisions** — velocity-based commit with a halfway
  settle threshold for released drags
- **Keyboard aware** — bottom-anchored sheets pad above the on-screen keyboard
- **Safe-area aware** — notch and gesture-bar insets respected per direction
- **Accessible** — fan tabs expose composed semantics labels (including badge
  counts) to screen readers
- **Programmatic control** — `PanelController` for singles,
  `PanelGroupController` for tab groups

## Usage

### Basic sheet

    final _controller = PanelController();

    Stack(
      children: [
        const MapScreen(),
        DraggableSideSheet(
          direction: SheetDirection.left,
          controller: _controller,
          expandedSize: 0.7,          // 70% of screen width
          onOpen: () => debugPrint('invites opened'),
          onClose: () => debugPrint('invites closed'),
          child: const InvitesView(),
        ),
      ],
    )

The sheet draws itself — scrim, panel, and rail are laid out internally with
`StackFit.expand`, so it fills whatever box you place it in, including inside
another `Stack` under loose constraints.

### Tab groups — the folder

Pass `tabs:` (instead of `child:`) to get stacked sheets with an icon fan
riding the edge:

    final _group = PanelGroupController('left');

    DraggableSideSheet(
      direction: SheetDirection.left,
      groupController: _group,
      expandedSize: 0.7,
      tabs: [
        SheetTab(
          icon: Icons.inbox_outlined,
          label: 'Inbox',
          badge: 3,
          backgroundColor: Colors.orangeAccent,
          child: const InvitesView(),
        ),
        SheetTab(
          icon: Icons.map_outlined,
          label: 'Map',
          child: const MapLayersView(),
        ),
      ],
    );

Behavior rules:

- **Tap an icon** — that sheet slides over everything; sheets above it slide
  off first (they were covering it)
- **Tap the frontmost sheet's icon** — closes it, revealing what's beneath
- **Drag any icon while sheets are open** — closes the frontmost sheet, never
  switches tabs
- **Drag a collapsed icon** — opens *that* sheet, following your finger
- **Tap the scrim** — closes everything
- When fully collapsed, all icons render equally — no "front" tab until you
  pull one out

### Cross-edge exclusivity

By default every `DraggableSideSheet` in the app shares one
`SheetCoordinator` — only one edge can have open sheets at a time. Opening a
left-edge group slides a right-edge sheet closed and fades out top/bottom
rails until everything is collapsed again.

Opt out per-widget by injecting a private coordinator:

    DraggableSideSheet(
      direction: SheetDirection.left,
      coordinator: SheetCoordinator(),   // independent island
      tabs: [...],
    );

### Programmatic control

    // Singles
    _controller.open();
    _controller.close();
    _controller.toggle();

    // Tab groups — open/close state per tab, "frontmost" is always derived
    _group.open(1);              // sheet 1 covers sheet 0
    _group.closeTopmost();       // peel one layer
    _group.tapTab(0);            // reveal sheet 0 (closes everything above)
    _group.closeAll();           // scrim-tap equivalent
    _group.isOpen(1);
    _group.openTabs;             // read-only set

    // React to changes, including drag outcomes:
    _group.addListener(() => print('open: ${_group.openTabs}'));

`PanelGroupController.settle()` is reserved for gesture outcomes — user code
should stick to `open`/`close`/`tapTab`/`closeAll`.

See `example/` for a runnable demo with tab groups on the left and right
edges plus single panels on top and bottom.

## API

### `DraggableSideSheet`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `direction` | `SheetDirection` | *required* | Edge the sheet anchors to |
| `child` | `Widget?` | — | Single-panel content (mutually exclusive with `tabs`) |
| `tabs` | `List<SheetTab>?` | — | Tab group; each tab is a stacked sheet |
| `controller` | `PanelController?` | internal | Single-mode external control |
| `groupController` | `PanelGroupController?` | internal | Tab-mode external control |
| `coordinator` | `SheetCoordinator` | `.shared` | Exclusivity scope |
| `expandedSize` | `double` | `0.7` | Fraction of the axis (≤1.0) or pixels (>1.0) |
| `initiallyOpen` | `bool` | `false` | Mount with sheet 0 open (tab mode) |
| `scrimColor` | `Color` | `0x66000000` | Backdrop; transparent keeps tap-to-dismiss |
| `staggeredDismiss` | `bool` | `false` | Sequential multi-sheet dismissal |
| `staggerDelay` | `Duration` | `70ms` | Delay between staggered dismissals |
| `railIconSize` | `double` | `48.0` | Icon size (clamped 40–56 in tab mode) |
| `railBackgroundColor` / `railIconColor` | `Color?` | theme | Fallbacks for fan icons |
| `edgeDragEnabled` / `edgeDragWidth` | `bool` / `double` | `true` / `32.0` | Leading-edge drag strip |
| `showHandle` | `bool` | `false` | Decorative drag pill inside the panel |
| `swipeToClose` | `bool` | `true` | Drag gestures enabled |
| `keyboardAware` | `bool` | `true` | Bottom sheets pad above the keyboard |
| `animationDuration` / `animationCurve` | `Duration` / `Curve` | `300ms` / `easeOutCubic` | Motion |
| `onTabOpened` / `onTabClosed` | `ValueChanged<int>?` | — | Tab-mode settle events |
| `onOpen` / `onClose` | `VoidCallback?` | — | Fired when the sheet settles (single mode) |

### `SheetTab`

| Field | Type | Description |
|---|---|---|
| `icon` | `IconData` | Fan icon |
| `label` | `String` | Screen-reader label (badge composes into it) |
| `child` | `Widget` | Sheet content; stays mounted always |
| `badge` | `int?` | Badge count |
| `backgroundColor` / `iconColor` | `Color?` | Per-tab color overrides |

## Migration from 0.x

`railIcon`, `railBadge`, and `stackPeek` were removed. Rail icons on single
sheets are now always the menu glyph (style via `railBackgroundColor` /
`railIconColor`); badges and icons live on `SheetTab` in tab mode.

## Design notes

**Intent flows one way.** Controllers own *intent* (which sheets are open);
animations own *position*. The animation never writes intent back.
"Frontmost" is derived from the open set, never stored — it cannot desync.

**`Positioned` is always a direct child of `Stack`.** Any wrapper that creates
a render object (`AnimatedOpacity`, `IgnorePointer`, `ExcludeSemantics`...)
goes *inside* the `Positioned`, never between it and its `Stack`. Two
production bugs came from violating this.

**Unsubscribe before you notify during dispose.** Listener removal precedes
`release()` in `dispose()` — `release()` notifies synchronously, and a
registered listener would `setState` on a defunct element.

**Claims evict.** `SheetCoordinator.claim()` displaces previous owners rather
than accumulating them — an accumulating "claim" is an exclusivity bug wearing
a mutex costume.

## Testing

    flutter test

14 tests covering rail toggling, edge-drag dismissal, snap decisions, tab
promotion/reveal semantics, drag-to-open and drag-to-close-topmost, scroll
state preservation across cover/uncover, cross-edge exclusivity (both modes),
icon-cluster restoration, coordinator lifecycle, and semantics labels.

## License