# Readiness review · implementation notes

Scope: fixes against the 20 November 2026 readiness review of build 8 (`cbedbd1`). This is a change set for the review branch, not a physical-device certification or a repair to SpringBoard.

| Report | Change on this branch | How to check |
| --- | --- | --- |
| B-01; B-02 | Split invalid SwiftUI state declarations. The Theme argument order is corrected on this branch, not necessarily `main`. | Build the entire app and widget in CI. |
| R-01 | A damaged, inaccessible or changed receipt file blocks mutations. The user must explicitly approve starting a new history, and the damaged bytes are retained. | `sh tests/readiness-operations/run.sh` |
| F-01; R-03 | Risk acknowledgement depends on tier and actual write capability; a dry run cannot write. Stop on a failed/unverified item, mark remaining changes not attempted. | Same fixture: check across mode, write capability, tier and acknowledgement. |
| AI-02; NET-01 | Carrier NAT isn't private LAN; a colon isn't proof of a local address. The shared classifier checks literals, local names, scopes and the endpoint used for requests. | `sh tests/readiness-network/run.sh` (offline). |
| CI-01; CI-02 | Pull requests and pushes to main run fixtures and the simulator build. Build jobs have read-only contents permission; optional renders are artifacts only. | A GitHub ruleset is a separate owner setting; the workflow itself does not require a check to merge. |
| R-02; X-01 | No made-up Demo health number or running transfer. Production ignores test launch arguments. | Check Demo and iPhone separately. SwiftUI previews and screenshot routes use Debug only. |
| A11Y-01 (partial) | New Fold Home/Studio use semantic iOS text styles, larger-text single-column tiles and existing Fold glyphs. | Check light, dark and largest Dynamic Type. This is not an app-wide accessibility sign-off. |

## Design provenance

The Fold mark, module icons and palette came from the owner's supplied design bundle. The native surfaces and actions are implemented in this repository; there is no new runtime UI dependency. The ComponentsKit catalogue on the owner's iPhone showed Card, Badge, Button, Divider and Progress examples; those are interaction references, not copied artwork or source. [ComponentsKit](https://componentskit.dev) publishes a separate MIT-licensed Swift package. The Chrome reference [Apple pass-builder](https://github.com/apple/pass-builder) concerns Wallet passes; no pass signing or pass artwork is added to Cards. Assay Cards still exports visual artwork only.

## Not closed by these changes

On-device protected preference writes, a protective whole-phone restore, signed scene exchange, trusted CMS verification in Signet, authenticated USB-helper receipts, StoreKit sandbox acceptance, and full-device accessibility/signing acceptance are not established. Private app bundles, user projects, tokens, Chrome cookies and browser history are not design assets. No bulk extraction was performed.
