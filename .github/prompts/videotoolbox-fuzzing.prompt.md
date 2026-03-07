---
name: VideoToolbox Fuzzing
description: Build and run the VideoToolbox fuzzer with sanitizers and coverage
---

# VideoToolbox Fuzzing

Build the VideoToolbox fuzzer with ASAN+UBSAN+coverage, run it against video
files, and collect results.

## Architecture

- **`videotoolbox-runner.m`** (Obj-C) — Opens video via AVFoundation, extracts
  CVPixelBuffer frames from CMSampleBuffer, applies bit-flip/inject/overflow
  mutations, saves fuzzed frames as PNG via ImageIO
- **`videotoolbox-interposer.c`** (C) — DYLD interposition library that replaces
  `IOConnectCallMethod` to fuzz IOKit inputs. Also creates VTCompressionSession
  for H.264 encoding of fuzzed pixel buffers
- **`runner.c`** — iOS binary launcher that patches `_amfi_check_dyld_policy_self`
- **`videotoolbox_build.mk`** — Shared build config; `DEVELOPER_ID ?= "-"` (ad-hoc default)

## Build Steps

1. **Build the interposer** (dependency for the runner):
   ```bash
   cd VideoToolbox/Fuzzing && mkdir -p build
   xcrun -sdk macosx clang \
     -arch arm64 -g -O1 -Wall -Wextra \
     -fsanitize=address,undefined -fno-omit-frame-pointer \
     -fprofile-instr-generate -fcoverage-mapping \
     -dynamiclib \
     -framework IOKit -framework CoreFoundation \
     -framework CoreMedia -framework CoreVideo \
     -framework VideoToolbox -lz \
     -o build/videotoolbox-interposer.dylib \
     videotoolbox-interposer.c
   codesign -s "-" --force build/videotoolbox-interposer.dylib
   ```

2. **Build the runner**:
   ```bash
   xcrun -sdk macosx clang \
     -arch arm64 -g -O1 -Wall -Wextra \
     -fsanitize=address,undefined -fno-omit-frame-pointer \
     -fprofile-instr-generate -fcoverage-mapping \
     -o build/videotoolbox-runner \
     videotoolbox-runner.m \
     build/videotoolbox-interposer.dylib \
     -framework VideoToolbox -framework Foundation \
     -framework AVFoundation -framework CoreFoundation \
     -framework CoreMedia -framework CoreVideo \
     -framework CoreImage -framework CoreGraphics \
     -framework ImageIO -framework UniformTypeIdentifiers -lz
   codesign -s "-" --force build/videotoolbox-runner
   ```

3. **Build runner + runner_dist** (C binaries):
   ```bash
   clang -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
     -O1 -Wall -Wextra -g \
     -fsanitize=address,undefined -fno-omit-frame-pointer \
     -fprofile-instr-generate -fcoverage-mapping \
     -o build/runner runner.c
   codesign -s "-" --force build/runner

   clang -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
     -O1 -Wall -Wextra -g \
     -fsanitize=address,undefined -fno-omit-frame-pointer \
     -fprofile-instr-generate -fcoverage-mapping \
     -o build/runner_dist runner_dist.c
   codesign -s "-" --force build/runner_dist
   ```

## Running

```bash
# Quick 60-second fuzz
ASAN_OPTIONS="detect_leaks=0:halt_on_error=0" \
UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0" \
LLVM_PROFILE_FILE="/tmp/profraw/vt-%m_%p.profraw" \
  build/videotoolbox-runner -t 60 -o /tmp/fuzzed-frames big.mov

# Extended run (10 minutes)
build/videotoolbox-runner -t 600 -o /tmp/fuzzed-frames big.mov

# With DYLD interposition
DYLD_INSERT_LIBRARIES=./build/videotoolbox-interposer.dylib \
  build/videotoolbox-runner -t 60 big.mov
```

## Coverage Report

```bash
xcrun llvm-profdata merge -sparse /tmp/profraw/*.profraw -o merged.profdata
xcrun llvm-cov report build/videotoolbox-runner -instr-profile=merged.profdata
xcrun llvm-cov show build/videotoolbox-runner -instr-profile=merged.profdata \
  -format=html -output-dir=coverage-html/
```

## Output Validation

Fuzzed frames are saved as PNG files. Validate with:
```bash
for f in /tmp/fuzzed-frames/*.png; do
  sips -g format -g pixelWidth -g pixelHeight "$f"
done
```

## Key Files
- `videotoolbox-runner.m` — Main harness: `fuzz()`, `save_fuzzed_frame()`, `main()`
- `videotoolbox-interposer.c` — DYLD interposition hooks for IOConnectCallMethod
- `runner.c` — Process attachment runner (iOS AMFI bypass)
- `Makefile` — Full build system (macOS + iOS targets)
- `videotoolbox_build.mk` — Shared config (DEVELOPER_ID, SDK flags)
- `big.mov` — 20MB default fuzz input (committed to git, not LFS)

## Known Gotchas

- **ASAN + `malloc_zone_print()`** — The interposer hot loop calls `malloc_zone_print()`,
  which under ASAN causes multi-minute hangs. The coverage job omits ASAN for this reason.
- **`signal()` → `sigaction()`** — Signal handler must be async-signal-safe.
  Do NOT call `malloc_zone_print()`, `log_memory_info()`, or `malloc_printf()` from handlers.
- **`rand()` is deterministic** — Always use `arc4random_uniform()` for mutations.
  `rand()` without `srand()` produces identical sequences every run.
- **CVPixelBuffer size** — `process_with_videotoolbox()` hardcodes 640×480 (1,228,800 bytes).
  Always validate `len >= 4*width*height` before `CVPixelBufferCreateWithBytes`.
- **`free_with_guard` sizing** — Guard page math uses the original `compressBound()` size,
  NOT the post-compression `compressed_len` (which is smaller after `compress_data()`).
- **macOS CI has no `timeout`** — Use `perl -e 'alarm shift; exec @ARGV'` as portable alternative.
- **`tracksWithMediaType:` deprecation** — Suppressed with pragma in videotoolbox-runner.m.

## CI Workflows

- **`videotoolbox.yml`** — 4 jobs: build-macos, coverage (UBSAN only, no ASAN),
  static-analysis, fuzz-and-commit. Triggers on `VideoToolbox/**` path changes.
- **`instrumented.yml`** — 3 jobs with macOS 14/15 matrix: ios-instrumented (Mac Catalyst),
  macos-native (clang ASAN+UBSAN), native-coverage. Triggers on `**/*.m` etc.
