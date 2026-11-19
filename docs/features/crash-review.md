# Crash review (Lab)

**Use one report, not a diagnostic archive.** On iPhone, go to Settings → Privacy & Security → Analytics & Improvements → Analytics Data. Open the app crash report around the time of the incident. Use Share → Save to Files → On My iPhone. In Lab → Crash review, choose that `.ips` file, or try the labelled synthetic example instead. No analytics enrolment, sysdiagnose collection, account or connection is required.

The screen reports observations, not a suspected cause, diagnosis or device-health score. For example, “EXC_BAD_ACCESS — An attempted memory access failed” does not identify the faulty component. **Unknown** means a supplied field is not recognised or cannot be verified; **Unavailable** means the report did not supply usable source fields (e.g. no thread was identified).

## Input and privacy limits

- One user-selected local regular `.ips` file (case-insensitive), **at most 5 MiB / 5,242,880 bytes**, inclusive. Both the chunked file reader and the in-memory parser enforce the limit. The picker URL is used only while reading; Assay keeps no bookmark, file copy, or log history.
- One JSON object, or a one-line JSON header followed by a JSON body. An explicit bug type must be `309` or `109`, and the body must have crash evidence. Other analytics reports, including jetsam and panic reports, are unsupported. Broken JSON is not interpreted as a partial crash. There is no sysdiagnose extraction, symbolication, general log parser or background scan.
- Projection only: numeric OS version (not build), a recognised Mach exception and its fixed explanation, a recognised termination namespace and signal, the **one-based** crashing-thread ordinal and count of threads listed. A zero-based `faultingThread` must be in range; if omitted, exactly one boolean `triggered: true` can identify the thread instead. Thread IDs are never ordinals.
- No filenames, paths, process names, PIDs, incident IDs, addresses, free text, timestamps, stacks or thread names in the summary or error messages. Sharing is optional: open **Review summary for sharing**, read the exact text, then use **Share this text only**. The selected file is never the share item. Clearing the review does not delete the original file; manage that separately in Files.

## Integration and offline checks

`CrashReviewView()` is the iOS 17 Lab destination. `CrashReview.read(_ url: URL) throws -> CrashEvidence` and `CrashReview.parse(_ bytes: Data) throws -> CrashEvidence` require no UI; `CrashEvidence.summary` is the same projection used for display and sharing. Failures are `CrashReviewError.file`, `.size`, `.malformed`, or `.unsupported` with fixed user-facing messages.

From the repository root, run the Foundation fixtures with no network or credentials:

```sh
out=$(mktemp -d)
swiftc App/Features/CrashReview/CrashReview.swift tests/crash-review/Fixture.swift -o "$out/check" && "$out/check"
rm -rf "$out"
```
