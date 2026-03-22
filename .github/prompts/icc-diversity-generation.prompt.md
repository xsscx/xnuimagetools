---
name: ICC Diversity Generation
description: Generate ICC-diverse image seeds from xnuimagetools for CFL fuzzer corpus enrichment
---

# ICC Diversity Generation Workflow

## Goal

Generate images with maximum ICC profile diversity to improve CFL fuzzer coverage,
especially for `icc_profile_fuzzer`, `icc_toxml_fuzzer`, `icc_tiffdump_fuzzer`, and
`icc_deep_dump_fuzzer`.

## Prerequisites

- xnuimagetools built (Mac Catalyst or native clang)
- ICC profile collection (e.g., `../test-profiles/`)
- CFL fuzzers built (`cd cfl && ./build.sh`)

## Step 1 — Generate ICC-Rich Output

```bash
# Set FUZZ_ICC_DIR to enable real ICC + mutated ICC variants
# Set FUZZ_OUTPUT_DIR for output collection
BINARY=/tmp/native-build/xnuimagetools
TEST_PROFILES=../test-profiles

FUZZ_ICC_DIR="$TEST_PROFILES" \
FUZZ_OUTPUT_DIR=/tmp/icc-diverse-output \
  "$BINARY"
```

### Expected Output Per TIFF/PNG Save

For each bitmap context TIFF/PNG output, `saveFuzzedImageWithICCVariants()` generates:
- `fuzzed_image_<ctx>_icc_<profilename>.<ext>` — real ICC profile embedded
- `fuzzed_image_<ctx>_icc_mutated.<ext>` — mutated ICC profile (6 corruption strategies)
- `fuzzed_image_<ctx>_no_icc.<ext>` — stripped color space (DeviceRGB only)
- `fuzzed_image_<ctx>_icc_mismatch.<ext>` — mismatched profile (cycles through 4 strategies)

### `encodeImageMultiFormat()` Also Produces

- `tiff-no-icc.tiff` / `png-no-icc.png` — stripped color space
- `tiff-icc-mismatch.tiff` / `png-icc-mismatch.png` — mismatched profiles
- `tiff-cs0.tiff` through `tiff-cs6.tiff` — 7 named Apple color spaces

## Step 2 — Extract Seeds for CFL

```bash
# Extract ICC profiles and TIFF files from the output
python3 contrib/scripts/extract-icc-seeds.py \
  --input /tmp/icc-diverse-output \
  --inject-cfl ../cfl

# Or stage to fuzz/ corpus first (organized by format)
cp /tmp/icc-diverse-output/*.tiff ../fuzz/xnuimagegenerator/tiff/
cp /tmp/icc-diverse-output/*.png ../fuzz/xnuimagegenerator/png/
# Extract embedded ICC profiles
python3 contrib/scripts/extract-icc-seeds.py \
  --input /tmp/icc-diverse-output \
  --output ../fuzz/xnuimagegenerator/icc/

# Verify injection
for dir in ../cfl/corpus-icc_*_fuzzer/; do
  echo "$(basename $dir): $(ls -1 "$dir" | wc -l) files"
done
```

### iOS Image Generator v1.9.0+ Output

The iOS generator produces images with collision-free filenames:
```
xig-{context}-{WxH}[-icc_{profile}]-{hash6}.{ext}
```
Stage to `fuzz/xnuimagegenerator/{format}/` then extract ICC profiles to
`fuzz/xnuimagegenerator/icc/` before injecting into CFL corpora.

Three unique ICC profiles extracted from iOS (March 2026):
| Profile | TRC Type | Gamut | Fuzzer Value |
|---------|----------|-------|-------------|
| sRGB IEC61966-2.1 (3KB) | curv 1024-sample | 100% | Shared TRC offsets, 17 tags |
| Display P3 (536B) | para type 3 | 128% | Negative XYZ, chad tag, v4.0 |
| Adobe RGB (560B) | curv γ=2.2 | 131% | Single gamma, wide green |

## Step 3 — Validate Coverage Improvement

```bash
# Run short fuzz sessions to check coverage
CFL_DIR=../cfl
RESEARCH_ROOT=..
for fuzzer in icc_profile_fuzzer icc_toxml_fuzzer icc_tiffdump_fuzzer; do
  LLVM_PROFILE_FILE=/tmp/profraw/${fuzzer}_%m_%p.profraw \
  ASAN_OPTIONS=detect_leaks=0 \
    "$CFL_DIR/bin/${fuzzer}" -max_total_time=60 -timeout=30 -rss_limit_mb=4096 \
    "$CFL_DIR/corpus-${fuzzer}/" 2>&1 | tail -3
done

# Generate coverage report
"$RESEARCH_ROOT/.github/scripts/merge-profdata.sh"
"$RESEARCH_ROOT/.github/scripts/generate-coverage-report.sh"
```

## Step 4 — Maximize Profile Diversity

### Source Profiles to Include in FUZZ_ICC_DIR

For maximum coverage, collect profiles from multiple sources:

```
test-profiles/              # ICC test profiles from research repo
/System/Library/ColorSync/Profiles/  # macOS system profiles
/Library/ColorSync/Profiles/         # User-installed profiles
```

### High-Value Profile Types

| Profile Type | Why Valuable | CFL Target |
|-------------|-------------|------------|
| v2 RGB Display | Tests v2 parsing paths | icc_profile_fuzzer |
| v4 CMYK Output | Tests CMYK + A2B/B2A LUTs | icc_apply_fuzzer |
| v5 Spectral | Tests MPE calculator | icc_spectral_fuzzer |
| Abstract | Tests Lab↔Lab transforms | icc_link_fuzzer |
| DeviceLink | Tests multi-profile chains | icc_link_fuzzer |
| NamedColor | Tests named color CMM | icc_applynamedcmm_fuzzer |
| Gray | Tests gray-to-PCS paths | icc_profile_fuzzer |

### Synthetic Mismatch Profiles (Built-in)

`encodeImageWithMismatchedProfile()` cycles through 4 strategies:
1. CMYK output profile on RGB image
2. Gray display profile on RGB image
3. Abstract Lab profile on RGB image
4. Truncated profile (size mismatch — 132 of 1024 bytes)

These synthetic profiles include valid `acsp` magic and D50 illuminant to pass
initial validation but trigger deep-path errors during color conversion.

## Step 5 — Named Color Space Variants

`encodeImageMultiFormat()` re-renders through 7 Apple named color spaces:

| Index | Color Space | ICC Impact |
|-------|------------|------------|
| 0 | kCGColorSpaceSRGB | Standard sRGB, baseline |
| 1 | kCGColorSpaceAdobeRGB1998 | Wider gamut, different TRC |
| 2 | kCGColorSpaceDisplayP3 | DCI-P3 gamut, modern displays |
| 3 | kCGColorSpaceGenericRGBLinear | Linear gamma, no TRC |
| 4 | kCGColorSpaceGenericGrayGamma2_2 | Grayscale, 2.2 gamma |
| 5 | kCGColorSpaceACESCGLinear | Film/VFX linear, AP1 gamut |
| 6 | kCGColorSpaceExtendedLinearSRGB | Extended range, negative values possible |

Each produces a TIFF with the color space's ICC profile embedded by ImageIO,
creating seeds that exercise different ICC TRC curves, gamut boundaries, and
PCS conversion paths.

## Troubleshooting

### No ICC variants generated
- Check that `saveFuzzedImage` is being called with TIFF/PNG context descriptions
- ICC variant generation only triggers for context descriptions containing "tiff" or "png"
- Verify `FUZZ_ICC_DIR` is set and contains `.icc` or `.icm` files (for real/mutated variants)

### Mismatched ICC variants not useful
- The 132-byte synthetic headers are intentionally minimal to test parser validation
- For deeper coverage, add real profiles from `/System/Library/ColorSync/Profiles/`
  to `FUZZ_ICC_DIR` and let `mutateICCProfile()` corrupt them

### Coverage plateau
- Use the 5-step coverage methodology from `fuzzer-coverage-optimization.prompt.md`
- Check `llvm-cov` for which ICC parsing functions are still uncovered
- Doxygen inheritance analysis (`inherits.html`) reveals untested CIccTag subclasses
