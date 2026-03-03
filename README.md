# XNU Image Tools

Multi-platform image generation and fuzzing toolkit for iOS, watchOS, and Mac Catalyst. Generates diverse baseline images across platforms, then fuzzes them with ICC profile embedding across 22 output formats targeting Preview, Safari, iMessage, Mail, and Notes.

## Workflow

1. Generate baseline images with xnuimagetools (iOS, watchOS, Mac Catalyst)
2. Fuzz with [xnuimagefuzzer](https://github.com/xsscx/xnuimagefuzzer) (`--pipeline`, `--chain`, `--input-dir`)
3. Embed ICC profiles (clean + [mutated](https://github.com/xsscx/research/tree/main/colorbleed_tools))
4. Feed to target apps: Preview, Safari, iMessage, Mail, Notes
5. Collect crashes from `~/Library/Logs/DiagnosticReports/`

## Components

| Component | Platform | Language |
|-----------|----------|----------|
| XNU Image Fuzzer | macOS (Mac Catalyst) | Objective-C |
| XNU Image Generator for iOS | iOS | Swift |
| XNU Image Generator for Watch | watchOS | Swift |
| VideoToolbox Interposer | iOS / macOS | Objective-C |

## Quick Start

```bash
# Open workspace in Xcode, update Team ID, select scheme, Run
open "XNU Image Tools.xcworkspace"
```

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 15+ (arm64, x86_64) | ✅ |
| iOS / iPadOS 18+ | ✅ |
| watchOS 11+ | ✅ |
| visionOS 2.x | ✅ |

## Sample Output

### iOS / Mac / Vision Pro
<img src="https://xss.cx/2024/05/26/img/xnuimagetools_ios-filmstrip.jpg" alt="XNU Image Tools iOS Example Output" style="height:286px; width:818px;"/>

### watchOS
<img src="https://xss.cx/2024/05/26/img/xnuimagetools_watchos-filmstrip.jpg" alt="XNU Image Tools watchOS Output" style="height:286px; width:818px;"/>

## Documentation

- [Copilot Instructions](.github/copilot-instructions.md) — build commands, architecture, debug env vars
- [XNU Image Fuzzer](https://github.com/xsscx/xnuimagefuzzer) — primary fuzzer repo
- [VideoToolbox Fuzzer](VideoToolbox/Readme.md) — VideoToolbox interposer docs
