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
- **Edge dragging** — grab the panel's leading edge (the side opposite its
  anchor) anywhere along its length via an invisible drag strip
- **Fling detection** — velocity-based commit: flick to open, flick to close
- **Snap decisions** — released drags settle toward the nearest state
  (halfway threshold)
- **Backdrop scrim** — tap-to-dismiss, fades with panel progress, optional
- **Keyboard aware** — bottom-anchored sheets pad above the on-screen keyboard
- **Safe-area aware** — notch and gesture-bar insets respected per direction
- **State preserved** — panel content stays mounted and stateful across
  open/close cycles (streams, scroll positions, form input all survive)
- **Programmatic control** — `PanelController` for open/close/toggle from
  anywhere, safe to use with multiple simultaneous sheets

## Installation

This package is not yet on pub.dev. Use a path or git dependency:

```yaml
dependencies:
  draggable_sidesheet:
    path: ../draggable_sidesheet
```

## Usage

### Basic sheet

```dart
import 'package:draggable_sidesheet/draggable_sidesheet.dart';

final _controller = PanelController();

Stack(
  children: [
    const MapScreen(), // your base content — the map, canvas, whatever
    DraggableSideSheet(
      direction: SheetDirection.left,
      controller: _controller,
      expandedSize: 0.7,          // 70% of screen width
      railIcon: Icons.mail,
      railBadge: 3,              // optional badge count
      onOpen: () => debugPrint('invites opened'),
      onClose: () => debugPrint('invites closed'),
      child: const InvitesView(),
    ),
  ],
)
```

The sheet draws itself — scrim, panel, and rail are laid out internally with
`StackFit.expand`, so it fills whatever box you place it in, including inside
another `Stack` under loose constraints.

### Multiple sheets on one screen

Each sheet owns its rail, so several can coexist. Give each its own controller
and spell them out in your `Stack`:

```dart
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _invitesController = PanelController(debugLabel: 'invites');
  final _profileController = PanelController(debugLabel: 'profile');

  @override
  void dispose() {
    _invitesController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MapScreen(), // your base content

          // Invites hang off the left edge
          DraggableSideSheet(
            direction: SheetDirection.left,
            controller: _invitesController,
            railIcon: Icons.mail,
            railBadge: 3,
            expandedSize: 0.7,
            child: const InvitesView(),
          ),

          // Profile hangs off the right edge
          DraggableSideSheet(
            direction: SheetDirection.right,
            controller: _profileController,
            railIcon: Icons.person,
            expandedSize: 0.6,
            child: const ProfileView(),
          ),
        ],
      ),
    );
  }
}
```

This mirrors the shape most real apps will use — a map or canvas underneath,
a couple of feature panels on the edges — and also demonstrates disposing
controllers you own. The controllers are kept as named fields here, which
makes them easy to grab from elsewhere (e.g. tapping a notification deep-link
calls `_invitesController.open()`).

Tip: with overlapping sheets, set `scrimColor: Colors.transparent` on all but
the topmost sheet, or scrims will intercept each other's taps.

### Programmatic control

```dart
_controller.open();
_controller.close();
_controller.toggle();

// React to state, including drags:
_controller.addListener(() {
  if (!_controller.isOpen) refreshBadgeCount();
});
```

See `example/` for a runnable four-panel demo.

## API

| Parameter | Type | Default | Description |
|---|---|---|---|
| `direction` | `SheetDirection` | *required* | Edge the sheet anchors to |
| `child` | `Widget` | *required* | Panel content |
| `controller` | `PanelController?` | internal | External control; supply your own to observe state |
| `expandedSize` | `double` | `0.7` | Fraction of the axis (≤1.0) or pixels (>1.0) |
| `initiallyOpen` | `bool` | `false` | Mount in the open state |
| `scrimColor` | `Color` | `0x66000000` | Backdrop color; fully transparent disables dimming but keeps tap-to-dismiss |
| `railIcon` | `IconData` | `Icons.menu` | Rail trigger icon |
| `railIconSize` | `double` | `48.0` | Rail button size (any size works; badge scales) |
| `railBadge` | `int?` | — | Badge count on the rail |
| `railBackgroundColor` | `Color?` | `primary` | Rail fill color |
| `edgeDragEnabled` | `bool` | `true` | Invisible drag strip on the panel's leading edge |
| `edgeDragWidth` | `double` | `32.0` | Width of that strip |
| `showHandle` | `bool` | `false` | Decorative drag pill inside the panel |
| `swipeToClose` | `bool` | `true` | Drag-to-dismiss gestures |
| `keyboardAware` | `bool` | `true` | Bottom sheets pad above the keyboard |
| `animationDuration` | `Duration` | `300ms` | Open/close animation |
| `animationCurve` | `Curve` | `easeOutCubic` | Open/close easing |
| `onOpen` / `onClose` | `VoidCallback?` | — | Fired when the sheet settles |

## Design notes

**Intent flows one way.** The controller owns *intent* (open/closed); the
animation owns *position*. The animation never writes intent back — a rule
adopted after a class of bugs where mid-animation state feedback re-triggered
open actions during close. If you extend this package (e.g. snap points),
preserve the invariant: the sheet reports user-driven outcomes through
`PanelController.settle()`, never from animation ticks.

**Status events are distrusted.** Open/close callbacks derive openness from
the controller's position, not from `AnimationStatus`, which proved unreliable
on some animation paths.

## Testing

```bash
flutter test
```

The suite covers rail toggling, edge-drag dismissal, drag snap decisions, and
direction math, including regression tests for the controller/state-machine
bugs above.

## License
