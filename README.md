# Lótus AI 🪷

Android app (Flutter/Dart): AI hub with multiple providers, chat, projects, agents (specialized sessions) and terminal module in preparation.

## Implemented

- **App/architecture:** Modular Flutter (`app/`, `core/`, `features/`), dark/light theme, tab navigation, Lótus identity.
- **Providers (separate adapters):** API keys in `flutter_secure_storage`, configurable endpoint, connection test, model listing, default provider/model, manual context limit.
  - **Gemini:** SSE streaming, token usage when returned.
  - **OpenAI-compatible:** `/chat/completions` streaming and `/models` (OpenAI, Groq, OpenRouter, DeepSeek, Mistral, Z.ai/GLM, Kilo Gateway, OpenCode, OpenClaw, configurable Hugging Face router, custom endpoints).
  - **Cohere:** dedicated adapter (v2 chat streaming).
  - HTTP/network/429/cancellation errors handled and displayed (without exposing secrets).
- **Chat:** persistent conversations, history search/export, system prompt per conversation, streaming with interruption, edit/resend, regenerate, retry, Markdown/copy, auto-scroll.
- **Chat attachments:** text files included in the message, with 200 KB limit and truncation above 12,000 characters. Image selection via UI not yet implemented; OpenAI-compatible and Gemini adapters have image handling, but this does not enable sending via the interface.
- **Metrics:** real usage displayed only when the API returns it; local estimate and %/remaining based on known limit (API or manual). Credits/quotas not invented.
- **Projects (local):** in-app workspace (create/rename/edit/delete, navigation, simple diff), import/export ZIP, import public GitHub repo via ZIP download (`main`/`master`).
- **Agents:** chat sessions with specialized system prompts (Programmer, Designer, Analyst, Tester, Architect, Compiler) using real providers/models.
- **Release/CI:** signing via `android/key.properties` when present (debug fallback), `android/key.properties.example`, CI workflow (`.github/workflows/ci.yml`) with analyze/test/build.

## Known limitations (depend on native integration/external platform)

- **Real Linux terminal:** PRoot/PTY, Alpine/Ubuntu/Debian images, sessions/packages/filesystem and IA↔terminal bridge with per-action authorization require native components/binaries and device validation (module exposes requirements/status, no simulated shell).
- **Collaborative autonomous agents:** multi-agent orchestration with real tool execution, direct project/terminal access and auditable actions require additional permission/execution infrastructure.
- **Advanced projects:** native Git clone with auth, in-app code execution and Android build.
- **Full multimodal and exact metrics:** depend on what each provider/model exposes.
- **Production distribution:** requires production keystore and AAB/Play Store; automated releases in this repo use debug signing when `key.properties` is not provided.

## Build

Prerequisites: Flutter SDK, Android SDK (API 33+).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Signing: copy `android/key.properties.example` to `android/key.properties` and configure the keystore (do not commit).

## Security

- API keys stored with `flutter_secure_storage`, not logged and not exported.
- No simulated API responses; errors reported as per real return.
