import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ipick/ui/core/theme/app_colors.dart';
import 'package:ipick/ui/core/theme/app_spacing.dart';
import 'package:ipick/ui/core/theme/app_text_styles.dart';
import 'package:ipick/ui/core/widgets/ipick_chip.dart';
import 'package:ipick/ui/features/admin/view/widget/tabs.dart';

import './widget/header.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0; // 나중에 view_model로 빼야함 상태관리가 되야하기 때문에

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Header(),
              Tabs(),
              IndexedStack(
                index: _index,
                children: [
                  Text('world1'),
                  Text('world2'),
                  Text('world3'),
                  Text('world4'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
