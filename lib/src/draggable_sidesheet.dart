import 'package:flutter/material.dart';

import 'sheet_direction.dart';
import 'panel_controller.dart';
import 'panel_group_controller.dart';
import 'sheet_tab.dart';
import 'sheet_coordinator.dart';

class DraggableSideSheet extends StatefulWidget {
  final SheetDirection direction;

  // Single-child mode. Ignored when [tabs] is provided.
  final Widget? child;

  // Tab mode: each tab is a real stacked sheet with its own animation.
  final List<SheetTab>? tabs;

  final bool initiallyOpen;

  // Single-sheet controller. Ignored in tab mode.
  final PanelController? controller;

  // Tab-group controller. Required (or null for internal) in tab mode.
  final PanelGroupController? groupController;

  // Makes sure only one group of sheets is open at a time (L/R/T/B)
  final SheetCoordinator coordinator;

  final double expandedSize;
  final Color scrimColor;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool swipeToClose;
  final bool railToggleEnabled;
  final double railIconSize;
  final Color? railBackgroundColor;
  final Color? railIconColor;
  final bool edgeDragEnabled;
  final double edgeDragWidth;
  final bool keyboardAware;
  final bool showHandle;

  final ValueChanged<int>? onTabOpened;
  final ValueChanged<int>? onTabClosed;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final Alignment fanAlignment;
  final double fanSpacing;
  final double fanEdgeOffset;

  DraggableSideSheet({
    super.key,
    required this.direction,
    this.child,
    this.tabs,
    this.initiallyOpen = false,
    this.controller,
    this.groupController,
    SheetCoordinator? coordinator,
    this.expandedSize = 0.7,
    this.scrimColor = const Color(0x66000000),
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOutCubic,
    this.swipeToClose = true,
    this.railToggleEnabled = true,
    this.railIconSize = 48.0,
    this.railBackgroundColor,
    this.railIconColor,
    this.edgeDragEnabled = true,
    this.edgeDragWidth = 32.0,
    this.keyboardAware = true,
    this.showHandle = false,
    this.onTabOpened,
    this.onTabClosed,
    this.onOpen,
    this.onClose,
    this.fanAlignment = Alignment.center,
    this.fanSpacing = 8.0,
    this.fanEdgeOffset = 0.0,

  }) : assert(
         // compile time rules. you cant construct without tabs and content
         child != null || (tabs != null && tabs.isNotEmpty),
         'Provide either child or a non-empty tabs list.',
       ),
       // Must have a tab or a controller, not both.
       assert(
         tabs == null || controller == null,
         'In tab mode, pass groupController, not controller.',
       ),
       coordinator = coordinator ?? SheetCoordinator.shared;

  @override
  State<DraggableSideSheet> createState() => _DraggableSideSheetState();
  
}



/// One state hosts BOTH modes (single sheet and tab group). They share:
/// geometry ([SheetDirectionX]), drag math, coordinator scope, and the
/// sheet-body chrome ([_buildSheetBody]).
///
/// CANON: Positioned must be a DIRECT child of Stack — always. Wrappers
/// that create render objects (AnimatedOpacity, IgnorePointer,
/// ExcludeSemantics, ...) go INSIDE the Positioned, never around it.
/// Violating this twice in one session is why it's written down here.
class _DraggableSideSheetState extends State<DraggableSideSheet>
    with TickerProviderStateMixin {
  static const _flingVelocity = 350.0;
  bool _lastSettledOpen = false;
  bool _wasOpenForScope = false;
  bool _wasForeign = false;

  double _alongStart(Size size, double extent) {
    final insets = MediaQuery.paddingOf(context);
    final (safeStart, safeEnd) = switch (widget.direction) {
      SheetDirection.left || SheetDirection.right => (insets.top, insets.bottom),
      SheetDirection.top || SheetDirection.bottom => (insets.left, insets.right),
    };
    final edgeLen = widget.direction.isHorizontal ? size.height : size.width;
    final avail = edgeLen - safeStart - safeEnd;
    final comp = widget.direction.fanAlong(widget.fanAlignment);

    // comp=-1 flush to the start, 0 centered, +1 flush to the end.
    var pos = avail < extent ? (avail - extent) / 2 : (avail - extent) / 2 * (1 + comp);

    final abs = safeStart + pos;
    // Worst-case clamp: never closer than 16px to a physical edge,
    // even when the row barely fits.
    final hi = edgeLen - extent - 16.0;
    return abs.clamp(16.0, hi < 16.0 ? 16.0 : hi);
  }

  // ---- Single-sheet mode ----
  late final PanelController _internalSingle = PanelController();
  PanelController get _panel => widget.controller ?? _internalSingle;
  late final AnimationController _anim;

  // ---- Tab mode ----
  late final PanelGroupController _internalGroup = PanelGroupController();
  PanelGroupController get _group => widget.groupController ?? _internalGroup;
  List<AnimationController> _tabAnims = [];

  // Cached merged listenables. Recreating Listenable.merge on every
  // build forces AnimatedBuilder to unsubscribe/resubscribe every
  // controller on every frame — a hot-path allocation.
  Listenable _groupListenable = Listenable.merge(const []);
  Listenable? _singleListenable;

  // Rebuilds the cached tab-mode listenable after controller churn.
  void _refreshGroupListenable() {
    _groupListenable = Listenable.merge([..._tabAnims, _coordinator]);
  }

  // While an icon drag is consuming itself as "close frontmost",
  // further pan events are ignored.
  bool _iconDragClosing = false;

  bool get _isTabMode => widget.tabs != null;

  SheetCoordinator get _coordinator => widget.coordinator;

  /// Another widget owns the open slot — fade our icons out and
  /// keep them off any sheets. Derived, never stored.
  bool get _foreignOpen => _coordinator.anyOpen && !_coordinator.isOwner(this);

  @override
  void initState() {
    super.initState();
    _coordinator.addListener(_onForeignSheet);
    if (_isTabMode) {
      _rebuildTabAnims(null);
      _refreshGroupListenable();
      _group.addListener(_onGroupChanged);
      if (widget.groupController != null) {
        _onGroupChanged(); // external controller may arrive with sheets open
      } else if (widget.initiallyOpen) {
        _group.open(0);
      }
    } else {
      _anim = AnimationController(
        vsync: this,
        duration: widget.animationDuration,
        value: widget.initiallyOpen ? 1.0 : 0.0,
      );
      _anim.addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          final open = _anim.value > 0.5;
          if (open != _lastSettledOpen) {
            _lastSettledOpen = open;
            (open ? widget.onOpen : widget.onClose)?.call();
          }
        }
      });
      _singleListenable = Listenable.merge([_anim, _coordinator]);
      _panel.addListener(_onPanelChanged);
      if (widget.controller != null && widget.controller!.isOpen) {
        _onPanelChanged();
      }
      if (widget.initiallyOpen) {
        _panel.settle(open: true);
      }
    }
  }

  /// Applies the open/collapse transition to the coordinator.
  /// Intent-derived only (called from controller listeners, never
  /// from animation ticks) — preserves the one-way invariant.
  void _syncScope(bool nowOpen) {
    if (nowOpen && !_wasOpenForScope) {
      _coordinator.claim(this);
    } else if (!nowOpen && _wasOpenForScope) {
      _coordinator.release(this);
    }
    _wasOpenForScope = nowOpen;
  }

  // A foreign widget claimed (or released) the open slot.
  void _onForeignSheet() {
    if (_foreignOpen) {
      if (_isTabMode) {
        if (!_group.isCollapsed) _group.closeAll();
      } else {
        if (_panel.isOpen) _panel.close();
      }
    }
    // Repaint only when the fade target actually flipped — the claiming
    // widget is also notified and has nothing to repaint for.
    if (mounted && _foreignOpen != _wasForeign) {
      _wasForeign = _foreignOpen;
      setState(() {});
    }
  }

  void _rebuildTabAnims(List<double>? initialValues) {
    assert(_isTabMode);
    final n = widget.tabs!.length;
    _tabAnims = [
      for (var i = 0; i < n; i++)
        AnimationController(
          vsync: this,
          duration: widget.animationDuration,
          value: initialValues != null
              ? (i < initialValues.length ? initialValues[i] : 0.0)
              : (_group.isOpen(i) ? 1.0 : 0.0),
        ),
    ];
  }

  @override
  void didUpdateWidget(DraggableSideSheet old) {
    super.didUpdateWidget(old);
    if (old.coordinator != _coordinator) {
      // Unsubscribe BEFORE releasing — release() notifies synchronously
      // and a still-attached listener would setState a defunct element.
      old.coordinator.removeListener(_onForeignSheet);
      old.coordinator.release(this);
      _wasOpenForScope = false;
      _wasForeign = false;
      _coordinator.addListener(_onForeignSheet);
      if (_isTabMode) {
        _refreshGroupListenable();
      } else {
        _singleListenable = Listenable.merge([_anim, _coordinator]);
      }
      // Re-claim AFTER this frame: claim() notifies synchronously and
      // _onForeignSheet may setState — illegal inside didUpdateWidget.
      if (_isTabMode ? !_group.isCollapsed : _panel.isOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncScope(true);
        });
      }
    }
    if (_isTabMode &&
        (widget.tabs!.length != _tabAnims.length ||
            widget.animationDuration != old.animationDuration)) {
      final vals = [for (final a in _tabAnims) a.value];
      for (final a in _tabAnims) {
        a.dispose();
      }
      _rebuildTabAnims(vals);
      _refreshGroupListenable();
    }
  }

  void _onPanelChanged() {
    _syncScope(_panel.isOpen);

    final target = _panel.isOpen ? 1.0 : 0.0;
    if ((_anim.value - target).abs() < 0.001) return;
    _anim.animateTo(
      target,
      duration: widget.animationDuration,
      curve: widget.animationCurve,
    );
  }

  void _onGroupChanged() {
    _syncScope(!_group.isCollapsed);

    // Always repaint — fixes the silent no-repaint bug.
    setState(() {});

    final open = _group.openTabsRef;
    for (var i = 0; i < _tabAnims.length; i++) {
      final target = open.contains(i) ? 1.0 : 0.0;
      final anim = _tabAnims[i];
      if ((anim.value - target).abs() < 0.001) continue;
      anim.animateTo(
        target,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    }
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onForeignSheet);
    _coordinator.release(this);

    if (_isTabMode) {
      _group.removeListener(_onGroupChanged);
      for (final a in _tabAnims) {
        a.dispose();
      }
      if (widget.groupController == null) _internalGroup.dispose();
    } else {
      _panel.removeListener(_onPanelChanged);
      if (widget.controller == null) _internalSingle.dispose();
      _anim.dispose();
    }
    super.dispose();
  }

  // ---- Geometry ----

  double _expandedPixels(Size size) {
    final axisSize = widget.direction.isHorizontal ? size.width : size.height;
    return widget.expandedSize <= 1.0
        ? axisSize * widget.expandedSize
        : widget.expandedSize.clamp(0.0, axisSize);
  }

  EdgeInsets _contentPadding(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final bottom = widget.keyboardAware
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return widget.direction.contentPadding(safe, bottom);
  }

  // ---- Drag handling ----

  void _onDragStart(AnimationController anim) => anim.stop();

  void _onDragUpdate(AnimationController anim, DragUpdateDetails d) {
    final raw = widget.direction.isHorizontal ? d.delta.dx : d.delta.dy;
    final expanded = _expandedPixels(MediaQuery.sizeOf(context));
    anim.value =
        (anim.value + widget.direction.openingComponent(raw) / expanded).clamp(
          0.0,
          1.0,
        );
  }

  // velocity controller for dragging the target
  double _dragTarget(AnimationController anim, DragEndDetails d) {
    final v = widget.direction.isHorizontal
        ? d.velocity.pixelsPerSecond.dx
        : d.velocity.pixelsPerSecond.dy;
    final openVel = widget.direction.openingComponent(v);
    if (openVel > _flingVelocity) return 1.0;
    if (openVel < -_flingVelocity) return 0.0;
    return anim.value >= 0.5 ? 1.0 : 0.0;
  }

  // Single-mode drag outcome: report intent to the controller, then
  // animate. Used identically by the handle, the edge strip and the
  // rail icon — the gesture just decides HOW it ended.
  void _settleSingleFromDrag(DragEndDetails d) {
    final target = _dragTarget(_anim, d);
    _panel.settle(open: target == 1.0);
    _anim.animateTo(
      target,
      duration: widget.animationDuration,
      curve: widget.animationCurve,
    );
  }

  // ---- Tab-mode icon gestures ----

  void _onIconPanStart(int i, DragStartDetails d) {
    if (_group.isCollapsed) {
      // Dragging a collapsed icon drags THAT sheet open, following the finger.
      // Claims the coordinator — foreign sheets animate closed underneath.
      _group.open(i);
      _onDragStart(_tabAnims[i]);
      _iconDragClosing = false;
    } else {
      // Any drag while sheets are open closes the frontmost sheet.
      _group.closeTopmost();
      _iconDragClosing = true;
    }
  }

  void _onIconPanUpdate(int i, DragUpdateDetails d) {
    if (_iconDragClosing) return;
    _onDragUpdate(_tabAnims[i], d);
  }

  void _onIconPanEnd(int i, DragEndDetails d) {
    if (_iconDragClosing) {
      _iconDragClosing = false;
      return;
    }
    final target = _dragTarget(_tabAnims[i], d);
    _group.settle(i, open: target == 1.0);
    _tabAnims[i].animateTo(
      target,
      duration: widget.animationDuration,
      curve: widget.animationCurve,
    );
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    if (_isTabMode) {
      return AnimatedBuilder(
        animation: _groupListenable,
        builder: (context, _) => _buildGroup(size, theme),
      );
    }
    return AnimatedBuilder(
      animation: _singleListenable!,
      builder: (context, _) {
        final t = _anim.value;
        final expanded = _expandedPixels(size);
        final visible = expanded * t;

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildScrim(t: t, onTap: _panel.close),
            Positioned.fromRect(
              rect: widget.direction.panelRect(size, t, expanded),
              child: _buildSheetBody(
                theme: theme,
                content: widget.child!,
                anim: _anim,
                handleKey: const Key('ds_handle'),
                onDragEnd: _settleSingleFromDrag,
              ),
            ),
            _buildRail(size, visible, theme),
          ],
        );
      },
    );
  }

  /// Scrim shared by both modes: alpha follows [t] (single: sheet
  /// progress; group: most-visible sheet), tap routes to [onTap].
  /// [bottomInset] lifts it above the keyboard for bottom sheets.
  Widget _buildScrim({
    required double t,
    required GestureTapCallback onTap,
    double bottomInset = 0.0,
  }) {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: IgnorePointer(
          ignoring: t <= 0.0,
          child: GestureDetector(
            onTap: onTap,
            child: ColoredBox(
              color: widget.scrimColor.withValues(
                alpha: widget.scrimColor.a * t,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hides an icon cluster while a foreign sheet is open — icons can
  /// never sit on top of another edge's sheets, regardless of screen size.
  ///
  /// IMPORTANT: this must wrap the CONTENT of a Positioned, never the
  /// Positioned itself — Positioned must remain a direct child of Stack.
  Widget _fadeWhenForeign(Widget cluster) {
    return IgnorePointer(
      ignoring: _foreignOpen,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: _foreignOpen ? 0.0 : 1.0,
        child: cluster,
      ),
    );
  }

  /// The body of ONE sheet — Material chrome, optional handle, content,
  /// and edge grab strip. Identical for single mode (content: child,
  /// single controller gesture routing) and every tab in a group
  /// (content: tab.child, group gesture routing). Only the keys and
  /// the pan-end handler differ between call sites.
  Widget _buildSheetBody({
    required ThemeData theme,
    required Widget content,
    required AnimationController anim,
    Key? handleKey,
    Key? stripKey,
    required void Function(DragEndDetails) onDragEnd,
  }) {
    return Material(
      elevation: 8,
      borderRadius: widget.direction.panelRadius,
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: _contentPadding(context),
              child: Column(
                children: [
                  if (widget.showHandle && widget.swipeToClose)
                    _buildHandle(theme, handleKey, anim, onDragEnd),
                  Expanded(child: ClipRect(child: content)),
                ],
              ),
            ),
          ),
          if (widget.edgeDragEnabled && widget.swipeToClose)
            _buildEdgeStrip(stripKey, anim, onDragEnd),
        ],
      ),
    );
  }

  /// The drag handle pill. Present when [DraggableSideSheet.showHandle]
  /// and swipe-to-close are both enabled.
  Widget _buildHandle(
    ThemeData theme,
    Key? key,
    AnimationController anim,
    void Function(DragEndDetails) onDragEnd,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _onDragStart(anim),
      onPanUpdate: (d) => _onDragUpdate(anim, d),
      onPanEnd: onDragEnd,
      child: SizedBox(
        key: key,
        height: 28,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  /// Translucent grab strip along the sheet's inner boundary, for
  /// pulling a sheet closed from its edge.
  Widget _buildEdgeStrip(
    Key? key,
    AnimationController anim,
    void Function(DragEndDetails) onDragEnd,
  ) {
    final gesture = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _onDragStart(anim),
      onPanUpdate: (d) => _onDragUpdate(anim, d),
      onPanEnd: onDragEnd,
      child: SizedBox(key: key, child: const SizedBox.expand()),
    );
    return widget.direction.edgeStrip(widget.edgeDragWidth, gesture);
  }

  /// Visible extent of the outermost sheet — the whole fan parks
  /// just beyond this.
  double _outerExtent(Size size) {
    final expanded = _expandedPixels(size);
    var maxExtent = 0.0;
    for (final a in _tabAnims) {
      final e = a.value * expanded;
      if (e > maxExtent) maxExtent = e;
    }
    return maxExtent;
  }

  Widget _buildGroup(Size size, ThemeData theme) {
    final expanded = _expandedPixels(size);
    final bottomInset =
        widget.direction == SheetDirection.bottom && widget.keyboardAware
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    final tabs = widget.tabs!;
    final s = widget.railIconSize.clamp(40.0, 56.0);

    // Shared scrim: alpha follows the most-visible sheet; tap closes all.
    var maxT = 0.0;
    for (final a in _tabAnims) {
      if (a.value > maxT) maxT = a.value;
    }
    final extent = tabs.length * s + (tabs.length - 1) * widget.fanSpacing;
    final start = _alongStart(size, extent);

    final outerExtent = _outerExtent(size);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildScrim(t: maxT, onTap: _group.closeAll, bottomInset: bottomInset),

        // Sheets, ascending tab order so higher indices paint on top.
        for (var i = 0; i < tabs.length; i++)
          Positioned.fromRect(
            rect: widget.direction.panelRect(
              size,
              _tabAnims[i].value,
              expanded,
            ),
            child: _buildSheetBody(
              theme: theme,
              content: tabs[i].child,
              anim: _tabAnims[i],
              handleKey: Key('ds_handle_$i'),
              stripKey: Key('ds_edge_strip_$i'),
              onDragEnd: (d) => _onIconPanEnd(i, d),
            ),
          ),

        // Tab fan parked uniformly beyond outermost sheet. Each tab's
        // button applies its own foreign-fade INSIDE its Positioned —
        // never between the Stack and its Positioned children.
        for (var i = 0; i < tabs.length; i++)
          _buildFanTab(
            size,
            tabs[i],
            i,
            s,
            start + i * (s + widget.fanSpacing),
            outerExtent,
          ),
      ],
    );
  }

  Positioned _buildFanTab(
    Size size,
    SheetTab tab,
    int i,
    double s,
    double alongEdge,
    double outerExtent,
  ) {
    final open = _group.isOpen(i);
    // Equal full opacity when collapsed; dim only if open AND covered.
    final covered = open && _group.anyOpenAbove(i);

    var fromEdge = outerExtent + 8 + widget.fanEdgeOffset.clamp(0.0, double.infinity);
    if (widget.direction == SheetDirection.bottom && widget.keyboardAware) {
      fromEdge += MediaQuery.viewInsetsOf(context).bottom;
    }

    final button = GestureDetector(
      onTap: widget.railToggleEnabled ? () => _group.tapTab(i) : null,
      onPanStart: widget.swipeToClose ? (d) => _onIconPanStart(i, d) : null,
      onPanUpdate: widget.swipeToClose ? (d) => _onIconPanUpdate(i, d) : null,
      onPanEnd: widget.swipeToClose ? (d) => _onIconPanEnd(i, d) : null,
      child: _FanTabIcon(
        index: i,
        tab: tab,
        open: open,
        covered: covered,
        size: s,
        railBackgroundColor: widget.railBackgroundColor,
        railIconColor: widget.railIconColor,
      ),
    );

    // Foreign-fade wraps the button, inside the Positioned.
    final fadedButton = _fadeWhenForeign(button);

    return widget.direction.edgeIcon(fromEdge, alongEdge, s, fadedButton);
  }

  // ---- Single-sheet rail ----

  Widget _buildRail(Size size, double visible, ThemeData theme) {
    final s = widget.railIconSize;

    Widget button = GestureDetector(
      onTap: widget.railToggleEnabled ? _panel.toggle : null,
      onPanStart: widget.swipeToClose ? (_) => _onDragStart(_anim) : null,
      onPanUpdate: widget.swipeToClose ? (d) => _onDragUpdate(_anim, d) : null,
      onPanEnd: widget.swipeToClose ? _settleSingleFromDrag : null,
      child: Container(
        key: const Key('ds_rail'),
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: widget.railBackgroundColor ?? theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(s * 0.25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.menu,
            size: s * 0.5,
            color: widget.railIconColor ?? theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );

    // Foreign-fade wraps the button, inside the Positioned.
    final fadedButton = _fadeWhenForeign(button);

    final alongEdge = _alongStart(size, s);
    return widget.direction.edgeIcon(
      visible + 8 + widget.fanEdgeOffset.clamp(0.0, double.infinity),
      alongEdge,
      s,
      fadedButton,
    );
  }
}

class _FanTabIcon extends StatelessWidget {
  const _FanTabIcon({
    required this.index,
    required this.tab,
    required this.open,
    required this.covered,
    required this.size,
    this.railBackgroundColor,
    this.railIconColor,
  });

  /// Position in the tab list — used only for the `ds_tab_$i` test key.
  final int index;
  final SheetTab tab;
  final bool open;
  final bool covered;
  final double size;

  /// Widget-level fallbacks the per-tab colors defer to when null.
  final Color? railBackgroundColor;
  final Color? railIconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = size;

    return Semantics(
      // Compose the badge INTO the label deliberately — otherwise the
      // semantics engine merges the badge's raw Text("3") into the
      // label as "Inbox\n3". The badge visual is ExcludeSemantics'd below.
      label: switch (tab.badge) {
        final b? when b > 0 => '${tab.label}, $b unread${open ? ', open' : ''}',
        _ => '${tab.label}${open ? ', open' : ''}',
      },
      button: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: covered ? 0.45 : 1.0,
        child: Container(
          key: Key('ds_tab_$index'),
          width: s,
          height: s,
          decoration: tab.iconBezel
              ? BoxDecoration(
                  color:
                      tab.backgroundColor ??
                      railBackgroundColor ??
                      (open
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest),
                  borderRadius: BorderRadius.circular(s * 0.25),
                  boxShadow: open
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : const [],
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: tab.iconWidget != null
                    ? SizedBox.square(
                        dimension: tab.iconBezel ?  s * 0.5 : s,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: tab.iconWidget,
                        ),
                      )
                    : Icon(
                        tab.icon,
                        size: s * 0.5,
                        color:
                            tab.iconColor ??
                            railIconColor ??
                            (open
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant),
                      ),
              ),
              if (tab.badge != null && tab.badge! > 0)
                // Positioned must be the DIRECT child of the Stack —
                // ExcludeSemantics goes inside it, never around it.
                Positioned(
                  top: -6,
                  right: -6,
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: theme.scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      constraints: BoxConstraints(
                        minWidth: s * 0.4,
                        minHeight: s * 0.4,
                      ),
                      child: Center(
                        child: Text(
                          tab.badge.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onError,
                            fontSize: (s * 0.22).roundToDouble(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
