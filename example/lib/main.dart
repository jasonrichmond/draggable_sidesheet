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
 final _controllers = {
    for (final d in SheetDirection.values) d: PanelController(d.name),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color _accent(SheetDirection d) => switch (d) {
        SheetDirection.left => Colors.deepOrange,
        SheetDirection.right => Colors.teal,
        SheetDirection.top => Colors.indigo,
        SheetDirection.bottom => Colors.amber.shade800,
      };

  IconData _icon(SheetDirection d) => switch (d) {
        SheetDirection.left => Icons.west,
        SheetDirection.right => Icons.east,
        SheetDirection.top => Icons.north,
        SheetDirection.bottom => Icons.south,
      };

  Widget _panelContent(SheetDirection d) => Builder(
        builder: (context) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${d.name.toUpperCase()} panel',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Drag the handle or the panel edge. Tap the rail button or '
                'swipe back toward the screen edge to close.'),
            const SizedBox(height: 16),
            ...List.generate(
              12,
              (i) => ListTile(
                leading: CircleAvatar(backgroundColor: _accent(d), child: Text('${i + 1}')),
                title: Text('${d.name} item ${i + 1}'),
                subtitle: const Text('Scrolls while the panel stays draggable'),
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
          // Base layer behind the sheets.
          const Center(
            child: Text(
              'Four panels, four edges.\nTap an arrow to open one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
          ),
          for (final d in SheetDirection.values)
            DraggableSideSheet(
              key: ValueKey(d),
              direction: d,
              controller: _controllers[d],
              expandedSize: d.isHorizontal ? 0.55 : 0.45,
              railIcon: _icon(d),
              railBackgroundColor: _accent(d),
              railIconColor: Colors.white,
              railBadge: d == SheetDirection.left ? 3 : null,
              scrimColor: const Color(0x00000000),
              child: _panelContent(d),
            ),
        ],
      ),
    );
  }
}