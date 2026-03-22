# VideoToolbox Fuzzer — Path-Specific Instructions

## What This Is

A video frame mutation fuzzer targeting Apple's VideoToolbox hardware decoding
pipeline. Extracts frames via AVFoundation, applies byte-level mutations
(bit-flip, injection, overflow), and encodes fuzzed frames through
VTCompressionSession. Includes DYLD interposition to fuzz IOKit inputs.

## Build

```bash
cd VideoToolbox/Fuzzing && make    # builds interposer + runner + runner_dist
```

- Compiler: `xcrun -sdk macosx clang` (arm64)
- Sanitizers: `-fsanitize=address,undefined` for instrumented builds
- Coverage: `-fprofile-instr-generate -fcoverage-mapping`
- Ad-hoc signing required: `codesign -s "-" --force`
- `DEVELOPER_ID ?= "-"` in `videotoolbox_build.mk` (override for distribution signing)

## Architecture — 3 Components

| Component | File | Language | Purpose |
|-----------|------|----------|---------|
| Runner | `videotoolbox-runner.m` | Obj-C | Frame extraction, mutation, PNG output |
| Interposer | `videotoolbox-interposer.c` | C | DYLD `IOConnectCallMethod` replacement |
| Launcher | `runner.c` | C | iOS AMFI bypass for process attachment |

### Runner Flow
1. `main()` → parse args (`-t` duration, `-o` output dir, positional video file)
2. `fuzz()` → AVAsset → AVAssetReader → CMSampleBuffer → CVPixelBuffer
3. Mutate pixel data (bit-flip, random injection, overflow patterns)
4. `save_fuzzed_frame()` → CGImage → ImageIO → PNG

### Interposer Flow
1. DYLD loads `videotoolbox-interposer.dylib` via `DYLD_INSERT_LIBRARIES`
2. `fake_IOConnectCallMethod()` replaces real IOKit calls
3. `process_with_videotoolbox()` creates VTCompressionSession for H.264 encoding
4. `compression_fuzz()` compresses mutated buffers with guard-page-protected allocations

## Key Functions

| Function | File | Purpose |
|----------|------|---------|
| `fuzz()` | `videotoolbox-runner.m` | Main fuzzing loop — extracts and mutates frames |
| `save_fuzzed_frame()` | `videotoolbox-runner.m` | CVPixelBuffer → PNG via ImageIO |
| `flip_bits()` | `videotoolbox-interposer.c` | `arc4random_uniform()` bit mutations |
| `inject_random_data()` | `videotoolbox-interposer.c` | Random byte injection into buffers |
| `process_with_videotoolbox()` | `videotoolbox-interposer.c` | VTCompressionSession encoding |
| `compression_fuzz()` | `videotoolbox-interposer.c` | Guard-page-protected compression |
| `free_with_guard()` | `videotoolbox-interposer.c` | Frees guard-page allocations (uses original alloc size) |

## Critical Patterns — Must Follow

### Mutation Functions
- **Always use `arc4random_uniform()`** — never `rand()`. Without `srand()`, `rand()`
  produces identical sequences every run, defeating the purpose of fuzzing.

### Buffer Validation
- **Validate `len >= 4*width*height`** before `CVPixelBufferCreateWithBytes`.
  The hardcoded 640×480 expects 1,228,800 bytes minimum (BGRA = 4 bytes/pixel).

### Memory Management
- **`free_with_guard(ptr, size)`** — The `size` parameter must be the ORIGINAL
  allocation size from `compressBound()`, NOT the post-compression `compressed_len`.
  Guard page math: `mmap` allocates `size + PAGE_SIZE`, returns `base + PAGE_SIZE`.
  `munmap` needs `base = ptr - PAGE_SIZE`, `total = size + PAGE_SIZE`.

### Signal Handling
- **Use `sigaction()`, not `signal()`** — POSIX-compliant, no race conditions.
- **Signal handlers must be async-signal-safe** — only `write()`, `_exit()`, `signal()`.
  NEVER call `malloc_zone_print()`, `log_memory_info()`, `malloc_printf()`,
  `fprintf()`, or `NSLog()` from a signal handler.

### Argument Parsing
- `main()` uses `getopt()` — the positional video filename is `argv[optind]`,
  stored in `filename`. Do NOT use `argv[1]` after options are parsed.

### VTCompressionSession
- Initialize `VTCompressionSessionRef session = NULL` before use.
- Always check return status of `VTCompressionSessionCreate()`.
- `VTCompressionSessionCompleteFrames()` + `VTCompressionSessionInvalidate()`
  before `CFRelease(session)`.

## ASAN Compatibility

- **Coverage job omits ASAN** because `malloc_zone_print()` in the interposer
  hot loop causes multi-minute hangs under ASAN instrumentation.
- UBSAN remains enabled in all instrumented builds.
- `ASAN_OPTIONS=detect_leaks=0` required (macOS leak detection is noisy).

## CI Workflows

- **`videotoolbox.yml`** — 4 jobs: build-macos, coverage (UBSAN only),
  static-analysis, fuzz-and-commit. Triggers on `VideoToolbox/**` paths.
- **`instrumented.yml`** — 3 jobs with macOS 14/15 matrix: ios-instrumented,
  macos-native, native-coverage. Triggers on all `**/*.m` etc.

## Test Input

- `big.mov` — 20MB QuickTime file committed directly to git (not LFS)
- Both CI workflows validate it exists and is non-empty before fuzzer runs

## macOS CI Notes

- No GNU `timeout` command — use `perl -e 'alarm shift; exec @ARGV'`
- `tracksWithMediaType:` deprecation suppressed with `#pragma clang diagnostic`
- `-framework ImageIO -framework UniformTypeIdentifiers` required for runner link
