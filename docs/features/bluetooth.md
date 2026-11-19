# Bluetooth notebook (Phase 7.1)

A BLE scanner and GATT reader, modelled on the idea of "Bluetooth Inspector". Root view: `BluetoothRootView` in `App/Features/Bluetooth/`.

## Files

| File | Purpose |
| --- | --- |
| `BLEModels.swift` | Value types, UUID name table, six-entry company table, device-type guess, value decoder, write-payload parser, demo data. No CoreBluetooth import, so it is easy to unit test. |
| `BLEScanner.swift` | `@MainActor @Observable final class BLEScanner`, wrapping `CBCentralManager` and `CBPeripheral`. |
| `BluetoothRootView.swift` | Device list, search, pins, permission states, Demo toggle, export sheet, signal tag, sparkline. |
| `BLEDeviceView.swift` | Device detail, connect and read, value history, the separate Write sheet. |

## What is real, demo, and not possible

| Thing | Status |
| --- | --- |
| Scan for nearby BLE devices, name, RSSI, service UUIDs, manufacturer data, Tx power, connectable flag | **Real** on a device. Tagged Observed. |
| RSSI smoothing (exponential, factor 0.3) and 60-sample history (at most one sample per second) | Real. The smoothed value is derived from Observed raw values. |
| Guessed device type | **Inferred** with a confidence (25–85 %), from advertised service UUIDs and company ID only. |
| Company name | Resolved only for Apple 0x004C, Microsoft 0x0006, Google 0x00E0, Samsung 0x0075, Nordic 0x0059, Garmin 0x0087. Everything else shows **Unknown**. |
| Service, characteristic and descriptor names | Only 0x1800, 0x180A, 0x180D, 0x180F and the characteristics listed in `BLEUUID.characteristics`. Others show "Unknown". |
| Connect, discover services, characteristics, descriptors, read | Real, only after the user taps "Connect and read services". |
| Write | Real, only from the Write sheet, only if the characteristic reports write support, only after the confirmation toggle is on. The sheet shows the exact bytes. Writing is disabled otherwise. |
| Notifications and indications | **Not subscribed in this version.** The properties are listed but nothing subscribes. |
| Background scanning | **Not supported.** Scanning stops when the screen closes or the app leaves the foreground. |
| Demo mode | Five sample devices (`DE000000-…` UUIDs) with sample GATT trees. Every row and value carries a Demo tag. No Bluetooth is used and demo writes send nothing. |
| iOS Simulator | Has no Bluetooth. The screen explains this and points to Demo mode. |

## Behaviour notes

- The `CBCentralManager` is created only when the screen first appears (this triggers the system permission prompt) and never in Demo mode.
- Scanning uses `AllowDuplicates = true` so RSSI keeps updating. This costs battery; the footer says so.
- Adverts go to a non-observed dictionary. The observed `peripherals` array is refreshed at most every 500 ms.
- Devices not heard for 120 s drop off the list unless pinned or connected. Maximum 400 devices.
- Pinned UUIDs are stored in `UserDefaults` under `assay.ble.pinned`. Nothing else is persisted.
- Closing a device screen, closing the root screen or leaving the app disconnects and stops scanning.
- A 15-second connect timeout shows an error rather than waiting forever.
- Number decoding is little-endian unsigned for 1, 2, 4 and 8 byte values. Meaning is only added for Battery Level, Heart Rate Measurement and Body Sensor Location.
- Export: the Share button (toolbar) opens a sheet showing the plain-text session log with a `ShareLink`. The log has timestamps, device names, peripheral UUIDs, advertised data, values read and an event list. It contains no user identifiers beyond peripheral UUIDs (which are per-phone iOS-assigned IDs).

## How to test

1. Simulator: open Bluetooth, see "Bluetooth is not available here". Turn on Demo mode, open "Demo Heart Strap", tap "Connect and read services", read Battery Level (87 %), Device Name, etc. Try Write… on the `FFF1` characteristic (demo only).
2. Real device, first run: the permission prompt appears when the screen opens. Deny it to see the "Open Settings" state. Turn Bluetooth off in Control Centre to see the off state.
3. Real device: scan next to a BLE device (a heart strap, earbuds, a tracker). Open it, tap Connect, read Battery Level (2A19) and Device Information strings. Share the log.
4. Pin a device, leave the screen, reopen: it stays pinned.
5. Background the app while scanning: scanning stops; return and it resumes.

## Known limits

- iOS hides the Bluetooth MAC address; only an iOS-assigned UUID is available, and it can differ between phones.
- Name comes from the advert local name first, then the cached GAP name; either may be stale.
- Connecting to a device that is already connected to another phone usually times out.
- Devices requiring pairing may prompt the system pairing dialog on read; that is iOS behaviour.
- Apple devices randomise addresses, so one physical device may appear as several entries over time.
- No decoding of Apple continuity or other manufacturer payloads beyond the company ID.

## Needs from the lead

- Info.plist: `NSBluetoothAlwaysUsageDescription` (already in `project.yml`). No `UIBackgroundModes` entry is needed or wanted.
- A route to `BluetoothRootView()` inside a `NavigationStack` (for example a row in Studio/More). No new `AppModel` properties are required.
