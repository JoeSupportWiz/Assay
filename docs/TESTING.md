# Testing

## Review renders (no install needed)
1. GitHub › **Actions** › **Assay iOS CI** › **Run workflow**, mode `screenshots`.
2. Wait ~10 min. Open the run › **Artifacts** › `Assay-screens`.
3. The same PNGs are committed to `docs/app-screens/` when the workflow is run with **commit** ticked.

## Install on your iPhone
1. Run the workflow with mode `ipa`.
2. Download `Assay-unsigned-ipa`.
3. Sign it with your own certificate (Sideloadly, your signing tool or Signet once it lands) and install.

## What works in which build
| Area | Simulator | Your iPhone, unsigned → self-signed |
|---|---|---|
| UI, themes, motion | ✅ | ✅ |
| Demo engine (sample device) | ✅ | ✅ (labelled **Demo**) |
| On-device facts (model, iOS, storage, battery) | partial | ✅ |
| Bluetooth / local network | ✗ | ✅ after permission |
| Loopback tunnel, system backup, real tweak writes | Not included | Not included; importing a pairing file or re-signing will not enable them in this version. Choose Demo for the simulated flow. |
| StoreKit Pro | ✅ with `Assay.storekit` | sandbox only |

Anything running on the Demo engine shows a **Demo** tag. Nothing is presented as live device data unless it was observed.
