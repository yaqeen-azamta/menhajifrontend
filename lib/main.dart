import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/theme.dart';

void main() {
  runApp(const ProviderScope(child: KidLearnApp()));
}

class KidLearnApp extends ConsumerWidget {
  const KidLearnApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildRouter(ref);
    return MaterialApp.router(
      title: 'منهاجي',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // ── Arabic locale + RTL ──────────────────────────────────
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
