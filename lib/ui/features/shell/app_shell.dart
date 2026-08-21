import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../feed/view/feed_screen.dart';
import '../notifications/view/notifications_screen.dart';
import '../profile/view/profile_screen.dart';
import '../subscriptions/view/subscriptions_screen.dart';

/// 하단 탭 셸: 피드 / 구독 / 알림 / MY. 탭 전환만 담당하는 얇은 셸.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    FeedScreen(),
    SubscriptionsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.canvas,
        indicatorColor: AppColors.weakBackground,
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed, color: AppColors.primaryInk),
            label: '피드',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(
              Icons.favorite_rounded,
              color: AppColors.primaryInk,
            ),
            label: '구독',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(
              Icons.notifications_rounded,
              color: AppColors.primaryInk,
            ),
            label: '알림',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.primaryInk,
            ),
            label: 'MY',
          ),
        ],
      ),
    );
  }
}
