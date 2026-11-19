# Analyse with Minis

**What it does.** Assay prepares a point-in-time diagnostic report. You review the exact JSON before you copy, share or save it. Minis analyses a **copy**, not your live phone. There is no network listener to keep alive and no need to grant Assay a pairing record, developer account, Minis token or access to the Minis sandbox.

## Quick handoff
1. Open **Lab → Analyse with Minis** (also in **Studio → Alchemy**). Select **iPhone only** for real public device facts; **Demo** creates clearly labelled synthetic evidence.
2. Optionally include up to 20 same-engine receipt summaries, or in a non-demo mode **Add backup log summary**. This reads one UTF-8 log of up to 8 MiB locally and exports **counts only**: sampled backup heartbeats, maximum reported callback-idle seconds, last reported percent, and explicit reset/completion lines. These are excerpt statistics; repeats, retries and multiple runs can appear in one input. They are not timings for a particular backup or proof of packet loss. No recognised lines → no summary, not a healthy backup.
3. Tap **Prepare report → Use this report** after reviewing the JSON. **Copy report and open Minis** copies it with the displayed analysis prompt to the local clipboard for three minutes, then opens a new chat; paste and send yourself. Or use **Share reviewed JSON** / **Save JSON to Files** to bring it into an existing chat. Minis uses whichever model you choose, which can be hosted. Assay sends no model request in this flow.

## Optional: ask about your latest report without attaching it again
- In Files create a dedicated folder **Assay Reports**, preferably under **On My iPhone**. In Minis **Settings → Mount External Folders**, choose it with the mount name `Assay Reports`. Leave **Allow writes** off. Do not mount your entire Documents or Downloads folder for this feature. Mounts are visible across Minis chats.
- From Assay, **Save JSON to Files** in that folder. Each export has its own filename; keep two exports from the same engine to compare them. Folder access is not required for manual sharing.
- On this installation `assay-reports` is already registered. On a fresh installation run `sh integrations/minis/setup.sh` from the checked-out Assay repo in Minis. It registers a local STDIO MCP reader; it does not mount anything and will not overwrite another server. Set it up again if your shell environment is reset. Disable it in Minis MCP settings or run `minis-mcp-cli disable assay-reports`; remove the mount to revoke access to the folder.

| Tool | Result |
|---|---|
| `assay_status` | Number of reviewed reports, oldest/latest export, latest age, folder availability and skipped/incomplete coverage |
| `assay_latest` | Latest privacy-filtered report in that engine, with evidence labels and optional log counts |
| `assay_compare` | Differences for the two latest distinct export times, plus elapsed time and coverage limits |

Default engine is `iphone`; pass `{"engine":"demo"}` for samples or `{"engine":"mac"}` for the Mac-selection preview. No arbitrary file paths, shell commands, scans or writes are exposed. Unique device identifiers are deliberately absent; **same engine does not prove same physical phone**. The current iPhone engine cannot observe SpringBoard preferences or live transfers. Real-data fields are limited to what the OS or your explicitly selected log can show. A successful source read is not a verified cause of a symptom.

**Example question:** “Read my latest Assay report. Was there an actual connection reset, or just a long idle interval? Give me the sample count, the time window we know, the evidence, and one read-only check. If there’s an older report, tell me what changed.”

**Tests:** `python3 -m unittest discover -s integrations/minis/tests -v`. See [reader implementation](../../integrations/minis/assay_reports.py). Test fixtures are synthetic and never added to the user's report folder.
