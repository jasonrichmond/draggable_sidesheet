import 'package:flutter/material.dart';
import 'sheet_direction.dart';
import 'panel_controller.dart';

class DraggableSideSheet extends StatefulWidget {
  final SheetDirection direction;
  final Widget child;
  final bool initiallyOpen;
  final PanelController? controller;
  final double expandedSize;
  final Color scrimColor;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool swipeToClose;
  final bool railToggleEnabled;
  final IconData railIcon;
  final double railIconSize;
  final int? railBadge;
  final Color? railBackgroundColor;
  final Color? railIconColor;
  final bool edgeDragEnabled;
  final double edgeDragWidth;
  final bool keyboardAware;

  // Whether to show the decorative drag pill inside the panel.
  // The rail tab and invisible edge strip are always available for dragging.
  final bool showHandle;

  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  const DraggableSideSheet({
    super.key,
    required this.direction,
    required this.child,
    this.initiallyOpen = false,
    this.controller,
    this.expandedSize = 0.7,
    this.scrimColor = const Color(0x66000000),
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOutCubic,
    this.swipeToClose = true,
    this.railToggleEnabled = true,
    this.railIcon = Icons.menu,
    this.railIconSize = 48.0,
    this.railBadge,
    this.railBackgroundColor,
    this.railIconColor,
    this.edgeDragEnabled = true,
    this.edgeDragWidth = 32.0,
    this.keyboardAware = true,
    this.showHandle = false,
    this.onOpen,
    this.onClose,
  });

  @override
  State<DraggableSideSheet> createState() => _DraggableSideSheetState();
}

class _DraggableSideSheetState extends State<DraggableSideSheet>
    with SingleTickerProviderStateMixin {
  late final PanelController _internal = PanelController();
  PanelController get _panel => widget.controller ?? _internal;
  late final AnimationController _anim;
  static const _flingVelocity = 350.0;
  bool _lastSettledOpen = false;

  @override
  void initState() {
    super.initState();
    // NOTE: no listener mirroring animation progress into the controller.
    // That back-write was the source of every reopen bug we've chased.
    _anim = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: widget.initiallyOpen ? 1.0 : 0.0,
    );

    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        // Derive openness from the actual position — status alone proved
        final open = _anim.value > 0.5;
        if (open != _lastSettledOpen) {
          _lastSettledOpen = open;
          (open ? widget.onOpen : widget.onClose)?.call();
        }
      }
    });
    

    _panel.addListener(_onPanelChanged);

    if (widget.controller != null && widget.controller!.isOpen) {
      // External controller arrived open — kick the animation.
      _onPanelChanged();
    }
    if (widget.initiallyOpen) {
      _panel.settle(open: true);
    }
  }

   void _onPanelChanged() {
    debugPrint('_ON_PANEL_CHANGED [${widget.direction.name}]');
    debugPrint('  _panel.isOpen=${_panel.isOpen}, _anim.value=${_anim.value}');
    final target = _panel.isOpen ? 1.0 : 0.0;
    if ((_anim.value - target).abs() < 0.001) {
      debugPrint('  SKIPPING (already at target)');
      return;
    }
    debugPrint('  ANIMATING to $target');
    _anim.animateTo(target,
        duration: widget.animationDuration, curve: widget.animationCurve);
  }

  @override
  void dispose() {
    _panel.removeListener(_onPanelChanged);
    if (widget.controller == null) _internal.dispose();
    _anim.dispose();
    super.dispose();
  }

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
      SheetDirection.right => Rect.fromLTWH(size.width - expanded + off, 0, expanded, size.height),
      SheetDirection.top => Rect.fromLTWH(0, -off, size.width, expanded),
      SheetDirection.bottom => Rect.fromLTWH(0, size.height - expanded + off, size.width, expanded),
    };
  }

  // Drag handling (shared by rail tab, edge strip, and handle)

  void _onDragStart(DragStartDetails _) => _anim.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    final raw = widget.direction.isHorizontal ? d.delta.dx : d.delta.dy;
    final openDelta = (widget.direction == SheetDirection.right || widget.direction == SheetDirection.bottom)
        ? -raw
        : raw;
    final expanded = _expandedPixels(MediaQuery.sizeOf(context));
    _anim.value = (_anim.value + openDelta / expanded).clamp(0.0, 1.0);
  }

   void _onDragEnd(DragEndDetails d) {
    debugPrint('ON_DRAG_END [${widget.direction.name}] velocity=${d.velocity}');
    debugPrint('  _anim.value=${_anim.value}');
    // ... rest of the method unchanged
    final v = widget.direction.isHorizontal
        ? d.velocity.pixelsPerSecond.dx
        : d.velocity.pixelsPerSecond.dy;
    final openVel = (widget.direction == SheetDirection.right ||
            widget.direction == SheetDirection.bottom)
        ? -v
        : v;

    double target;
    if (openVel > _flingVelocity) {
      target = 1.0;
    }
    else if (openVel < -_flingVelocity) {
      target = 0.0;
    }
    else {
      target = _anim.value >= 0.5 ? 1.0 : 0.0;
    }

    _panel.settle(open: target == 1.0); // silent: no reaction possible
    _anim.animateTo(target,
        duration: widget.animationDuration, curve: widget.animationCurve);
  }

  BorderRadius get _panelRadius => switch (widget.direction) {
        SheetDirection.left => const BorderRadius.horizontal(right: Radius.circular(16)),
        SheetDirection.right => const BorderRadius.horizontal(left: Radius.circular(16)),
        SheetDirection.top => const BorderRadius.vertical(bottom: Radius.circular(16)),
        SheetDirection.bottom => const BorderRadius.vertical(top: Radius.circular(16)),
      };

  EdgeInsets _contentPadding(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safe = mq.padding;
    return switch (widget.direction) {
      SheetDirection.left => EdgeInsets.only(right: safe.right),
      SheetDirection.right => EdgeInsets.only(left: safe.left),
      SheetDirection.top => EdgeInsets.only(left: safe.left, right: safe.right),
      SheetDirection.bottom => EdgeInsets.only(left: safe.left, right: safe.right, bottom: widget.keyboardAware ? mq.viewInsets.bottom : 0.0),
    };
  }

  Widget _buildEdgeStrip() {
    final w = widget.edgeDragWidth;
    final gesture = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onDragStart,
      onPanUpdate: _onDragUpdate,
      onPanEnd: _onDragEnd,
      child: SizedBox(key: const Key('ds_edge_strip'), child: const SizedBox.expand()),
    );
    return switch (widget.direction) {
      SheetDirection.left => Positioned(top: 0, bottom: 0, right: 0, width: w, child: gesture),
      SheetDirection.right => Positioned(top: 0, bottom: 0, left: 0, width: w, child: gesture),
      SheetDirection.top => Positioned(left: 0, right: 0, bottom: 0, height: w, child: gesture),
      SheetDirection.bottom => Positioned(left: 0, right: 0, top: 0, height: w, child: gesture),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(animation: _anim, builder: (context, _) {
      final t = _anim.value;
      final expanded = _expandedPixels(size);
      final visible = expanded * t;

      // StackFit.expand makes the sheet fill whatever box it's placed in,
      // even under loose constraints (e.g. inside another Stack).
      return Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: t <= 0.0,
            child: GestureDetector(
              onTap: _panel.close,
              child: ColoredBox(color: widget.scrimColor.withValues(alpha: widget.scrimColor.a * t)),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: _panelRect(size, t, expanded),
          child: Material(
            elevation: 8,
            borderRadius: _panelRadius,
            color: theme.scaffoldBackgroundColor,
            child: Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding: _contentPadding(context),
                  child: Column(children: [
                    if (widget.showHandle && widget.swipeToClose)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _onDragStart,
                        onPanUpdate: _onDragUpdate,
                        onPanEnd: _onDragEnd,
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
                    Expanded(child: ClipRect(child: widget.child)),
                  ]),
                ),
              ),
              if (widget.edgeDragEnabled && widget.swipeToClose) _buildEdgeStrip(),
            ]),
          ),
        ),
        _buildRail(size, visible, theme),
      ]);
    });
  }

  Widget _buildRail(Size size, double visible, ThemeData theme) {
    final s = widget.railIconSize;

    Widget button = GestureDetector(
      // Tap toggles; pan drags the panel open/closed by its tab.
      onTap: widget.railToggleEnabled 
    ? () {
        debugPrint('RAIL ON_TAP FIRED [${widget.direction.name}]');
        debugPrint('  Before toggle: _panel.isOpen=${_panel.isOpen}, _anim.value=${_anim.value}');
        _panel.toggle();
        debugPrint('  After toggle: _panel.isOpen=${_panel.isOpen}');
      } 
    : null,
      onPanStart: widget.swipeToClose ? (details) {
    debugPrint('RAIL ON_PAN_START [${widget.direction.name}] at ${details.globalPosition}');
    _onDragStart(details);
  } : null,
      onPanUpdate: widget.swipeToClose ? _onDragUpdate : null,
      onPanEnd: widget.swipeToClose ? _onDragEnd : null,
      child: Container(
        key: const Key('ds_rail'),
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: widget.railBackgroundColor ?? theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(s * 0.25),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Center(
            child: Icon(widget.railIcon, size: s * 0.5, color: widget.railIconColor ?? theme.colorScheme.onPrimary),
          ),
          if (widget.railBadge != null && widget.railBadge! > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: theme.scaffoldBackgroundColor, width: 1.5)),
                ),
                constraints: BoxConstraints(minWidth: s * 0.4, minHeight: s * 0.4),
                child: Center(
                  child: Text(
                    widget.railBadge.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onError, fontSize: (s * 0.22).roundToDouble(), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );

    return switch (widget.direction) {
      SheetDirection.left => Positioned(left: visible + 8, top: (size.height - s) / 2, child: button),
      SheetDirection.right => Positioned(right: visible + 8, top: (size.height - s) / 2, child: button),
      SheetDirection.top => Positioned(top: visible + 8, left: (size.width - s) / 2, child: button),
      SheetDirection.bottom => Positioned(bottom: visible + 8, left: (size.width - s) / 2, child: button),
    };
  }
}