import 'package:flutter/material.dart';

/// Labeled, accessible navigation that keeps narrow screens usable.
class AppNavigation extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, String)> destinations;
  final Widget child;
  const AppNavigation({
    super.key,
    required this.index,
    required this.onChanged,
    required this.destinations,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 720) {
        return Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onChanged,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.$1),
                      label: Text(d.$2),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        );
      }
      return Column(
        children: [
          Expanded(child: child),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: onChanged,
            destinations: destinations
                .map(
                  (d) => NavigationDestination(icon: Icon(d.$1), label: d.$2),
                )
                .toList(),
          ),
        ],
      );
    },
  );
}
