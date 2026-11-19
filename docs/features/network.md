# Local network inventory (Phase 7.2)

Folder: `App/Features/Network/`. Root view: `NetworkRootView` (place inside a `NavigationStack`; it registers its own `NetRoute` destinations). All types are prefixed `Net`.

## What it does
- **Bonjour browser** (`NetBonjourService`, `@Observable @MainActor`): one `NWBrowser` per service type in a fixed list of 14 (`NetServiceKind.all`). Results show name, type, domain, interface and TXT keys, grouped by service name with a service count and last-seen time. Services that stop advertising stay listed, marked "No longer advertised".
- **Lazy resolve**: host and port are looked up only when the user opens a device, by opening one `NWConnection` to the Bonjour endpoint and reading the remote endpoint, then cancelling. Never done for the whole list.
- **Scope guard** (`NetScopeSheet`, `NetScope`): first-run sheet stating the limits (no port scanning, no credential guessing, no exploit attempts) with the toggle "I’m allowed to inspect this network". Stored once in `UserDefaults` (`assay.network.scopeAccepted`) because iOS does not expose the SSID without extra entitlements. A Reset button on the main screen clears it and stops browsing. Browsing and all live tests are blocked until it is confirmed.
- **Connect-time check** (`NetTCPProbe`, `NetProbeStore.runLatency`): five sequential TCP `NWConnection`s, 2 s timeout each, reports min/avg/max ms and loss, with a `Path`/`Canvas` sparkline. One test at a time across the whole feature. No bytes are sent.
- **Address policy** (`NetAddressPolicy`): typed addresses must be 10/8, 172.16/12, 192.168/16, 169.254/16, IPv6 fe80::/10 or fc00::/7, or a `.local` name. Public addresses and loopback are refused with a plain explanation. Discovered services use the same check except that IPv6 addresses advertised on the local link are accepted.
- **TLS check** (`NetCertInspector`, `NetTrustDelegate`): one `HEAD` request through an ephemeral `URLSession`, 5 s timeout. The delegate evaluates and captures the server trust, then **always cancels** the challenge (`.cancelAuthenticationChallenge`), so validation is never bypassed and no data is transferred. Non-trust challenges (passwords) are refused with no credential. Shows subject, issuer, valid from/until, days left, key type and size, self-signed, whether this iPhone trusts the chain. Tags: `Expired` (`.experimental`), `Weak` for RSA < 2048 (`.caution`), `In date` / `OK` (`.reversible`). Subject, issuer and dates come from a small DER reader (`NetCertParser`) because iOS has no public API for them; if parsing fails the field says "Not available".
- **Permission**: explains what the Local Network prompt is for. Denial is detected from the DNS-SD policy-denied error (-65570) and shows an Open Settings button. iOS gives no API to read the setting, so "allowed" is labelled Inferred.
- **Export**: `ShareLink` of a plain-text report (`NetReport.text`), including only what has been looked up or tested. Demo entries are marked `[DEMO]`.
- **Footer** on the main and device screens states the limits.

## Real, demo, not possible
| | |
|---|---|
| Real | Bonjour browsing, lazy resolve, TCP connect timing, TLS inspection, permission handling, report export |
| Demo | Six services (printer, speaker, media box, file server with an **expired** certificate, hallway camera with a **1024-bit RSA** self-signed certificate, hub with a valid EC certificate). Every demo row, section and result carries the Demo tag. No traffic is sent for them. Toggle: "Demo services" |
| Not possible on iOS | ARP table, ICMP ping, raw sockets, MAC addresses, reading the SSID without entitlements, listing devices that do not advertise over Bonjour, reading the Local Network permission directly |

## How to test
1. Simulator: open the screen, confirm the scope sheet, switch on Demo services, open "Demo · File server" and tap "Check certificate" (Expired), then "Demo · Hallway camera" (Weak, self-signed). "Test connect time" shows the sparkline, including a lost sample on the camera.
2. Device (real Bonjour): confirm the Local Network prompt, tap Start browsing, open a printer or web interface, then test it. A Mac running `python3 -m http.server` advertised via `dns-sd -R test _http._tcp local 8000` is a quick source.
3. Denied state: turn Local Network off for Assay in Settings, then start browsing; the Denied tag and Open Settings button appear.
4. Manual: Type an address, enter `8.8.8.8` (refused with explanation), then a LAN IP.

## Known limits
- Connect time is TCP handshake time, not ICMP RTT; a closed port counts as a loss.
- Resolve reads the address iOS chose for the connection; a service that accepts no TCP connection will show "Could not connect".
- Browsing stops when the screen leaves the foreground or disappears, so results are session-only; nothing is persisted except the scope flag.
- `NWBrowser.Result.interfaces` reports the interfaces the advert arrived on; the label is "name · kind".
- Not compiled here (parse-checked only).
