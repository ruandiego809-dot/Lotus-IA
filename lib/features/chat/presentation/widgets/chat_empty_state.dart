// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.onNew,
    required this.onSuggestion,
  });

  final VoidCallback? onNew;
  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    (
      Icons.code_rounded,
      'Revisar código',
      'Revise este trecho e aponte problemas de desempenho.',
    ),
    (
      Icons.lightbulb_outline_rounded,
      'Explicar um conceito',
      'Explique de forma objetiva, com um exemplo prático.',
    ),
    (
      Icons.auto_awesome_outlined,
      'Planejar um projeto',
      'Monte um plano com etapas, riscos e prioridades.',
    ),
    (
      Icons.translate_rounded,
      'Traduzir e melhorar',
      'Traduza o texto a seguir e melhore a clareza.',
    ),
    (
      Icons.terminal_rounded,
      'Comando do terminal',
      'Gere um comando para o terminal Linux.',
    ),
    (
      Icons.article_outlined,
      'Resumir texto',
      'Resuma este artigo mantendo os pontos principais.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LotusSpace.xl,
          LotusSpace.xl,
          LotusSpace.xl,
          LotusSpace.xxxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: LotusBrandMark(size: 72, radius: 24)),
              const SizedBox(height: LotusSpace.xl),
              Text(
                'Bem-vindo ao Lótus',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: LotusSpace.sm),
              Text(
                'Sua central de IA com múltiplos provedores. Escolha um modelo, envie uma mensagem e continue de onde parou.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(height: 1.55),
              ),
              const SizedBox(height: LotusSpace.xl),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_comment_outlined, size: 19),
                label: const Text('Nova conversa'),
              ),
              const SizedBox(height: LotusSpace.xxl),
              Text(
                'Comece com uma ideia',
                style: context.text.labelSmall?.copyWith(
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: LotusSpace.sm),
              for (final suggestion in _suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: LotusSpace.sm),
                  child: _SuggestionCard(
                    icon: suggestion.$1,
                    title: suggestion.$2,
                    prompt: suggestion.$3,
                    onTap: () => onSuggestion(suggestion.$3),
                  ),
                ),
              const SizedBox(height: LotusSpace.sm),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Ajustar provedores e chaves'),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.muted,
                    textStyle: context.text.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.prompt,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LotusCard(
      onTap: onTap,
      radius: LotusRadius.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: LotusSpace.md,
        vertical: LotusSpace.md,
      ),
      child: Row(
        children: [
          LotusIconBadge(icon: icon, size: 34),
          const SizedBox(width: LotusSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall,
                ),
              ],
            ),
          ),
          Icon(
            Icons.north_east_rounded,
            size: 15,
            color: context.palette.muted,
          ),
        ],
      ),
    );
  }
}
