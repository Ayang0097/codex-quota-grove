# Codex Quota Widget · Quota Grove

**A visual Codex quota monitor and desktop widget for macOS and Windows.**

Your Codex quota, as a forest that fades. See your remaining **7-day Codex quota and reset time** at a glance; as quota drops, the landscape moves from forest to autumn, apocalypse, and wasteland.

[中文](README.md) · [Latest release v1.4.0](https://github.com/Ayang0097/codex-quota-grove/releases/latest) · [Report an issue](https://github.com/Ayang0097/codex-quota-grove/issues/new/choose)

![Actual app renders illustrating quota states, not real-time quota consumption](docs/screenshots/quota-grove-demo.gif)

| macOS Apple Silicon | Windows 10 / 11 x64 |
| :---: | :---: |
| **[Download for macOS](https://github.com/Ayang0097/codex-quota-grove/releases/download/v1.4.0/Quota-Grove-v1.4.0-macos-arm64.zip)** | **[Download for Windows](https://github.com/Ayang0097/codex-quota-grove/releases/download/v1.4.0/Quota-Grove-v1.4.0-windows-x64.zip)** |
| macOS 13+ · Unzip and move to Applications | Portable · Unzip and run `QuotaGrove.exe` |

Requires local Codex activity containing quota records. The macOS package is Apple Silicon only; the Windows package is x64 only.

## At a glance

- **Keep quota in sight.** See remaining weekly quota and reset time. Click for plan details and the last data update.
- **Tuck it away.** Drag the card to the screen edge; hover to reveal it again.
- **Read the landscape.** Forest at `70–100%`, autumn at `40–<70%`, apocalypse at `10–<40%`, and wasteland at `0–<10%`.
- **No API key or model calls.** Quota polling reads local records every 10 seconds and consumes no model tokens.

![Compact, expanded, and edge-stashed states](docs/screenshots/quota-grove-modes-en-v101.png)

## Install and start

**macOS:** unzip the download, move `Quota Grove.app` to Applications, and open it. The current build is ad-hoc signed and not Apple-notarized. If macOS cannot verify the developer, verify the download source first. After trying to open it, follow the prompt in System Settings → Privacy & Security → Open Anyway. See [Apple's instructions](https://support.apple.com/en-us/102445).

**Windows:** fully extract the ZIP and run `QuotaGrove.exe`. No separate .NET installation is needed. The build has no commercial code-signing certificate, so SmartScreen may show a warning. Verify the source and the [SHA-256 checksums](https://github.com/Ayang0097/codex-quota-grove/releases/download/v1.4.0/SHA256SUMS-v1.4.0.txt).

Use Codex locally to create quota records. **Click** to expand, **double-click** to refresh, **drag** to move or stash, and **right-click** for settings. On macOS, the widget follows the Codex/ChatGPT desktop client's visibility.

## What's in v1.4.0?

This release packages the background suites and revised quota thresholds previously available in the source tree.

| Feature | macOS | Windows |
| --- | :---: | :---: |
| Weekly quota, reset time, edge stashing | ✓ | ✓ |
| Four quota states, double-click leaf burst | ✓ | ✓ |
| Five background suites, custom backgrounds | ✓ | — |
| Optional local rain and snow effects | ✓ | — |

On macOS, right-click → Background suite to choose Quota Grove, Astral Terrarium, Cloudsea Beacon, Moonlit Conservatory, or Abyssal Reverie. See the [visual gallery](README.md) and [detailed guide (Chinese)](docs/technical-guide.md).

## Questions

**Why `--%` or an old value?** No trusted local record means `--%`. Without newer records, the last trusted result is retained. Expand the card to inspect the update time or double-click to scan again. This is not a real-time server status API.

**What leaves my computer?** No quota or Codex logs are uploaded, and there is no telemetry. Optional weather on macOS is off by default; enabling it sends a coarse location to fetch weather. See [privacy details](PRIVACY.md).

**Other quota windows or systems?** The widget focuses on the overall 7-day Codex quota. No Linux or Intel Mac binary is provided.

**Is this official?** No. This is an independent tool, not affiliated with or endorsed by OpenAI. The in-card Codex icon identifies the data source only.

## Feedback

[Report an issue](https://github.com/Ayang0097/codex-quota-grove/issues/new/choose) with your OS, app version, reproduction steps, and a redacted screenshot. Do not attach full Codex logs or credentials.

If it helps your workflow, a **Star** makes it easier to find again and helps other Codex users discover it.

[Build from source (Chinese)](docs/technical-guide.md#从源码构建) · [Windows development](windows/README.md) · [Data source](data-source-notes.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)

The code, documentation, and project-owned visuals remain under the repository's existing [all-rights-reserved license](LICENSE). Third-party names, icons, and marks remain with their respective owners.
