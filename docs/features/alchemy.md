# AI providers and Alchemy chat (Phase 5.1 / 5.2)

Folders: `App/Features/Alchemy/` and `App/Core/AI*.swift`. Root view: `AlchemyRootView` (place inside a `NavigationStack`; it pushes `AISettingsView` itself). All types are prefixed `AI`.

## Files
| File | Contents |
|---|---|
| `Core/AIProvider.swift` | `AIProviderKind` (names, default base URLs, wire format, auth style, default and economy model), `AITask`, `AIMessage`, `AIReply`, `AIError` (plain-English messages), `AITestResult` |
| `Core/AIPrivacy.swift` | `AIPrivacyLabel`, `AIHost` (address classification), `AIRedactor`, `AIStoredSettings` (non-secret settings in `UserDefaults`) |
| `Core/AIKeychain.swift` | `AIKeychain` save / delete / has / masked |
| `Core/AIClient.swift` | `actor AIClient`: `complete(messages:system:provider:model:maxTokens:)` and `test(...)` |
| `Core/AIService.swift` | `AIService` (observable settings, status, consent), `AIPrompts`, `AIDemo` |
| `Core/AIDiagnosis.swift` | `AIDiagnosis.suggest(text:)` and `AIDiagnosisResult` |
| `Features/Alchemy/*` | `AlchemyRootView`, `AIChatModel`, `AIConsentSheet`, `AISettingsView` (+ `AIProviderDetailView`) |

## What it does
- **Providers**: Minis (placeholder), OpenAI (`/chat/completions`), Anthropic (`/messages`, `x-api-key` + `anthropic-version: 2023-06-01`), Google (`models/{model}:generateContent`, `x-goog-api-key`), OpenRouter (OpenAI-compatible), Ollama (`/api/chat`, no key, editable base URL) and a custom OpenAI-compatible endpoint. Default base URLs are as specified; model ids are suggestions and are editable per provider (standard and economy).
- **AIClient**: non-streaming `URLSession` (ephemeral, no cache or cookies, redirects refused so a key cannot be forwarded). 60 s request timeout; refuses prompts over 60 000 characters before any network call; refuses unencrypted `http` unless the host is localhost, a private address or `.local`. Errors are mapped from status code to plain English (invalid key, network, model not found, rate limit, no credit, provider busy, blocked). Response bodies are never shown, logged or returned.
- **Test connection**: one request ("Reply with the single word OK", 16 tokens, 10 s timeout). Shows latency in ms on success, or a plain-English reason. It sends no user text or device facts.
- **Keychain**: `kSecClassGenericPassword`, service `com.joesupportwiz.assay.ai`, account = provider id, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Keys are shown only as `••••` + last four (short keys show just the dots). The key is read at request time and only placed in an HTTP header. Never in `UserDefaults`, URLs, prompts or logs. Deleting a key also withdraws send consent.
- **Privacy label**: hosted providers = "Leaves your phone". Ollama / custom / Minis with a localhost or 127.x/::1 address = "Stays on this phone"; a private address (10/8, 172.16/12, 192.168/16, 169.254/16, 100.64/10, fc00::/7, fe80::/10) or `.local` = "Stays on your LAN". Any other host name is treated as hosted.
- **Consent sheet** (`AIConsentSheet`): before the first message to a hosted provider, lists the exact system prompt and messages that will be sent (already redacted), the redaction count ("N items redacted") and a toggle "Send to <provider>" that must be on before the pinned button works. Remembered per provider; shown again the first time device context is included. Can be withdrawn in the provider screen.
- **Redactor** (`AIRedactor`): removes UDID-like (8 hex, then dash groups of 4-16 hex), 40-hex legacy UDIDs, ECID-like (`ECID: …`, `0x` + 12-16 hex), serial-like (labelled serial/IMEI/MEID, and bare 10-12 character upper-case alphanumerics containing a digit and a letter), 15-digit numbers, MAC addresses, PEM blocks, `sk-…` / `AIza…` / bearer tokens, `pairing record: …`, `host id`, `escrow bag`, `private key`, `api key`, `password` style assignments and long base64-like blobs. It is a safety net, not a guarantee, which is why the sheet shows the exact text.
- **Settings screens**: provider list with status (Configured / Needs key / Not available) and privacy line, default provider, per-task model picker (Diagnose, Tweak help, Asset drafts, plus Alchemy chat) choosing Standard / Economy / Custom id, editable base URL and model for Ollama / custom / Minis, key entry, Test connection.
- **Alchemy chat**: bubbles are plain rounded rectangles in theme colours (speaker named in text), input pinned at the bottom, "System prompt" disclosure showing the exact text sent, "Device context" toggle (off by default; adds model and iOS version only, never UDID, serial or name), starter prompts, an "AI proposes, you approve" banner, retry on failure. The chat has no code path to the device: it does not touch `model.activePlan`, the engine or receipts, and the reply text is only displayed.
- **`AIDiagnosis.suggest(text:)`**: sends the symptom text (redacted) with the id / title / cause of every `Knowledge.symptoms` entry, asks for JSON `{"id","explanation"}`, extracts the first JSON object, validates the id against the known list (case-insensitive, anything else becomes `nil`) and clips the explanation to two sentences. It never returns or applies a fix; the lead maps `symptomID` to `Symptom.plan(current:)` which goes through the normal review sheet.

## Real, demo, not possible
| | |
|---|---|
| Real | Every provider request, key storage, redaction, privacy label, consent sheet, status, test connection, diagnosis suggestion |
| Demo | The "Demo" toggle (chat header and AI settings). Replies are canned, begin with "Demo reply: sample text…", and every bubble carries a Demo tag. They come from `Knowledge.match`, not a model. `AIDiagnosis.suggest` in demo mode uses keyword matching and sets `isDemo = true`. Demo messages are never sent to a real model. The `-uiDemo` launch argument turns it on (not saved) |
| Not possible yet | **Minis**: shown as "Not available from inside this app yet" unless the user types a local OpenAI-compatible endpoint (then it behaves as a local endpoint). There is no way for Assay to call the Minis app's configured models. Streaming is not implemented. Chat does not change the device by design |

## How to test
1. Open Alchemy, turn **Demo** on, tap "Why is my clock stuck at 9:41?" and check the Demo-tagged reply. Open "System prompt" and "AI settings".
2. AI settings > a hosted provider: paste a throwaway key, check it shows `••••` + last four, tap Test connection. Try a wrong key (invalid key message), a wrong model (model not found) and aeroplane mode (network).
3. Turn Demo off, send a message: the consent sheet should list the system prompt and message and keep the button disabled until "Send to <provider>" is on. Type a fake UDID (`00008030-001A2B3C4D5E6F07`) and check "1 item redacted" and the placeholder in the preview.
4. Ollama: set a LAN base URL (`http://192.168.1.20:11434`); the privacy line should read "Stays on your LAN" and no consent sheet appears. `http://localhost:11434` reads "Stays on this phone".
5. Minis: provider detail shows "Not available from inside this app yet" until a local endpoint is entered.
6. Device context on with a demo or real snapshot: the system prompt disclosure gains a "Device context" block with model and iOS only.

## Known limits
- No streaming; replies appear when complete (60 s limit).
- Model ids are suggestions and will go out of date; change them in settings.
- Redaction is pattern-based and can miss unusual identifiers or free-text secrets. The preview is the real safeguard.
- Local-network Ollama needs the iOS Local Network permission (already declared in `project.yml`). Plain `http://` to a LAN address may be blocked by App Transport Security unless the lead adds `NSAppTransportSecurity > NSAllowsLocalNetworking = YES` to Info.plist (see the hand-off note).
- A custom host name that resolves to a private address but is not `.local` is treated as hosted (the safe assumption), so it asks for consent.
- Consent is stored in `UserDefaults` as provider ids only (no keys).
