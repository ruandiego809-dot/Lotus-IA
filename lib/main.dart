// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura erros não tratados em qualquer isolate e exibe uma tela amigável
  // em vez de deixar o app travar silenciosamente.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint(details.exceptionAsString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Erro não tratado: $error');
    debugPrint(stack.toString());
    return true;
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: LotusApp())),
    (error, stack) {
      debugPrint('Erro não capturado na zona: $error');
      debugPrint(stack.toString());
    },
  );
}
