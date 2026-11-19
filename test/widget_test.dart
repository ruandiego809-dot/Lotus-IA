// ignore_for_file: deprecated_member_use, avoid_relative_lib_imports, prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lotus_ai/app/app.dart';
import 'package:lotus_ai/design/design.dart';

void main() {
  testWidgets('Lótus app constrói sem falhar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LotusApp()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LotusApp), findsOneWidget);
  });

  testWidgets('LotusCard renderiza conteúdo e ripple', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LotusCard(
            onTap: null,
            child: const Text('Conteúdo do card'),
          ),
        ),
      ),
    );
    expect(find.text('Conteúdo do card'), findsOneWidget);
    expect(find.byType(LotusCard), findsOneWidget);
  });

  testWidgets('LotusPill renderiza rótulo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LotusPill('Etiqueta')));
    expect(find.text('Etiqueta'), findsOneWidget);
  });

  testWidgets('LotusSkeleton renderiza', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LotusSkeleton(width: 100, height: 16)),
      ),
    );
    expect(find.byType(LotusSkeleton), findsOneWidget);
  });

  testWidgets('LotusBrandMark renderiza', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LotusBrandMark(size: 40)),
      ),
    );
    expect(find.byType(LotusBrandMark), findsOneWidget);
  });
}
