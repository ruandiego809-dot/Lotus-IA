// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../chat/data/chat_repository.dart';
import '../../providers/data/provider_repository.dart';

class AgentsPage extends ConsumerStatefulWidget {
  const AgentsPage({super.key});

  @override
  ConsumerState<AgentsPage> createState() => _AgentsPageState();
}

class _Agent {
  const _Agent(
    this.name,
    this.description,
    this.icon,
    this.specialty,
    this.prompt,
  );

  final String name;
  final String description;
  final IconData icon;
  final String specialty;
  final String prompt;
}

class _AgentsPageState extends ConsumerState<AgentsPage> {
  String? _starting;

  static const _agents = [
    _Agent(
      'Programador',
      'Escreve, revisa e corrige código com foco em qualidade.',
      Icons.code_rounded,
      'Engenharia',
      'Você é o agente Programador do Lótus AI. Ajude a escrever, revisar e corrigir código com explicações objetivas, boas práticas e atenção a segurança. Peça contexto do projeto quando necessário.',
    ),
    _Agent(
      'Designer',
      'Cria interfaces e conceitos visuais modernos e acessíveis.',
      Icons.palette_outlined,
      'UI/UX',
      'Você é o agente Designer do Lótus AI. Proponha interfaces, fluxos e conceitos visuais claros, acessíveis e consistentes. Entregue orientações práticas de UI/UX.',
    ),
    _Agent(
      'Analista',
      'Analisa requisitos, riscos e oportunidades de melhoria.',
      Icons.analytics_outlined,
      'Análise',
      'Você é o agente Analista do Lótus AI. Analise requisitos, arquitetura e problemas, identifique riscos e sugira melhorias priorizadas e justificadas.',
    ),
    _Agent(
      'Testador',
      'Planeja casos de teste e caça falhas e cenários de borda.',
      Icons.bug_report_outlined,
      'Qualidade',
      'Você é o agente Testador do Lótus AI. Crie planos de teste, casos, cenários de borda e estratégias para encontrar bugs e validar funcionalidades.',
    ),
    _Agent(
      'Arquiteto',
      'Define estrutura, módulos e decisões técnicas do projeto.',
      Icons.account_tree_outlined,
      'Arquitetura',
      'Você é o agente Arquiteto do Lótus AI. Proponha estrutura modular, decisões técnicas, trade-offs e organização do projeto com foco em manutenibilidade.',
    ),
    _Agent(
      'Compilador',
      'Diagnostica erros de build e organiza etapas de compilação.',
      Icons.build_circle_outlined,
      'Build',
      'Você é o agente Compilador do Lótus AI. Ajude a diagnosticar erros de build/compilação, configurar ambientes e organizar etapas de build com comandos e verificações.',
    ),
  ];

  Future<void> _startSession(_Agent agent) async {
    if (_starting != null) return;
    setState(() => _starting = agent.name);
    try {
      final provider = ref
          .read(providerControllerProvider)
          .value
          ?.defaultConfig;
      final chat = ref.read(chatControllerProvider.notifier);
      final id = await chat.createConversation(
        providerId: provider?.id,
        modelId: provider?.selectedModel,
      );
      await chat.renameConversation(id, 'Agente: ${agent.name}');
      await chat.updateSystemPrompt(id, agent.prompt);
      await chat.select(id);
      if (!mounted) return;
      LotusFeedback.show(
        context,
        'Sessão "${agent.name}" pronta.',
        tone: LotusSnackTone.success,
      );
      context.go('/chat');
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LotusScaffold(
      appBar: const LotusAppBar(
        title: 'Agentes',
        subtitle: 'Sessões com especialidades próprias',
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 760;
          final contentWidth = (constraints.maxWidth - LotusSpace.lg * 2).clamp(
            0.0,
            LotusBreakpoints.contentMaxWidth,
          );
          final cardWidth = twoColumns
              ? (contentWidth - LotusSpace.md) / 2
              : contentWidth;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              LotusSpace.lg,
              LotusSpace.xs,
              LotusSpace.lg,
              LotusSpace.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LotusBreakpoints.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AgentsHero(),
                    const SizedBox(height: LotusSpace.lg),
                    Wrap(
                      spacing: LotusSpace.md,
                      runSpacing: LotusSpace.md,
                      children: [
                        for (final agent in _agents)
                          SizedBox(
                            width: cardWidth,
                            child: _AgentCard(
                              agent: agent,
                              starting: _starting == agent.name,
                              disabled: _starting != null,
                              onStart: () => _startSession(agent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: LotusSpace.lg),
                    LotusCard(
                      color: context.scheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LotusIconBadge(
                            icon: Icons.groups_outlined,
                            size: 38,
                            color: context.palette.muted,
                          ),
                          const SizedBox(width: LotusSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trabalho colaborativo',
                                  style: context.text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: LotusSpace.xxs),
                                Text(
                                  'Delegação entre agentes com contexto compartilhado, tarefas encadeadas e ações auditáveis depende de integrações adicionais e consentimento explícito. Nada é simulado.',
                                  style: context.text.labelSmall?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgentsHero extends StatelessWidget {
  const _AgentsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LotusSpace.xl),
      decoration: BoxDecoration(
        gradient: context.palette.glow,
        borderRadius: BorderRadius.circular(LotusRadius.lg),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LotusBrandMark(size: 48, radius: 16),
          const SizedBox(width: LotusSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Especialistas sob demanda',
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: LotusSpace.xs),
                Text(
                  'Cada agente abre uma conversa com um prompt de sistema dedicado ao seu papel. As respostas usam o provedor e o modelo configurados por você.',
                  style: context.text.bodySmall?.copyWith(height: 1.55),
                ),
                const SizedBox(height: LotusSpace.md),
                const Wrap(
                  spacing: LotusSpace.sm,
                  runSpacing: LotusSpace.sm,
                  children: [
                    LotusPill('Provedor real', icon: Icons.hub_outlined),
                    LotusPill('Sem simulação', icon: Icons.verified_outlined),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.starting,
    required this.disabled,
    required this.onStart,
  });

  final _Agent agent;
  final bool starting;
  final bool disabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LotusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LotusIconBadge(icon: agent.icon, size: 42, gradient: true),
              const SizedBox(width: LotusSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name, style: context.text.titleSmall),
                    Text(agent.specialty, style: context.text.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LotusSpace.md),
          Text(
            agent.description,
            style: context.text.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: LotusSpace.lg),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: disabled ? null : onStart,
              icon: starting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(starting ? 'Abrindo' : 'Iniciar sessão'),
            ),
          ),
        ],
      ),
    );
  }
}
