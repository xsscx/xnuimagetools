# Build & CI — XNU Image Tools

## Build Commands

### Xcode (primary — Mac Catalyst)
```bash
xcodebuild build \
  -project "XNU Image Fuzzer/XNU Image Fuzzer.xcodeproj" \
  -scheme "XNU Image Fuzzer" \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug \
  -derivedDataPath /tmp/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

### Xcode (ASAN + UBSAN — sanitizer testing only)
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
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  CLANG_ADDRESS_SANITIZER=YES \
  CLANG_UNDEFINED_BEHAVIOR_SANITIZER=YES \
  OTHER_CFLAGS='$(inherited) -fno-omit-frame-pointer'
```

> **⚠️ Do NOT add `CLANG_ENABLE_CODE_COVERAGE=YES` to xcodebuild Mac Catalyst builds.**
> Xcode does NOT inject `-fprofile-instr-generate -fcoverage-mapping` for Mac Catalyst.
> Use the native clang build below for coverage.

### Native clang (ASAN + UBSAN + Coverage — recommended)
```bash
# Use the build script:
.github/scripts/build-native.sh           # full pipeline: build + run + coverage
.github/scripts/build-native.sh --build-only  # compile only
.github/scripts/build-native.sh --run-only    # run existing binary

# Or build manually:
clang -arch arm64 -target arm64-apple-ios17.2-macabi \
  -isysroot $(xcrun --show-sdk-path) \
  -iframework $(xcrun --show-sdk-path)/System/iOSSupport/System/Library/Frameworks \
  -fobjc-arc -g -O0 -fno-omit-frame-pointer \
  -fsanitize=address,undefined \
  -fprofile-instr-generate -fcoverage-mapping \
  -framework Foundation -framework UIKit -framework CoreGraphics \
  -framework ImageIO -framework UniformTypeIdentifiers \
  -I"XNU Image Fuzzer/XNU Image Fuzzer" \
  "XNU Image Fuzzer/XNU Image Fuzzer"/*.m -o /tmp/xnuimagetools
```

### CMake (alternative)
```bash
mkdir xcode_build && cd xcode_build
cmake -G Xcode ../XNU\ Image\ Fuzzer/CMakeLists.txt
cmake --build . --config Debug
```

### Running the built binary
```bash
BINARY=$(find /tmp/DerivedData -name "XNU Image Fuzzer" -type f -perm +111 \
  ! -path "*/Contents/Resources/*" | sed -n '1p')

FUZZ_OUTPUT_DIR=/tmp/fuzzed-output \
ASAN_OPTIONS="detect_leaks=0:halt_on_error=0" \
UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0" \
LLVM_PROFILE_FILE="/tmp/profraw/fuzzer-%m_%p.profraw" \
  timeout 120 "$BINARY"
```

## CI/CD Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `code-quality.yml` | ObjC syntax, Python lint, CMake check | push/PR |
| `build-and-test.yml` | Build, generate images, commit output | push/PR, cron 12h |
| `cached-build.yml` | Fast build with DerivedData cache | push/PR |
| `instrumented.yml` | ASAN+UBSAN testing + native build + coverage (macOS 14/15 matrix) | push/PR, dispatch |
| `videotoolbox.yml` | VideoToolbox fuzzer build, coverage, static analysis, fuzz | push/PR on VideoToolbox/** |
| `release.yml` | Tag-triggered release with artifacts | tag v* |
| `codeql-analysis.yml` | GitHub CodeQL security scanning | push/PR |

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

### CI Pipeline: build-and-test.yml (8 Jobs)

```
build-ios (Job 1)
  ├→ generate-images (Job 2)          — iOS Simulator fuzzed images (4-device matrix)
  ├→ generate-catalyst-images (Job 3) — Mac Catalyst + FUZZ_ICC_DIR (all 4 ICC variants)
  ├→ generate-ios-gen-images (Job 5)  — iOS Generator images
  └→ build-watch (Job 6)             — watchOS images
       │
       ▼
  commit-images (Job 7)  — collects all sources into fuzzed-images/<timestamp>/
  extract-seeds (Job 8)  — runs extract-icc-seeds.py → uploads cfl-seeds artifact (30-day)
```

**Mac Catalyst job** (`generate-catalyst-images`):
- Builds with `platform=macOS,variant=Mac Catalyst` destination
- Runs binary directly (`$APP_PATH/Contents/MacOS/XNU Image Fuzzer`) — no simulator
- Sets `FUZZ_ICC_DIR=/System/Library/ColorSync/Profiles` for system ICC profiles
- Enables all 4 ICC variants: real, mutated, stripped, mismatched

## Coding Conventions

### Objective-C Style
- Use `#pragma mark -` sections for code organization
- ANSI color macros for console output: `MAG`, `BLUE`, `RED`, `GRN`, `YEL`, `CYN`
- Guard all `CGContextRef` with NULL checks before use
- Always `CGContextRelease()` and `free()` bitmap data in error paths
- Use `os_log` and `os_signpost` for structured logging

### Memory Management
- Manual retain/release patterns in Core Graphics code
- `@autoreleasepool` blocks around image generation loops
- Always pair `CGColorSpaceCreate*` with `CGColorSpaceRelease`
- Always pair `CGContextRef` creation with release in all code paths
- Check `malloc()` return values — never assume success

### CGBitmapInfo Correctness
- Always cast `CGImageAlphaInfo` to `CGBitmapInfo`: `(CGBitmapInfo)kCGImageAlphaPremultipliedLast`
- Combine with byte order using `|`: `(CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big`
- Never pass raw `kCGImageAlpha*` constants where `CGBitmapInfo` is expected

### Build Flags
- `GCC_TREAT_WARNINGS_AS_ERRORS=YES` — all warnings are errors
- `-Wall -Wextra` for clang builds
- `-Werror=macro-redefined` will catch duplicate `#define` issues

## Git Identity

Use bot identity for all commits — never personal info:
```bash
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
```
