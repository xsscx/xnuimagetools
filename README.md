# XNU Image Tools

Multi-platform image generation and fuzzing toolkit for iOS, watchOS, and Mac Catalyst. Generates diverse baseline images across platforms, then fuzzes them with ICC profile embedding across 22+ output formats targeting Preview, Safari, iMessage, Mail, and Notes.

The [XNU Image Fuzzer](https://github.com/xsscx/xnuimagefuzzer) is included as a **git submodule** at `XNU Image Fuzzer/`. xnuimagefuzzer is the primary development repository for the fuzzer source code — all code changes should be made there first.

## Clone

```bash
git clone --recurse-submodules https://github.com/xsscx/xnuimagetools.git

# If already cloned without submodules:
git submodule update --init --recursive

# Update submodule to latest xnuimagefuzzer:
git submodule update --remote "XNU Image Fuzzer"
```

## Workflow

1. Generate baseline images with xnuimagetools (iOS, watchOS, Mac Catalyst)
2. Fuzz with [xnuimagefuzzer](https://github.com/xsscx/xnuimagefuzzer) (`--pipeline`, `--chain`, `--input-dir`)
3. Embed ICC profiles (clean + [mutated](https://github.com/xsscx/research/tree/main/colorbleed_tools))
4. Feed to target apps: Preview, Safari, iMessage, Mail, Notes
5. Collect crashes from `~/Library/Logs/DiagnosticReports/`

## Components

| Component | Platform | Language | LOC | Notes |
|-----------|----------|----------|-----|-------|
| XNU Image Fuzzer | macOS (Mac Catalyst) | Objective-C | 5,800+ | git submodule → [xsscx/xnuimagefuzzer](https://github.com/xsscx/xnuimagefuzzer) |
| XNU Image Generator for iOS | iOS | Swift | — | |
| XNU Image Generator for Watch | watchOS | Swift | — | |
| VideoToolbox Fuzzer | iOS / macOS | Obj-C + C | 1,775 | |

## Quick Start

```bash
# Open workspace in Xcode, update Team ID, select scheme, Run
open "XNU Image Tools.xcworkspace"

# Mac Catalyst CLI build (unsigned)
xcodebuild build \
  -project "XNU Image Fuzzer/XNU Image Fuzzer.xcodeproj" \
  -scheme "XNU Image Fuzzer" \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# VideoToolbox fuzzer
cd VideoToolbox/Fuzzing && make
build/videotoolbox-runner -t 60 -o /tmp/fuzzed-frames big.mov
```

## VideoToolbox Fuzzer

Three-component video frame mutation fuzzer targeting Apple's hardware decoding pipeline:

| Component | File | Purpose |
|-----------|------|---------|
| Runner | `videotoolbox-runner.m` | AVFoundation frame extraction, mutations, PNG output |
| Interposer | `videotoolbox-interposer.c` | DYLD `IOConnectCallMethod` replacement for IOKit fuzzing |
| Launcher | `runner.c` | iOS AMFI bypass for process attachment |

Built with ASAN+UBSAN+coverage via Makefile (not Xcode). Uses `big.mov` (20MB) as default input.

## CI/CD Workflows

| Workflow | Jobs | Purpose |
|----------|------|---------|
| `build-and-test.yml` | 8 | Build, generate images, extract ICC seeds |
| `cached-build.yml` | — | Fast build with DerivedData cache |
| `code-quality.yml` | — | ObjC syntax, Python lint, CMake check |
| `instrumented.yml` | 3 × (macOS 14, 15) | ASAN+UBSAN: Mac Catalyst + macOS native + coverage |
| `videotoolbox.yml` | 4 | Build, coverage, static-analysis, fuzz-and-commit |
| `release.yml` | — | Tag-triggered release with artifacts |

All actions SHA-pinned. `persist-credentials: false`. `BASH_ENV=/dev/null`.

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 14+ (arm64, x86_64) | ✅ |
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
- [VideoToolbox Fuzzer](VideoToolbox/Readme.md) — VideoToolbox interposer docs
- [VideoToolbox Instructions](.github/instructions/videotoolbox.instructions.md) — path-specific build/code patterns
- [XNU Image Fuzzer](https://github.com/xsscx/xnuimagefuzzer) — primary fuzzer repo
- [Security Research](https://github.com/xsscx/research) — ICC profile analysis, CFL fuzzers, MCP server
