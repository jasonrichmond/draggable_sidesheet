import 'package:flutter/material.dart';
import 'package:draggable_sidesheet/draggable_sidesheet.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Draggable SideSheet Demo',
        theme: ThemeData.dark(useMaterial3: true),
        home: const DemoScreen(),
      );
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _leftGroup = PanelGroupController('left');
  final _rightGroup = PanelGroupController('right');
  final _topController = PanelController('top-single');
  final _bottomController = PanelController('bottom-single');

  @override
  void dispose() {
    _leftGroup.dispose();
    _rightGroup.dispose();
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  Widget _tabBody(String title, Color accent) => Builder(
        builder: (context) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Each tab is its own sheet. Content state survives '
                'open/close AND covering/uncovering.'),
            const SizedBox(height: 16),
            ...List.generate(
              12,
              (i) => ListTile(
                leading: CircleAvatar(backgroundColor: accent, child: Text('${i + 1}')),
                title: Text('$title item ${i + 1}'),
                onTap: () {},
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: Stack(
        children: [
          const Center(
            child: Text(
              'LEFT: stacked sheets (pure overlap)\n'
              'RIGHT: stacked sheets with stagger\n'
              'TOP/BOTTOM: single panels\n\n'
              'Tap a tab to pull its sheet forward.\n'
              'Tap outside to close everything.\n'
              'Icons ride past sheet edges — never obstruct content.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ),

          // LEFT: stacked sheets, pure overlap
          DraggableSideSheet(
            key: const ValueKey('left-group'),
            direction: SheetDirection.left,
            groupController: _leftGroup,
            expandedSize: 0.7,
            tabs: [
              SheetTab(iconWidget: Image.asset('assets/anim.gif', gaplessPlayback: true,), iconBezel: false, label: 'Inbox', badge: 3,
                  child: _tabBody('Inbox', Colors.orange)),
              SheetTab(icon: Icons.people_outline, label: 'Invites',
                  child: _tabBody('Invites', Colors.lightBlue)),
              SheetTab(icon: Icons.star_border, label: 'Favorites',
                  child: _tabBody('Favorites', Colors.purpleAccent)),
            ],
          ),

          // RIGHT: stacked sheets with stagger (peek removed — all aligned)
          DraggableSideSheet(
            key: const ValueKey('right-group'),
            direction: SheetDirection.right,
            groupController: _rightGroup,
            expandedSize: 0.7,
            fanAlignment: Alignment.bottomLeft,
            fanSpacing: 10,
            fanInset: 100,
            tabs: [
              SheetTab(icon: Icons.map_outlined, label: 'Map',
                  child: _tabBody('Map', Colors.teal)),
              SheetTab(icon: Icons.route_outlined, label: 'Routes',
                  child: _tabBody('Routes', Colors.greenAccent)),
              SheetTab(icon: Icons.settings_outlined, label: 'Settings',
                  child: _tabBody('Settings', Colors.cyanAccent)),
            ],
          ),

          // TOP: single panel
          DraggableSideSheet(
            key: const ValueKey('top-single'),
            direction: SheetDirection.top,
            controller: _topController,
            expandedSize: 0.45,
            railBackgroundColor: Colors.indigo,
            railIconColor: Colors.white,
            scrimColor: const Color(0x00000000),
            child: _tabBody('TOP single', Colors.indigo),
          ),

          // BOTTOM: single panel
          DraggableSideSheet(
            key: const ValueKey('bottom-single'),
            direction: SheetDirection.bottom,
            controller: _bottomController,
            expandedSize: 0.45,
            railBackgroundColor: Colors.amber.shade800,
            railIconColor: Colors.white,
            scrimColor: const Color(0x00000000),
            child: _tabBody('BOTTOM single', Colors.amber.shade800),
          ),
        ],
      ),
    );
  }
}