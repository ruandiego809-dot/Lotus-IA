// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class LotusApp extends ConsumerWidget {
  const LotusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Lótus AI',
      debugShowCheckedModeBanner: false,
      theme: LotusTheme.light,
      darkTheme: LotusTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('pt')],
      locale: const Locale('pt'),
      routerConfig: router,
      themeAnimationDuration: LotusMotion.base,
      themeAnimationCurve: LotusMotion.curve,
    );
  }
}
