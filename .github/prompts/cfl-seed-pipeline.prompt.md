---
name: CFL Seed Pipeline
description: Extract ICC profiles and TIFF files from xnuimagetools output and inject into CFL fuzzer corpora
---

# CFL Fuzzer Seed Pipeline

Bridge xnuimagetools fuzzed image output into CFL LibFuzzer seed corpora for the
research repo's 18 ICC profile fuzzers. Extracts embedded ICC profiles and copies
TIFF files across hardware-diverse image outputs.

## Prerequisites

- xnuimagetools output in `fuzzed-images/` (from macOS/iOS/watchOS runs)
- CFL fuzzers built at `../cfl/` in this workspace (or another explicit sibling path)
- Python 3.8+

## Phase 1: Generate ICC-Rich Images

With ICC variant generation (commit 5865137), every TIFF/PNG save automatically
produces up to 4 ICC variants — stripped, mismatched, real ICC, and mutated ICC.
Setting `FUZZ_ICC_DIR` unlocks all 4 strategies:

```bash
# Full ICC diversity — generates all 4 variant types per TIFF/PNG save
BINARY=/tmp/native-build/xnuimagetools
TEST_PROFILES=../test-profiles

FUZZ_ICC_DIR="$TEST_PROFILES" \
FUZZ_OUTPUT_DIR=/tmp/icc-rich-output \
  "$BINARY"

# Without FUZZ_ICC_DIR — still generates stripped + mismatched variants
# (real ICC and mutated ICC require FUZZ_ICC_DIR)
FUZZ_OUTPUT_DIR=/tmp/basic-output "$BINARY"
```

### ICC Variant Output Per Save

| Variant | Filename Pattern | Requires FUZZ_ICC_DIR |
|---------|-----------------|----------------------|
| Real ICC | `fuzzed_image_<ctx>_icc_<name>.<ext>` | Yes |
| Mutated ICC | `fuzzed_image_<ctx>_icc_mutated.<ext>` | Yes |
| Stripped | `fuzzed_image_<ctx>_no_icc.<ext>` | No |
| Mismatched | `fuzzed_image_<ctx>_icc_mismatch.<ext>` | No |

### encodeImageMultiFormat Variants

Additionally, `encodeImageMultiFormat()` produces:
- `tiff-no-icc.tiff` / `png-no-icc.png`
- `tiff-icc-mismatch.tiff` / `png-icc-mismatch.png`
- `tiff-cs0.tiff` through `tiff-cs6.tiff` (7 named Apple color spaces)

### ICC Profile Sources (Priority Order)

1. `../test-profiles/` — curated ICC profiles for testing (highest diversity)
2. `../extended-test-profiles/` — additional profiles including edge cases
3. `/System/Library/ColorSync/Profiles/` — macOS system profiles (sRGB, Display P3, etc.)
4. `/Library/ColorSync/Profiles/` — user-installed profiles

### Most Valuable Bitmap Contexts for ICC

| Context | Why |
|---------|-----|
| HDRFloatComponents | ExtendedLinearSRGB auto-embeds ICC; exercises wide-gamut paths |
| HDRFloat16 | Half-precision floats + ICC = edge case coverage in color transforms |
| CMYK | CMYK ICC profiles rarely fuzzed; exercises device-link paths |
| 16BitDepth | 16bpc + ICC exercises depth conversion in CMM pipeline |
| 32BitFloat4Component | 128-bit float + ICC exercises range clamping |

## Phase 2: Extract and Inject Seeds

```bash
# Extract ICC profiles + TIFF files from ALL fuzzed-images runs
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ \
  --inject-cfl ../cfl

# Extract from a specific device run (e.g., iPhone vs iPad comparison)
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/2026-03-03-030143/ \
  --output /tmp/device-seeds

# Extract to staging directory first (for inspection before injection)
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ \
  --output /tmp/extracted-seeds
ls /tmp/extracted-seeds/icc/    # ICC profiles
ls /tmp/extracted-seeds/tiff/   # TIFF files
cat /tmp/extracted-seeds/manifest.json  # Extraction metadata
```

### What Gets Extracted Where

| Source | Staging | CFL Target |
|--------|---------|------------|
| iOS Generator images | `fuzz/xnuimagegenerator/{format}/` | ICC → profile/dump/toxml fuzzers |
| Fuzzed images | `fuzz/xnuimagefuzzer/{format}/` | TIFF → tiffdump/specsep fuzzers |
| Chained/pipeline outputs | `fuzz/xnuimagefuzzer/chained/` or `pipeline/` | Multi-pass mutations |
| Extracted ICC profiles | `fuzz/xnuimagegenerator/icc/` or `fuzz/xnuimagefuzzer/icc/` | All ICC fuzzers |

### Collision-Free Filenames (v1.9.0+)

Both tools use SHA-256 hash suffixes to prevent collisions across runs:
- iOS Generator: `xig-{context}-{WxH}[-icc_{profile}]-{hash6}.{ext}`
- Fuzzer: `xif-{source}-perm{N}[-{variant}]-{hash6}.{ext}`

## Phase 3: Validate Coverage

### Profile Class Coverage Audit
Before running fuzzers, verify all 7 ICC classes are seeded. Printer profiles were
entirely missing from all CFL corpora until March 2026 — a major blind spot for
LUT, gamut mapping, and CMYK code paths.

| Source Format | Extraction Method | Target CFL Fuzzers |
|--------------|-------------------|-------------------|
| TIFF with ICC (tag 34675) | IFD tag extraction | profile, dump, deep_dump, toxml |
| PNG with ICC (iCCP chunk) | Chunk parsing | profile, dump, deep_dump, toxml |
| JPEG with ICC (APP2 marker) | APP2 reassembly | profile, dump, deep_dump, toxml |
| TIFF files (any) | Direct copy | tiffdump, specsep |

### Deduplication

The script deduplicates by SHA256 hash (12-char prefix). Running it multiple times
on the same images will not create duplicates.

## Phase 3: Verify Coverage Gain

After injecting seeds, run a quick smoke test on the target fuzzers:

```bash
CFL_DIR=../cfl

# Verify profile fuzzer gained edges
ASAN_OPTIONS=detect_leaks=0 LLVM_PROFILE_FILE=/dev/null \
  "$CFL_DIR/bin/icc_profile_fuzzer" -max_total_time=30 "$CFL_DIR/corpus-icc_profile_fuzzer/" \
  2>&1 | grep "INITED\|DONE"

# Verify tiffdump fuzzer gained edges
ASAN_OPTIONS=detect_leaks=0 LLVM_PROFILE_FILE=/dev/null \
  "$CFL_DIR/bin/icc_tiffdump_fuzzer" -max_total_time=30 "$CFL_DIR/corpus-icc_tiffdump_fuzzer/" \
  2>&1 | grep "INITED\|DONE"
```

Compare "cov:" values before and after seed injection.

## Phase 4: Feed Into macOS System Tools

Run the fuzzed images through macOS system parsers to find crashes:

```bash
# Test all fuzzed images against sips, qlmanage, mdimport, tiffutil
LATEST_RUN=$(ls -1dt fuzzed-images/*/ | sed -n '1p')
./fuzz-apps.sh "$LATEST_RUN" --timeout 15

# Stage CFL crash artifacts in a directory, then test them
CRASH_DIR=/tmp/cfl-crashes
./fuzz-apps.sh "$CRASH_DIR" --timeout 15 --report /tmp/cfl-crash-report
```

## Cross-Device Seed Diversity

Different Apple hardware produces different image characteristics:

| Device | Unique Value |
|--------|-------------|
| iPhone 16 Pro | ProRAW DNG, 48MP, always-on display color profile |
| iPad Pro M4 | Wide color (P3), ProMotion timing artifacts |
| Apple Watch Ultra 2 | Always-On display, small resolution edge cases |
| Mac Studio M2 Ultra | Maximum bitmap sizes, GPU Metal path |
| Vision Pro | Spatial photo metadata, wide-gamut stereoscopic |

Run xnuimagetools on each device and extract seeds separately to maximize diversity:
```bash
# Per-device extraction
for run in fuzzed-images/2026-03-*; do
  python3 contrib/scripts/extract-icc-seeds.py --input "$run" --inject-cfl ../cfl
done
```

## Maintenance

### After Adding New Bitmap Contexts
1. Update `MAX_PERMUTATION` constant in xnuimagefuzzer.m
2. Add context function following existing pattern
3. Run pipeline to generate new seeds
4. Extract and inject into CFL corpora

### After CFL Fuzzer Corpus Merge
After an extended fuzzing campaign with `ramdisk-merge.sh`, the minimized corpus
may have dropped xnuimagetools-derived seeds. Re-run the extraction pipeline to
re-inject them:
```bash
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ --inject-cfl ../cfl
```

### Profraw Note
When collecting coverage data, ensure profraw filenames include the fuzzer name:
```bash
LLVM_PROFILE_FILE=$RAMDISK/profraw/${fuzzer_name}_%m_%p.profraw
```
After rebuilding fuzzers, ALL old profraw is invalid (binary hash changes).
