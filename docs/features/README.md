# Studio and Lab · first combined review

This review uses sample inputs, not a paired iPhone. It does not grant permissions, write to a peripheral, import a real profile, send a paid AI request, or sign/install an app.

| Start here | What to try in Demo | What the simulator does **not** prove |
|---|---|---|
| **Lab → Bluetooth notebook** | Open a sample peripheral. Inspect the service UUID, RSSI history and sample battery characteristic. | Radio discovery, hardware timing, or read/write success on your accessory. |
| **Lab → Local network** | Compare the six sample services. Inspect the certificate expiry/strength examples. | Bonjour permission prompts, TCP timing or certificate trust on your LAN. |
| **Studio → Signet** | Inspect the sample app and its extensions. Compare an expiring profile with an entitlement mismatch. | Authenticity of an embedded CMS profile or binary entitlements. Signing, installation and Apple account changes are not in this build. |
| **Studio → Alchemy** | Turn on **Demo**, ask about the 9:41 clock, and inspect the prompt. Under **Lab → Diagnose**, compare offline matches with the optional AI second opinion. | Reachability of Ollama/Minis or success with a hosted model or real API key. Alchemy never applies a fix. |

**Next physical checks:** use an accessory and LAN you own; try a known IPA from Files; connect one provider deliberately, inspect its destination and redacted preview, and cancel once before sending. No keys or real device identifiers belong in a bug report.

**Minis analysis:** [Review, share and compare diagnostic snapshots](minis.md). This uses a read-only export and does not require an AI key or device pairing.

**Further detail:** [Bluetooth](bluetooth.md) · [Network](network.md) · [Signet](signet.md) · [Alchemy](alchemy.md) · [Simulator captures](../app-screens/README.md).
