import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ipick/ui/features/admin/view/admin_home_screen.dart';
import 'package:ipick/ui/features/admin/view/admin_login_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/admin/home',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(body: Text('root')),
      routes: [
        GoRoute(
          path: 'admin',
          builder: (context, state) => Scaffold(body: Text('admin')),
          routes: [
            GoRoute(
              path: 'login',
              builder: (context, state) => AdminLoginScreen(),
            ),
            GoRoute(
              path: 'home',
              builder: (context, state) => AdminHomeScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
