---
name: VideoToolbox Fuzzing
description: Build and run the VideoToolbox fuzzer with sanitizers and coverage
---

# VideoToolbox Fuzzing

Build the VideoToolbox fuzzer with ASAN+UBSAN+coverage, run it against video
files, and collect results.

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
     -framework CoreImage -framework CoreGraphics -lz
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
- `videotoolbox-interposer.c` — DYLD interposition hooks
- `runner.c` — Process attachment runner
- `Makefile` — Full build system (macOS + iOS targets)

## Critical Notes
- **Always link `-framework CoreGraphics`** for videotoolbox-runner
- Ad-hoc codesign required: `codesign -s "-" --force`
- `tracksWithMediaType:` deprecation is suppressed with pragma
- The `-t` flag controls duration (default 60s), `-o` controls output dir
