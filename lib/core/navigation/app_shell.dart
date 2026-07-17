import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/route_constants.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _tabIndex(location),
        onTabTapped: (i) => _navigate(context, i),
      ),
    );
  }

  int _tabIndex(String path) {
    if (path.startsWith('/quest')) return 1;
    if (path.startsWith('/signs')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(kRouteHome);
      case 1: context.go(kRouteQuest);
      case 2: context.go(kRouteSigns);
      case 3: context.go(kRouteProfile);
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTabTapped;

  const _BottomNavBar({required this.currentIndex, required this.onTabTapped});

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home'),
    _NavItem(icon: Icons.emoji_events_outlined, label: 'Quest'),
    _NavItem(icon: Icons.sign_language_outlined, label: 'Signs'),
    _NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(
              _items.length,
              (i) => Expanded(
                child: _NavTab(
                  item: _items[i],
                  selected: i == currentIndex,
                  onTap: () => onTabTapped(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavTab extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFFAAAAAA);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: selected ? 4 : 0,
              height: selected ? 4 : 0,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
