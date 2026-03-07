---
name: CFL Seed Pipeline
description: Extract ICC profiles and TIFF files from xnuimagetools output and inject into CFL fuzzer corpora
---

# CFL Fuzzer Seed Pipeline

Bridge xnuimagetools fuzzed image output into CFL LibFuzzer seed corpora for the
research repo's 19 ICC profile fuzzers. Extracts embedded ICC profiles and copies
TIFF files across hardware-diverse image outputs.

## Prerequisites

- xnuimagetools output in `fuzzed-images/` (from macOS/iOS/watchOS runs)
- CFL fuzzers built at `../research/cfl/` (or wherever the research repo lives)
- Python 3.8+

## Phase 1: Generate ICC-Rich Images

By default, most xnuimagetools images do NOT embed ICC profiles — they use named
color spaces (DeviceRGB, DeviceGray). To maximize ICC diversity:

```bash
# Set FUZZ_ICC_DIR to a library of ICC profiles before running the fuzzer
FUZZ_ICC_DIR=../research/test-profiles \
FUZZ_OUTPUT_DIR=/tmp/icc-rich-output \
  ./XNU\ Image\ Fuzzer

# This round-robins through the profiles and embeds them into every generated image.
# With 15 bitmap contexts × N ICC profiles × 6 formats, this generates thousands
# of images with diverse ICC profile + pixel format combinations.
```

### ICC Profile Sources (Priority Order)

1. `../research/test-profiles/` — curated ICC profiles for testing (highest diversity)
2. `../research/extended-test-profiles/` — additional profiles including edge cases
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
  --inject-cfl ../research/cfl

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
cd ../research

# Verify profile fuzzer gained edges
ASAN_OPTIONS=detect_leaks=0 LLVM_PROFILE_FILE=/dev/null \
  cfl/bin/icc_profile_fuzzer -max_total_time=30 cfl/corpus-icc_profile_fuzzer/ \
  2>&1 | grep "INITED\|DONE"

# Verify tiffdump fuzzer gained edges
ASAN_OPTIONS=detect_leaks=0 LLVM_PROFILE_FILE=/dev/null \
  cfl/bin/icc_tiffdump_fuzzer -max_total_time=30 cfl/corpus-icc_tiffdump_fuzzer/ \
  2>&1 | grep "INITED\|DONE"
```

Compare "cov:" values before and after seed injection.

## Phase 4: Feed Into macOS System Tools

Run the fuzzed images through macOS system parsers to find crashes:

```bash
# Test all fuzzed images against sips, qlmanage, mdimport, tiffutil
./fuzz-apps.sh fuzzed-images/latest/ --timeout 15

# Test CFL crash artifacts against macOS parsers
./fuzz-apps.sh ../research/crash-* --timeout 15 --report /tmp/cfl-crash-report
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
  python3 contrib/scripts/extract-icc-seeds.py --input "$run" --inject-cfl ../research/cfl
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
  --input fuzzed-images/ --inject-cfl ../research/cfl
```

### Profraw Note
When collecting coverage data, ensure profraw filenames include the fuzzer name:
```bash
LLVM_PROFILE_FILE=$RAMDISK/profraw/${fuzzer_name}_%m_%p.profraw
```
After rebuilding fuzzers, ALL old profraw is invalid (binary hash changes).
