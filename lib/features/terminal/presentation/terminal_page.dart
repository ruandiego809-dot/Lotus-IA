// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../../design/design.dart';

import '../data/terminal_repository.dart';
import '../domain/terminal_models.dart';
import '../domain/terminal_session_controller.dart';

class TerminalPage extends ConsumerStatefulWidget {
  const TerminalPage({super.key});

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  final Map<String, xterm.Terminal> _terms = {};
  final Map<String, xterm.TerminalController> _controllers = {};
  final Map<String, StreamSubscription<String>> _subscriptions = {};

  xterm.Terminal _terminalFor(String sessionId) {
    return _terms.putIfAbsent(sessionId, () {
      final terminal = xterm.Terminal(maxLines: 10000);
      _controllers[sessionId] = xterm.TerminalController();
      terminal.onOutput = (data) =>
          ref.read(terminalControllerProvider.notifier).write(sessionId, data);
      terminal.onResize = (w, h, pw, ph) =>
          ref.read(terminalControllerProvider.notifier).resize(sessionId, w, h);
      _attachRuntime(sessionId, terminal);
      return terminal;
    });
  }

  void _attachRuntime(String sessionId, xterm.Terminal terminal) {
    _subscriptions[sessionId]?.cancel();
    final runtime = ref.read(terminalControllerProvider).runtimes[sessionId];
    if (runtime == null) return;
    _subscriptions[sessionId] = runtime.output.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalControllerProvider);
    final consent = ref.watch(terminalAiConsentProvider);
    final active = state.active;

    ref.listen(terminalControllerProvider, (previous, next) {
      for (final entry in next.runtimes.entries) {
        if (previous?.runtimes[entry.key] != entry.value) {
          final terminal = _terms[entry.key];
          if (terminal != null) _attachRuntime(entry.key, terminal);
        }
      }
      final removed = (previous?.runtimes.keys.toSet() ?? <String>{})
        ..removeAll(next.runtimes.keys.toSet());
      for (final id in removed) {
        _subscriptions[id]?.cancel();
        _subscriptions.remove(id);
        _terms.remove(id);
        _controllers.remove(id)?.dispose();
      }
    });

    return LotusScaffold(
      appBar: LotusAppBar(
        title: 'Terminal',
        subtitle: active == null ? 'Alpine Linux via PTY' : active.name,
        actions: [
          IconButton(
            tooltip: 'Sessões',
            onPressed: () => _showSessions(context),
            icon: const Icon(Icons.list_alt_rounded, size: 21),
          ),
          IconButton(
            tooltip: 'Nova sessão',
            onPressed: () =>
                ref.read(terminalControllerProvider.notifier).createSession(),
            icon: const Icon(Icons.add_rounded, size: 21),
          ),
          IconButton(
            tooltip: 'Autorização da IA',
            onPressed: () => _showAiConsent(context, consent),
            icon: Icon(
              consent ? Icons.shield_rounded : Icons.shield_outlined,
              size: 21,
            ),
          ),
          IconButton(
            tooltip: 'Diagnosticar terminal',
            onPressed: () => _showDiagnose(context),
            icon: const Icon(Icons.bug_report_rounded, size: 21),
          ),
          const SizedBox(width: LotusSpace.sm),
        ],
      ),
      body: active == null
          ? _NoSession(
              onCreate: () =>
                  ref.read(terminalControllerProvider.notifier).createSession(),
            )
          : _SessionView(
              session: active,
              terminal: _terminalFor(active.id),
              controller: _controllers[active.id]!,
              bootstrapping: state.bootstrapping.contains(active.id),
              progress: state.bootstrapProgress[active.id],
            ),
    );
  }

  Future<void> _showSessions(BuildContext context) async {
    await showLotusSheet<void>(
      context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final state = ref.watch(terminalControllerProvider);
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LotusSpace.xl,
                    LotusSpace.xs,
                    LotusSpace.lg,
                    LotusSpace.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sessões', style: ctx.text.titleMedium),
                            Text(
                              '${state.sessions.length} sessões Alpine',
                              style: ctx.text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await ref
                              .read(terminalControllerProvider.notifier)
                              .createSession();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nova'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state.sessions.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma sessão. Crie uma sessão Alpine para começar.',
                            textAlign: TextAlign.center,
                            style: ctx.text.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            LotusSpace.md,
                            0,
                            LotusSpace.md,
                            LotusSpace.xl,
                          ),
                          itemCount: state.sessions.length,
                          itemBuilder: (ctx, index) {
                            final session = state.sessions[index];
                            final selected = session.id == state.activeId;
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: LotusSpace.sm,
                              ),
                              child: LotusCard(
                                radius: LotusRadius.sm,
                                padding: EdgeInsets.zero,
                                onTap: () {
                                  ref
                                      .read(terminalControllerProvider.notifier)
                                      .select(session.id);
                                  Navigator.pop(ctx);
                                },
                                color: selected
                                    ? ctx.scheme.primary.withValues(alpha: 0.08)
                                    : null,
                                child: ListTile(
                                  leading: LotusIconBadge(
                                    icon:
                                        session.status ==
                                            TerminalSessionStatus.running
                                        ? Icons.play_circle_fill_rounded
                                        : Icons.terminal_rounded,
                                    size: 38,
                                    color:
                                        session.status ==
                                            TerminalSessionStatus.error
                                        ? ctx.scheme.error
                                        : null,
                                  ),
                                  title: Text(
                                    session.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ctx.text.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _statusLabel(session),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ctx.text.labelSmall,
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Excluir sessão',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 19,
                                    ),
                                    onPressed: () =>
                                        _deleteSession(ctx, ref, session),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteSession(
    BuildContext ctx,
    WidgetRef ref,
    TerminalSession session,
  ) async {
    final confirmed = await showLotusConfirm(
      ctx,
      title: 'Excluir sessão?',
      message:
          'O ambiente e o rootfs de "${session.name}" serão removidos do dispositivo.',
      confirmLabel: 'Excluir',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await ref
        .read(terminalControllerProvider.notifier)
        .deleteSession(session.id);
  }

  Future<void> _showAiConsent(BuildContext context, bool current) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 22),
            SizedBox(width: LotusSpace.md),
            Expanded(child: Text('IA e Terminal')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quando ativado, a IA pode solicitar comandos no terminal. Cada comando exige sua confirmação explícita antes de executar.',
                style: ctx.text.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: LotusSpace.md),
              const LotusPill(
                'Status atual',
                icon: Icons.lock_outline_rounded,
                dense: true,
              ),
              const SizedBox(height: LotusSpace.sm),
              Text(
                current
                    ? 'Permitido com confirmação por comando.'
                    : 'Bloqueado: nenhuma solicitação de execução é aceita.',
                style: ctx.text.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bloquear IA'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permitir com confirmação'),
          ),
        ],
      ),
    );
    if (allowed != null) {
      await ref.read(terminalAiConsentProvider.notifier).setConsent(allowed);
    }
  }

  Future<void> _showDiagnose(BuildContext context) async {
    final diag = await ref.read(terminalControllerProvider.notifier).diagnose();
    await showLotusTextPreview(
      context,
      title: 'Diagnóstico do Terminal',
      caption: 'Use essas informações para reportar problemas ou configurar o PRoot.',
      text: '''
Prototipo do terminal - Diagnóstico:
- PRoot disponível: ${diag['prootAvailable'] ?? false}
- Caminho PRoot: ${diag['prootPath'] ?? 'Não encontrado'}
- Diretório base: ${diag['rootfsBase']}
- Base existe: ${diag['baseExists'] ?? false}
- Plataforma: ${diag['platform']}
- Versão: ${diag['version']}

Se PRoot não estiver disponível, o terminal Alpine não funcionará neste dispositivo.
Instale PRoot via Termux ou use um dispositivo com suporte a PTY/PRoot nativo.
''',
    );
  }
}

String _statusLabel(TerminalSession session) {
  switch (session.status) {
    case TerminalSessionStatus.stopped:
      return session.rootfsPath != null
          ? 'Parada • Alpine pronto'
          : 'Parada • ambiente não instalado';
    case TerminalSessionStatus.bootstrapping:
      return 'Instalando Alpine…';
    case TerminalSessionStatus.starting:
      return 'Iniciando…';
    case TerminalSessionStatus.running:
      return 'Em execução';
    case TerminalSessionStatus.error:
      return 'Erro: ${session.lastError ?? 'desconhecido'}';
  }
}

LotusPillTone _toneFor(TerminalSessionStatus status) => switch (status) {
  TerminalSessionStatus.running => LotusPillTone.success,
  TerminalSessionStatus.error => LotusPillTone.danger,
  TerminalSessionStatus.bootstrapping ||
  TerminalSessionStatus.starting => LotusPillTone.warning,
  TerminalSessionStatus.stopped => LotusPillTone.neutral,
};

class _NoSession extends StatelessWidget {
  const _NoSession({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LotusEmptyState(
      title: 'Terminal Linux real',
      message: 'Crie uma sessão para baixar o minirootfs oficial do Alpine e abrir um shell via PTY. É necessário PRoot/PTY compatível com o dispositivo Android, sem root.',
      actionLabel: 'Nova sessão Alpine',
      onAction: onCreate,
      features: const [
        (Icons.lock_outline_rounded, 'Sem root'),
        (Icons.memory_rounded, 'PTY real'),
        (Icons.verified_outlined, 'Sem simulação'),
      ],
    );
  }
}

class _SessionView extends ConsumerWidget {
  const _SessionView({
    required this.session,
    required this.terminal,
    required this.controller,
    required this.bootstrapping,
    this.progress,
  });

  final TerminalSession session;
  final xterm.Terminal terminal;
  final xterm.TerminalController controller;
  final bool bootstrapping;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(terminalControllerProvider.notifier);
    final running = session.status == TerminalSessionStatus.running;
    final busy =
        bootstrapping || session.status == TerminalSessionStatus.starting;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LotusBreakpoints.contentMaxWidth,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LotusSpace.lg,
                LotusSpace.xs,
                LotusSpace.lg,
                LotusSpace.md,
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: LotusSpace.sm,
                      runSpacing: LotusSpace.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LotusPill(session.name, icon: Icons.terminal_rounded),
                        const LotusPill('Alpine', tone: LotusPillTone.primary),
                        LotusPill(
                          _statusLabel(session).split(' • ').first,
                          tone: _toneFor(session.status),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (bootstrapping)
                    FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: Text(
                        progress == null
                            ? 'Baixando'
                            : '${(progress! * 100).toStringAsFixed(0)}%',
                      ),
                    )
                  else if (running)
                    FilledButton.tonalIcon(
                      onPressed: () => notifier.stop(session.id),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Parar'),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: () => notifier.start(session.id),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        session.rootfsPath == null
                            ? 'Instalar e iniciar'
                            : 'Iniciar',
                      ),
                    ),
                ],
              ),
            ),
            if (bootstrapping && progress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: LotusSpace.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LotusRadius.pill),
                  child: LinearProgressIndicator(value: progress, minHeight: 4),
                ),
              ),
            if (session.status == TerminalSessionStatus.error &&
                session.lastError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LotusSpace.lg,
                  0,
                  LotusSpace.lg,
                  LotusSpace.md,
                ),
                child: LotusCard(
                  color: context.scheme.error.withValues(alpha: 0.08),
                  borderColor: context.scheme.error.withValues(alpha: 0.25),
                  radius: LotusRadius.sm,
                  padding: const EdgeInsets.all(LotusSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: context.scheme.error,
                      ),
                      const SizedBox(width: LotusSpace.sm),
                      Expanded(
                        child: Text(
                          session.lastError!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                  LotusSpace.md,
                  0,
                  LotusSpace.md,
                  LotusSpace.md,
                ),
                decoration: BoxDecoration(
                  color: context.palette.elevated,
                  borderRadius: BorderRadius.circular(LotusRadius.md),
                  border: Border.all(color: context.palette.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: running
                    ? xterm.TerminalView(
                        terminal,
                        controller: controller,
                        autofocus: true,
                        theme: _terminalTheme(context),
                        textStyle: const xterm.TerminalStyle(
                          fontSize: 13,
                          height: 1.35,
                        ),
                        padding: const EdgeInsets.all(LotusSpace.md),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(LotusSpace.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LotusIconBadge(
                                icon: busy
                                    ? Icons.downloading_rounded
                                    : Icons.terminal_rounded,
                                size: 52,
                                color: context.palette.muted,
                              ),
                              const SizedBox(height: LotusSpace.md),
                              Text(
                                busy
                                    ? 'Preparando o ambiente Alpine…'
                                    : session.rootfsPath == null
                                    ? 'Alpine ainda não instalado'
                                    : 'Sessão parada',
                                style: context.text.titleSmall,
                              ),
                              const SizedBox(height: LotusSpace.xs),
                              Text(
                                session.rootfsPath == null
                                    ? 'Toque em “Instalar e iniciar” para baixar o rootfs oficial e preparar o shell.'
                                    : 'Toque em “Iniciar” para abrir o shell. Requer PTY e PRoot compatíveis com a ABI do dispositivo.',
                                textAlign: TextAlign.center,
                                style: context.text.bodySmall?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

xterm.TerminalTheme _terminalTheme(BuildContext context) {
  final dark = context.isDark;
  return xterm.TerminalTheme(
    cursor: context.scheme.primary,
    selection: context.scheme.primary.withValues(alpha: 0.28),
    foreground: dark ? const Color(0xFFE7E9F4) : const Color(0xFF15161F),
    background: dark ? const Color(0xFF0B0C14) : const Color(0xFFFBFBFE),
    black: const Color(0xFF1B1C24),
    red: const Color(0xFFE06C75),
    green: const Color(0xFF5FB97E),
    yellow: const Color(0xFFD7A84C),
    blue: const Color(0xFF6C8FF5),
    magenta: const Color(0xFFB277D8),
    cyan: const Color(0xFF4FB8C9),
    white: const Color(0xFFE6E6EC),
    brightBlack: const Color(0xFF6E7080),
    brightRed: const Color(0xFFFF8A95),
    brightGreen: const Color(0xFF84D6A0),
    brightYellow: const Color(0xFFF0C56A),
    brightBlue: const Color(0xFF8FAAF9),
    brightMagenta: const Color(0xFFCF9BEE),
    brightCyan: const Color(0xFF71D7E7),
    brightWhite: Colors.white,
    searchHitBackground: const Color(0x55FFD166),
    searchHitBackgroundCurrent: const Color(0xAAFFD166),
    searchHitForeground: const Color(0xFF1A1B22),
  );
}
