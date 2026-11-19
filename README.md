# Lótus AI 🪷

Aplicativo Android (Flutter/Dart): central de IA com múltiplos provedores, chat, projetos, agentes (sessões especializadas) e módulo de terminal em preparação.

## Implementado

- **App/arquitetura:** Flutter modular (`app/`, `core/`, `features/`), tema escuro/claro, navegação por abas, identidade Lótus.
- **Provedores (adaptadores separados):** API keys em `flutter_secure_storage`, endpoint configurável, teste de conexão, listagem de modelos, modelo/provedor padrão, limite de contexto manual.
  - **Gemini:** SSE streaming, uso de tokens quando retornado.
  - **OpenAI-compatible:** `/chat/completions` streaming e `/models` (OpenAI, Groq, OpenRouter, DeepSeek, Mistral, Z.ai/GLM, Kilo Gateway, OpenCode, OpenClaw, Hugging Face router configurável, endpoints custom).
  - **Cohere:** adapter dedicado (v2 chat streaming).
  - Erros HTTP/rede/429/cancelamento tratados e exibidos (sem expor segredos).
- **Chat:** conversas persistentes, busca/exportação de histórico, prompt de sistema por conversa, streaming com interrupção, editar/reenviar, regenerar, retry, Markdown/cópia, auto-scroll.
- **Anexos no chat:** arquivos de texto são incluídos na mensagem, com limite de 200 KB e truncamento acima de 12.000 caracteres. Seleção de imagens pela interface ainda não está implementada; adaptadores OpenAI-compatible e Gemini possuem tratamento de imagens, mas isso não habilita o envio pela interface.
- **Métricas:** uso real exibido apenas quando a API retorna; estimativa local e %/restante com base em limite conhecido (API ou manual). Créditos/quotas não inventados.
- **Projetos (local):** workspace no app (criar/renomear/editar/excluir, navegação, diff simples), importar/exportar ZIP e importar repositório público do GitHub via download ZIP (`main`/`master`).
- **Agentes:** sessões de chat com prompts de sistema especializados (Programador, Designer, Analista, Testador, Arquiteto, Compilador) usando provedores/modelos reais.
- **Release/CI:** assinatura via `android/key.properties` quando presente (fallback debug), `android/key.properties.example`, workflow CI (`.github/workflows/ci.yml`) com analyze/test/build.

## Limitações conhecidas (dependem de integração nativa/plataforma externa)

- **Terminal Linux real:** PRoot/PTY, Alpine/Ubuntu/Debian, imagens/sessões/pacotes/filesystem e ponte IA↔terminal com autorização por ação exigem componentes nativos/binários e validação em dispositivo (módulo expõe requisitos/estado, sem shell simulado).
- **Agentes autônomos colaborativos:** orquestração multi-agente com execução real de ferramentas, acesso direto a projeto/terminal e ações auditáveis requer infraestrutura adicional de permissões/execução.
- **Projetos avançados:** clone Git nativo com auth, execução de código e build Android in-app.
- **Multimodal completo e métricas exatas:** dependem do que cada provedor/modelo expõe.
- **Distribuição produção:** requer keystore de produção e AAB/Play Store; releases automatizadas neste repositório usam assinatura debug quando `key.properties` não é fornecido.

## Compilação

Pré-requisitos: Flutter SDK, Android SDK (API 33+).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Assinatura: copie `android/key.properties.example` para `android/key.properties` e configure o keystore (não commitar).

## Segurança

- API keys armazenadas com `flutter_secure_storage`, não registradas em logs e não exportadas.
- Sem respostas de API simuladas; erros reportados conforme retorno real.
