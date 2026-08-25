import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipick/ui/core/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://obxjpqemljdtxyhykber.supabase.co',
    publishableKey: 'sb_publishable_XZt4olfVPGBrEO4p0aXYJg_ik1LxnKK',
  );

  runApp(ProviderScope(child: const IPickApp()));
}

class IPickApp extends StatelessWidget {
  const IPickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'iPick',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
    );
  }
}
