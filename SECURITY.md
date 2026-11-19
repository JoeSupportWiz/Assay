# Security

Assay handles pairing records, signing identities and API keys. Please report anything that could expose them privately to the owner rather than in an issue.

**Rules the code follows**
- Secrets live only in the Keychain (`AfterFirstUnlockThisDeviceOnly`). Never in UserDefaults, logs, exports, prompts or screenshots.
- UDID, serial and ECID are redacted by default everywhere.
- The loopback tunnel routes only the loopback host. No default route, no DNS capture.
- AI providers receive the minimum context, after you choose them.
- Bluetooth writes and every device change ask first.
