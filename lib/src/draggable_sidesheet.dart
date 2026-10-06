import 'dart:async';

import 'package:flutter/material.dart';

import 'sheet_direction.dart';
import 'panel_controller.dart';
import 'panel_group_controller.dart';
import 'sheet_tab.dart';
import 'sheet_coordinator.dart';

class DraggableSideSheet extends StatefulWidget {
  final SheetDirection direction;

  /// Single-child mode. Ignored when [tabs] is provided.
  final Widget? child;

  /// Tab mode: each tab is a real stacked sheet with its own animation.
  final List<SheetTab>? tabs;

  final bool initiallyOpen;

  /// Single-sheet controller. Ignored in tab mode.
  final PanelController? controller;

  /// Tab-group controller. Required (or null for internal) in tab mode.
  final PanelGroupController? groupController;

  /// Cross-widget exclusivity. Defaults to [SheetCoordinator.shared] —
  /// every sheet in the app competes for one exclusive slot. Pass a
  /// private instance to opt out of global exclusivity.
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

  /// When dismissing multiple sheets at once, slide them off one after
  /// another (riffle effect) instead of simultaneously.
  final bool staggeredDismiss;

  /// Delay between each staggered dismissal.
  final Duration staggerDelay;

  final ValueChanged<int>? onTabOpened;
  final ValueChanged<int>? onTabClosed;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

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
    this.staggeredDismiss = false,
    this.staggerDelay = const Duration(milliseconds: 70),
    this.onTabOpened,
    this.onTabClosed,
    this.onOpen,
    this.onClose,
  }) : assert(
         child != null || (tabs != null && tabs.isNotEmpty),
         'Provide either child or a non-empty tabs list.',
       ),
       assert(
         tabs == null || controller == null,
         'In tab mode, pass groupController, not controller.',
       ),
       coordinator = coordinator ?? SheetCoordinator.shared;

  @override
  State<DraggableSideSheet> createState() => _DraggableSideSheetState();
}

class _DraggableSideSheetState extends State<DraggableSideSheet>
    with TickerProviderStateMixin {
  static const _flingVelocity = 350.0;
  static const _tabSpacing = 8.0;
  bool _lastSettledOpen = false;

  // ---- Single-sheet mode ----
  late final PanelController _internalSingle = PanelController();
  PanelController get _panel => widget.controller ?? _internalSingle;
  late final AnimationController _anim;

  // ---- Tab mode ----
  late final PanelGroupController _internalGroup = PanelGroupController();
  PanelGroupController get _group => widget.groupController ?? _internalGroup;
  List<AnimationController> _tabAnims = [];

  /// While an icon drag is consuming itself as "close frontmost",
  /// further pan events are ignored.
  bool _iconDragClosing = false;

  /// Tracks our own open-transition, to claim/release the coordinator
  /// exactly once per collapse↔open edge (never from animation ticks).
  bool _wasOpenForScope = false;

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

  /// A foreign widget claimed (or released) the open slot.
  void _onForeignSheet() {
    if (_foreignOpen) {
      // Someone else is open: slide our sheets closed (animated).
      if (_isTabMode) {
        if (!_group.isCollapsed) _group.closeAll();
      } else {
        if (_panel.isOpen) _panel.close();
      }
    }
    // Repaint — the fan/rail fade depends on _foreignOpen.
    if (mounted) setState(() {});
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
      old.coordinator.release(this);
      _wasOpenForScope = false;
      old.coordinator.removeListener(_onForeignSheet);
      _coordinator.addListener(_onForeignSheet);
      _syncScope(_isTabMode ? !_group.isCollapsed : _panel.isOpen);
    }
    if (_isTabMode &&
        (widget.tabs!.length != _tabAnims.length ||
            widget.animationDuration != old.animationDuration)) {
      final vals = [for (final a in _tabAnims) a.value];
      for (final a in _tabAnims) {
        a.dispose();
      }
      _rebuildTabAnims(vals);
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

    final open = _group.openTabs;
    final closing = <int>[
      for (var i = 0; i < _tabAnims.length; i++)
        if (!open.contains(i) && _tabAnims[i].value > 0.001) i,
    ]..sort((a, b) => b.compareTo(a)); // topmost slides first

    for (var i = 0; i < _tabAnims.length; i++) {
      final target = open.contains(i) ? 1.0 : 0.0;
      final anim = _tabAnims[i];
      if ((anim.value - target).abs() < 0.001) continue;

      // Staggered dismissal: each closing sheet waits its turn.
      if (widget.staggeredDismiss && target == 0.0) {
        final rank = closing.indexOf(i);
        if (rank > 0) {
          final delay = widget.staggerDelay * rank;
          Timer(delay, () {
            if (mounted) {
              anim.animateTo(
                0.0,
                duration: widget.animationDuration,
                curve: widget.animationCurve,
              );
            }
          });
          continue;
        }
      }
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

  Rect _panelRect(Size size, double t, double expanded) {
    final off = expanded * (1 - t);
    return switch (widget.direction) {
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

  BorderRadius get _panelRadius => switch (widget.direction) {
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

  EdgeInsets _contentPadding(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safe = mq.padding;
    return switch (widget.direction) {
      SheetDirection.left => EdgeInsets.only(right: safe.right),
      SheetDirection.right => EdgeInsets.only(left: safe.left),
      SheetDirection.top => EdgeInsets.only(left: safe.left, right: safe.right),
      SheetDirection.bottom => EdgeInsets.only(
        left: safe.left,
        right: safe.right,
        bottom: widget.keyboardAware ? mq.viewInsets.bottom : 0.0,
      ),
    };
  }

  // ---- Drag handling ----

  void _onDragStart(AnimationController anim) => anim.stop();

  void _onDragUpdate(AnimationController anim, DragUpdateDetails d) {
    final raw = widget.direction.isHorizontal ? d.delta.dx : d.delta.dy;
    final openDelta =
        (widget.direction == SheetDirection.right ||
            widget.direction == SheetDirection.bottom)
        ? -raw
        : raw;
    final expanded = _expandedPixels(MediaQuery.sizeOf(context));
    anim.value = (anim.value + openDelta / expanded).clamp(0.0, 1.0);
  }

  double _dragTarget(AnimationController anim, DragEndDetails d) {
    final v = widget.direction.isHorizontal
        ? d.velocity.pixelsPerSecond.dx
        : d.velocity.pixelsPerSecond.dy;
    final openVel =
        (widget.direction == SheetDirection.right ||
            widget.direction == SheetDirection.bottom)
        ? -v
        : v;
    if (openVel > _flingVelocity) return 1.0;
    if (openVel < -_flingVelocity) return 0.0;
    return anim.value >= 0.5 ? 1.0 : 0.0;
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
        animation: Listenable.merge([..._tabAnims, _coordinator]),
        builder: (context, _) => _buildGroup(size, theme),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_anim, _coordinator]),
      builder: (context, _) {
        final t = _anim.value;
        final expanded = _expandedPixels(size);
        final visible = expanded * t;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: t <= 0.0,
                child: GestureDetector(
                  onTap: _panel.close,
                  child: ColoredBox(
                    color: widget.scrimColor.withValues(
                      alpha: widget.scrimColor.a * t,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: _panelRect(size, t, expanded),
              child: _buildPanelChrome(
                theme,
                child: widget.child!,
                anim: _anim,
              ),
            ),
            _buildRail(size, visible, theme),
          ],
        );
      },
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

  /// Panel chrome (Material + handle + edge strip) shared by both modes.
  Widget _buildPanelChrome(
    ThemeData theme, {
    required Widget child,
    required AnimationController anim,
    Key? stripKey,
  }) {
    return Material(
      elevation: 8,
      borderRadius: _panelRadius,
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: _contentPadding(context),
              child: Column(
                children: [
                  if (widget.showHandle && widget.swipeToClose)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => _onDragStart(anim),
                      onPanUpdate: (d) => _onDragUpdate(anim, d),
                      onPanEnd: (d) {
                        final target = _dragTarget(anim, d);
                        if (!_isTabMode) {
                          _panel.settle(open: target == 1.0);
                        }
                        anim.animateTo(
                          target,
                          duration: widget.animationDuration,
                          curve: widget.animationCurve,
                        );
                      },
                      child: SizedBox(
                        key: const Key('ds_handle'),
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
                    ),
                  Expanded(child: ClipRect(child: child)),
                ],
              ),
            ),
          ),
          if (widget.edgeDragEnabled && widget.swipeToClose)
            _buildEdgeStrip(
              stripKey,
              onStart: (_) => _onDragStart(anim),
              onUpdate: (d) => _onDragUpdate(anim, d),
              onEnd: (d) {
                final target = _dragTarget(anim, d);
                _panel.settle(open: target == 1.0);
                anim.animateTo(
                  target,
                  duration: widget.animationDuration,
                  curve: widget.animationCurve,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEdgeStrip(
    Key? key, {
    required void Function(DragStartDetails) onStart,
    required void Function(DragUpdateDetails) onUpdate,
    required void Function(DragEndDetails)? onEnd,
  }) {
    final w = widget.edgeDragWidth;
    final gesture = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: onStart,
      onPanUpdate: onUpdate,
      onPanEnd: onEnd,
      child: SizedBox(key: key, child: const SizedBox.expand()),
    );
    return switch (widget.direction) {
      SheetDirection.left => Positioned(
        top: 0,
        bottom: 0,
        right: 0,
        width: w,
        child: gesture,
      ),
      SheetDirection.right => Positioned(
        top: 0,
        bottom: 0,
        left: 0,
        width: w,
        child: gesture,
      ),
      SheetDirection.top => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: w,
        child: gesture,
      ),
      SheetDirection.bottom => Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: w,
        child: gesture,
      ),
    };
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
    final mq = MediaQuery.of(context);
    final tabs = widget.tabs!;
    final s = widget.railIconSize.clamp(40.0, 56.0);

    // Shared scrim: alpha follows the most-visible sheet; tap closes all.
    var maxT = 0.0;
    for (final a in _tabAnims) {
      if (a.value > maxT) maxT = a.value;
    }

    var scrimFromEdge = 0.0;
    if (widget.direction == SheetDirection.bottom && widget.keyboardAware) {
      scrimFromEdge = mq.viewInsets.bottom;
    }

    final horizontal = widget.direction.isHorizontal;
    final edgeLen = horizontal ? size.height : size.width;
    final extent = tabs.length * s + (tabs.length - 1) * _tabSpacing;
    final start = ((edgeLen - extent) / 2).clamp(16.0, double.infinity);

    final outerExtent = _outerExtent(size);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Shared scrim — static color, one layer, no compounding.
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              left: 0,
              top: 0,
              right: 0,
              bottom: scrimFromEdge,
            ),
            child: IgnorePointer(
              ignoring: maxT <= 0.0,
              child: GestureDetector(
                onTap: _group.closeAll,
                child: ColoredBox(
                  color: widget.scrimColor.withValues(
                    alpha: widget.scrimColor.a * maxT,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Sheets, ascending tab order so higher indices paint on top.
        for (var i = 0; i < tabs.length; i++)
          Positioned.fromRect(
            rect: _panelRect(size, _tabAnims[i].value, expanded),
            child: _buildSheet(tabs[i], i, theme),
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
            start + i * (s + _tabSpacing),
            theme,
            outerExtent,
          ),
      ],
    );
  }

  Widget _buildSheet(SheetTab tab, int i, ThemeData theme) {
    return Material(
      elevation: 8,
      borderRadius: _panelRadius,
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: _contentPadding(context),
              child: widget.showHandle && widget.swipeToClose
                  ? Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) => _onDragStart(_tabAnims[i]),
                          onPanUpdate: (d) => _onDragUpdate(_tabAnims[i], d),
                          onPanEnd: (d) => _onIconPanEnd(i, d),
                          child: SizedBox(
                            key: Key('ds_handle_$i'),
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
                        ),
                        Expanded(child: ClipRect(child: tab.child)),
                      ],
                    )
                  : ClipRect(child: tab.child),
            ),
          ),
          if (widget.edgeDragEnabled && widget.swipeToClose)
            _buildEdgeStrip(
              Key('ds_edge_strip_$i'),
              onStart: (_) => _onDragStart(_tabAnims[i]),
              onUpdate: (d) => _onDragUpdate(_tabAnims[i], d),
              onEnd: (d) => _onIconPanEnd(i, d),
            ),
        ],
      ),
    );
  }

    Positioned _buildFanTab(
    Size size,
    SheetTab tab,
    int i,
    double s,
    double alongEdge,
    ThemeData theme,
    double outerExtent,
  ) {
    final open = _group.isOpen(i);
    // Equal full opacity when collapsed; dim only if open AND covered.
    final covered = open && _group.openTabs.any((j) => j > i);

    var fromEdge = outerExtent + 8;
    if (widget.direction == SheetDirection.bottom && widget.keyboardAware) {
      fromEdge += MediaQuery.of(context).viewInsets.bottom;
    }

    Widget button = GestureDetector(
      onTap: widget.railToggleEnabled ? () => _group.tapTab(i) : null,
      onPanStart: widget.swipeToClose ? (d) => _onIconPanStart(i, d) : null,
      onPanUpdate: widget.swipeToClose ? (d) => _onIconPanUpdate(i, d) : null,
      onPanEnd: widget.swipeToClose ? (d) => _onIconPanEnd(i, d) : null,
      child: Semantics(
        // Compose the badge INTO the label deliberately — otherwise the
        // semantics engine merges the badge's raw Text("3") into the
        // label as "Inbox\n3". The badge visual is ExcludeSemantics'd below.
        label: switch (tab.badge) {
          final b? when b > 0 =>
            '${tab.label}, $b unread${open ? ', open' : ''}',
          _ => '${tab.label}${open ? ', open' : ''}',
        },
        button: true,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: covered ? 0.45 : 1.0,
          child: Container(
            key: Key('ds_tab_$i'),
            width: s,
            height: s,
            decoration: BoxDecoration(
              color:
                  tab.backgroundColor ??
                  widget.railBackgroundColor ??
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
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    tab.icon,
                    size: s * 0.5,
                    color:
                        tab.iconColor ??
                        widget.railIconColor ??
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
      ),
    );

    // Foreign-fade wraps the button, inside the Positioned.
    final fadedButton = _fadeWhenForeign(button);

    return switch (widget.direction) {
      SheetDirection.left => Positioned(
        left: fromEdge,
        top: alongEdge,
        width: s,
        height: s,
        child: fadedButton,
      ),
      SheetDirection.right => Positioned(
        right: fromEdge,
        top: alongEdge,
        width: s,
        height: s,
        child: fadedButton,
      ),
      SheetDirection.top => Positioned(
        top: fromEdge,
        left: alongEdge,
        width: s,
        height: s,
        child: fadedButton,
      ),
      SheetDirection.bottom => Positioned(
        bottom: fromEdge,
        left: alongEdge,
        width: s,
        height: s,
        child: fadedButton,
      ),
    };
  }
  // ---- Single-sheet rail ----

  Widget _buildRail(Size size, double visible, ThemeData theme) {
    final s = widget.railIconSize;

    Widget button = GestureDetector(
      onTap: widget.railToggleEnabled ? _panel.toggle : null,
      onPanStart: widget.swipeToClose ? (_) => _onDragStart(_anim) : null,
      onPanUpdate: widget.swipeToClose ? (d) => _onDragUpdate(_anim, d) : null,
      onPanEnd: widget.swipeToClose
          ? (d) {
              final target = _dragTarget(_anim, d);
              _panel.settle(open: target == 1.0);
              _anim.animateTo(
                target,
                duration: widget.animationDuration,
                curve: widget.animationCurve,
              );
            }
          : null,
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

    return switch (widget.direction) {
      SheetDirection.left => Positioned(
        left: visible + 8,
        top: (size.height - s) / 2,
        child: fadedButton,
      ),
      SheetDirection.right => Positioned(
        right: visible + 8,
        top: (size.height - s) / 2,
        child: fadedButton,
      ),
      SheetDirection.top => Positioned(
        top: visible + 8,
        left: (size.width - s) / 2,
        child: fadedButton,
      ),
      SheetDirection.bottom => Positioned(
        bottom: visible + 8,
        left: (size.width - s) / 2,
        child: fadedButton,
      ),
    };
  }
}
