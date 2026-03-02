# Copilot Instructions — XNU Image Tools

## Project Overview

XNU Image Tools is a multi-platform image generation and fuzzing toolkit for Apple
platforms. It contains an iOS image generator, watchOS image generator, VideoToolbox
codec fuzzer, and the shared XNU Image Fuzzer component. Used for command-line iOS
fuzzing using macOS.

- **Languages**: Objective-C, C, Swift
- **Platforms**: iOS 17.2+, macOS 14+ (Mac Catalyst), watchOS 10.5+, visionOS 1.x
- **License**: GPL v3
- **Author**: David Hoyt (@xsscx / @h02332)

## Repository Structure

```
xnuimagetools.xcworkspace          # Xcode workspace (all sub-projects)
│
├── XNU Image Fuzzer/              # Shared iOS fuzzer (Mac Catalyst)
│   └── XNU Image Fuzzer/
│       ├── xnuimagefuzzer.m       # Core fuzzer — 12 bitmap contexts
│       ├── ViewController.m       # UICollectionView display
│       ├── AppDelegate.m          # App lifecycle
│       └── CMakeLists.txt         # Alternative CMake build
│
├── XNU Image Generator for iOS/   # SwiftUI image generator
│   └── cx.srd.imagegenerator-xnu-demo/
│       ├── ContentView.swift      # 12+ image generation functions
│       ├── ViewController.swift
│       └── cx_srd_imagegenerator_xnu_demoApp.swift
│
├── XNU Image Generator for Watch/ # watchOS image generator
│   └── cx.srd.watch.ultra2-001 Watch App/
│       ├── ContentView.swift      # Watch UI with image gallery
│       └── cx_srd_watch_ultra2_001App.swift
│
├── VideoToolbox/                  # VideoToolbox codec fuzzer
│   └── Fuzzing/
│       ├── Makefile               # Build orchestrator (macOS + iOS)
│       ├── videotoolbox-runner.m  # Main fuzzing harness (ObjC)
│       ├── videotoolbox-interposer.c  # DYLD function interposition
│       ├── runner.c               # macOS runner
│       ├── runner_dist.c          # Distributed runner
│       ├── interpose.c            # iOS interposer
│       └── big.mov                # Sample video input
│
├── contrib/scripts/               # Quality validation scripts
│   ├── validate_fuzzed_images.py  # Steganography / injection detection
│   ├── compare_image_directories.py  # MSE, SSIM, PSNR, entropy
│   ├── read-magic-numbers.py      # 40+ magic byte signatures
│   ├── generate_filmstrip.py      # Side-by-side comparisons
│   └── code_statistics_report.py  # LOC / complexity metrics
│
└── .github/
    ├── workflows/                 # 6 CI/CD workflows
    ├── scripts/sanitize-sed.sh    # Input sanitization for CI
    └── prompts/                   # Copilot prompt templates
```

## Build Commands

### 1. iOS Fuzzer (Mac Catalyst — runs natively on macOS)
```bash
xcodebuild build \
  -project "XNU Image Fuzzer/XNU Image Fuzzer.xcodeproj" \
  -scheme "XNU Image Fuzzer" \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug \
  -derivedDataPath /tmp/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

### 2. iOS Image Generator (Simulator)
```bash
xcodebuild build \
  -project "XNU Image Generator for iOS/cx.srd.imagegenerator-xnu-demo.xcodeproj" \
  -scheme "cx.srd.imagegenerator-xnu-demo" \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath /tmp/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES
```

### 3. VideoToolbox Fuzzer (macOS native clang)
```bash
cd VideoToolbox/Fuzzing
mkdir -p build

# Build interposer
xcrun -sdk macosx clang \
  -arch arm64 -g -O1 -Wall -Wextra \
  -dynamiclib \
  -framework IOKit -framework CoreFoundation \
  -framework CoreMedia -framework CoreVideo \
  -framework VideoToolbox -lz \
  -o build/videotoolbox-interposer.dylib \
  videotoolbox-interposer.c
codesign -s "-" --force build/videotoolbox-interposer.dylib

# Build runner
xcrun -sdk macosx clang \
  -arch arm64 -g -O1 -Wall -Wextra \
  -o build/videotoolbox-runner \
  videotoolbox-runner.m \
  build/videotoolbox-interposer.dylib \
  -framework VideoToolbox -framework Foundation \
  -framework AVFoundation -framework CoreFoundation \
  -framework CoreMedia -framework CoreVideo \
  -framework CoreImage -framework CoreGraphics -lz
codesign -s "-" --force build/videotoolbox-runner
```

### 4. VideoToolbox (instrumented — ASAN + UBSAN + Coverage)
```bash
SANITIZER_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -fno-optimize-sibling-calls"
COVERAGE_FLAGS="-fprofile-instr-generate -fcoverage-mapping"

xcrun -sdk macosx clang \
  -arch arm64 -g -O1 -Wall -Wextra \
  $SANITIZER_FLAGS $COVERAGE_FLAGS \
  -o build/videotoolbox-runner \
  videotoolbox-runner.m \
  build/videotoolbox-interposer.dylib \
  -framework VideoToolbox -framework Foundation \
  -framework AVFoundation -framework CoreFoundation \
  -framework CoreMedia -framework CoreVideo \
  -framework CoreImage -framework CoreGraphics -lz
```

### 5. VideoToolbox via Makefile
```bash
cd VideoToolbox/Fuzzing
make all      # Build all targets (macOS + iOS)
make clean    # Remove build artifacts
make test     # Run all tests
```

### 6. Running the VideoToolbox Fuzzer
```bash
# Basic run (60 second default)
./build/videotoolbox-runner big.mov

# Timed run with output directory
./build/videotoolbox-runner -t 120 -o /tmp/fuzzed-frames big.mov

# With interposition
DYLD_INSERT_LIBRARIES=./build/videotoolbox-interposer.dylib \
  ./build/videotoolbox-runner -t 60 big.mov

# With sanitizers + coverage
ASAN_OPTIONS="detect_leaks=0:halt_on_error=0" \
UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0" \
LLVM_PROFILE_FILE="/tmp/profraw/vt-%m_%p.profraw" \
  ./build/videotoolbox-runner -t 60 -o /tmp/fuzzed big.mov
```

## Architecture

### Sub-Project Relationships
```
xnuimagetools.xcworkspace
  ├── XNU Image Fuzzer ────────── Shared fuzzer component
  │     └── Mac Catalyst build → runs natively on macOS
  ├── XNU Image Generator iOS ── SwiftUI image creation
  │     └── Imports same 12 bitmap context patterns
  ├── XNU Image Generator Watch ─ watchOS companion
  │     └── Shares image generation logic
  └── VideoToolbox Fuzzer ─────── Standalone C/ObjC
        ├── videotoolbox-runner.m  (main harness)
        ├── videotoolbox-interposer.c (DYLD interposition)
        ├── runner.c / runner_dist.c (macOS process runners)
        └── interpose.c (iOS interposer)
```

### VideoToolbox Fuzzing Pipeline
```
main() → parse CLI args (-t, -o, -h)
  → open video file (AVAsset)
  → time-based loop:
      fuzz(filename, flip, inject, overflow)
        → AVAssetReader → read video tracks
        → decode frames → CVPixelBuffer
        → apply mutations (bit flips, injection, overflow)
        → save_fuzzed_frame() → PNG via CIContext
      → repeat until duration expires
  → report statistics
```

### VideoToolbox CLI Arguments
| Flag | Default | Description |
|------|---------|-------------|
| `-t <seconds>` | 60 | Fuzzing duration |
| `-o <dir>` | none | Output directory for fuzzed frames |
| `-h` | — | Show help |

### Required Frameworks (VideoToolbox targets)
| Framework | Purpose |
|-----------|---------|
| VideoToolbox | Codec operations |
| AVFoundation | Video file reading |
| CoreMedia | Media timing, sample buffers |
| CoreVideo | Pixel buffer access |
| CoreImage | CIContext for PNG export |
| CoreGraphics | Color space management |
| CoreFoundation | Core utilities |
| IOKit | Hardware capabilities (interposer) |

**IMPORTANT**: `videotoolbox-runner` MUST link `-framework CoreGraphics` because
`save_fuzzed_frame()` uses `CGColorSpaceCreateDeviceRGB` and `CGColorSpaceRelease`.

### Deprecation Notes
- `[AVAsset tracksWithMediaType:]` is deprecated in macOS 15.0
- Suppressed with `#pragma clang diagnostic ignored "-Wdeprecated-declarations"`
- Async replacement `loadTracksWithMediaType:completionHandler:` not suitable
  for synchronous fuzzer flow

## Coding Conventions

### Objective-C (xnuimagefuzzer.m, videotoolbox-runner.m)
- `#pragma mark -` sections for code organization
- ANSI color macros: `MAG`, `BLUE`, `RED`, `GRN`, `YEL`, `CYN`
- Guard all `CGContextRef` with NULL checks
- Always release Core Graphics objects in all code paths
- Use `@autoreleasepool` around loops with ObjC object creation
- Cast `CGImageAlphaInfo` → `CGBitmapInfo` explicitly

### C (runner.c, interposer.c)
- Check all `malloc()` returns
- Use `codesign -s "-" --force` for ad-hoc signing in CI
- Link all required frameworks explicitly (no implicit linking)

### Swift (ContentView.swift)
- SwiftUI patterns with `@State` properties
- Use `CGImage` and `UIImage` bridging for display
- Save via `CGImageDestination` API

### Build Flags
- `GCC_TREAT_WARNINGS_AS_ERRORS=YES` — all warnings are errors
- `-Wall -Wextra` for clang builds
- Always include `-framework CoreGraphics` for videotoolbox-runner

## CI/CD Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `code-quality.yml` | ObjC/Swift/Python linting | push/PR |
| `build-and-test.yml` | Build all, generate images, commit | push/PR, cron |
| `cached-build.yml` | Fast build with DerivedData cache | push/PR |
| `videotoolbox.yml` | VT build + analyze + fuzz + commit | push/PR, dispatch |
| `instrumented.yml` | ASAN+UBSAN+Coverage for VT + iOS | push/PR, dispatch |
| `release.yml` | Tag-triggered multi-project release | tag v* |

### CI Security Hardening
- All action SHAs pinned (no `@v4` tags)
- `persist-credentials: false` on all checkouts
- `BASH_ENV=/dev/null`, `bash --noprofile --norc`
- `permissions: contents: read` (least privilege)
- Concurrency groups with `cancel-in-progress: true`
- No user-controllable inputs in `run:` blocks
- Input sanitization via `.github/scripts/sanitize-sed.sh`

### Pinned Action SHAs
```yaml
actions/checkout: 11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
actions/upload-artifact: ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
actions/cache: 5a3ec84eff668545956fd18022155c47e93e2684  # v4.2.3
actions/download-artifact: d3f86a106a0bac45b974a628896c90dbdf5c8093  # v4.3.0
```

## Git Identity

Use bot identity for all commits — never personal info:
```bash
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
```

## Environment Variables

| Variable | Used By | Purpose |
|----------|---------|---------|
| `FUZZ_OUTPUT_DIR` | iOS Fuzzer | Override image output directory |
| `FUZZ_DURATION` | VT workflow | Fuzzing duration (dispatch input) |
| `LLVM_PROFILE_FILE` | All | Coverage profraw output path |
| `ASAN_OPTIONS` | All | AddressSanitizer configuration |
| `UBSAN_OPTIONS` | All | UBSanitizer configuration |
| `DYLD_INSERT_LIBRARIES` | VT runner | Load interposer dylib |
| `DEVELOPER_ID` | Makefile | Code signing identity |

## Platform Compatibility

| Platform | Status | Sub-Project |
|----------|--------|-------------|
| macOS 14+ arm64 | ✅ | Fuzzer (Mac Catalyst), VideoToolbox |
| macOS 15+ x86_64 | ✅ | Fuzzer (Rosetta 2), VideoToolbox |
| iOS 17+ | ✅ | Fuzzer, iOS Generator |
| iPadOS 17+ | ✅ | Fuzzer, iOS Generator |
| watchOS 10.5+ | ✅ | Watch Generator |
| visionOS 1.x | ✅ | Fuzzer, iOS Generator |

## Quality Validation Scripts

Located in `contrib/scripts/`:

### validate_fuzzed_images.py
Steganography analysis — checks LSB/MSB of pixel data for injected strings:
- Buffer overflow patterns, XSS, SQL injection, format strings, XXE, path traversal
- **Requires**: Pillow

### compare_image_directories.py
Cross-device image comparison with quantitative metrics:
- MSE, SSIM, PSNR, perceptual hash, entropy analysis
- **Requires**: opencv-python, scikit-image, imagehash, pillow-heif

### read-magic-numbers.py
File format validation with 40+ magic byte signatures and MIME type checking.
- **Requires**: Pillow, python-magic

### generate_filmstrip.py
Side-by-side comparison strips for visual review.
- **Requires**: Pillow

## Common Issues & Solutions

### Link error: undefined CGColorSpaceCreateDeviceRGB
Add `-framework CoreGraphics` to the clang build command. The `save_fuzzed_frame()`
function uses CoreGraphics color space APIs.

### Warning: tracksWithMediaType: deprecated
Suppressed with pragma. The async replacement is not compatible with the synchronous
fuzzer architecture.

### Build fails: -Wenum-conversion
Cast `CGImageAlphaInfo` to `CGBitmapInfo`:
```objc
CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
```

### No coverage data collected
Ensure `LLVM_PROFILE_FILE` is set BEFORE running the binary.
For VideoToolbox: set it in the same shell as the runner execution.

### Makefile: missing targets
The Makefile builds both macOS and iOS targets. iOS targets require the iphoneos SDK
and arm64e architecture. Skip iOS targets in CI (no device available).
