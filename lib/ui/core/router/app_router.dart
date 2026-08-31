import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ipick/ui/features/admin/view/admin_home_screen.dart';
import 'package:ipick/ui/features/admin/view/admin_login_screen.dart';
import 'package:ipick/ui/features/feed/view/feed_screen.dart';
import 'package:ipick/ui/features/notifications/view/notifications_screen.dart';
import 'package:ipick/ui/features/profile/view/profile_screen.dart';
import 'package:ipick/ui/features/shell/app_shell.dart';
import 'package:ipick/ui/features/subscriptions/view/subscriptions_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/feed',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/feed', builder: (_, __) => FeedScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/subscriptions',
              builder: (_, __) => SubscriptionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => NotificationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // this is test comment
    GoRoute(
      path: '/admin',
      builder: (context, state) => Scaffold(body: Text('admin')),
      routes: [
        GoRoute(path: 'login', builder: (context, state) => AdminLoginScreen()),
        GoRoute(path: 'home', builder: (context, state) => AdminHomeScreen()),
      ],
    ),
  ],
);
