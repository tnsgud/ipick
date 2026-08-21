import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipick/ui/features/admin/view/admin_login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/core/theme/app_theme.dart';
import 'ui/features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://obxjpqemljdtxyhykber.supabase.co',
    publishableKey: 'sb_publishable_XZt4olfVPGBrEO4p0aXYJg_ik1LxnKK',
  );
  runApp(ProviderScope(child: const IPickApp()));
}

/// iPick — 팬덤 발매·굿즈 알림 + 구매 연결.
///
/// 현재는 디자인(UI) 레이어 + 목업 데이터만 배선돼 있다. 인증·데이터·구독·FCM 등
/// 내부 로직 연동은 `docs/design/flutter-logic-guide.md`를 참고해 붙인다.
class IPickApp extends StatelessWidget {
  const IPickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPick',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AdminLoginScreen(),
    );
  }
}
