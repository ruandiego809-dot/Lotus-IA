import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotus_ai/features/terminal/data/terminal_repository.dart';
import 'package:lotus_ai/features/terminal/domain/terminal_models.dart';
import 'package:lotus_ai/features/terminal/domain/terminal_session_controller.dart';

class DelayedTerminalRepository extends TerminalRepository {
  final completer = Completer<List<TerminalSession>>();
  List<TerminalSession>? saved;

  @override
  Future<List<TerminalSession>> load() => completer.future;

  @override
  Future<void> save(List<TerminalSession> items) async {
    saved = List.of(items);
  }
}

void main() {
  test('creating after disposal does not update disposed state', () async {
    final repo = DelayedTerminalRepository();
    final container = ProviderContainer(
      overrides: [terminalRepositoryProvider.overrideWithValue(repo)],
    );
    final controller = container.read(terminalControllerProvider.notifier);
    final created = controller.createSession(name: 'new');
    container.dispose();
    repo.completer.complete([]);
    await expectLater(created, throwsStateError);
    expect(repo.saved, isNull);
  });

  test('creating a session waits for saved sessions to load', () async {
    final repo = DelayedTerminalRepository();
    final container = ProviderContainer(
      overrides: [terminalRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(terminalControllerProvider.notifier);
    final created = controller.createSession(name: 'new');
    final old = TerminalSession(name: 'old');
    repo.completer.complete([old]);
    final newSession = await created;
    final state = container.read(terminalControllerProvider);
    expect(state.sessions.map((s) => s.id), [newSession.id, old.id]);
    expect(repo.saved!.map((s) => s.id), [newSession.id, old.id]);
  });
}
