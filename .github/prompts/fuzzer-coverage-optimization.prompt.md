---
name: Fuzzer Coverage Optimization
description: Systematic methodology for improving CFL fuzzer coverage using xnuimagetools output, Doxygen analysis, and source code review
---

# Fuzzer Coverage Optimization Methodology

Step-by-step guide for improving CFL LibFuzzer coverage by combining code coverage
analysis, Doxygen class hierarchy inspection, source code review, and xnuimagetools
seed pipeline integration.

## Overview

This methodology was developed across multi-session work that achieved significant
coverage gains across 19 CFL fuzzers by combining six techniques:

1. **HTML coverage report analysis** — identify uncovered lines and classify gaps
2. **Dictionary expansion** — add ICC specification tokens to fuzzer dictionaries
3. **Targeted seed creation** — craft inputs that exercise specific code paths
4. **Source code fidelity audit** — compare fuzzers against iccDEV tool source code
5. **Doxygen inheritance analysis** — find untested class hierarchies
6. **ICC diversity generation** — use xnuimagetools ICC variants for seed enrichment

## Step 1: Identify Coverage Gaps from HTML Reports

```bash
# Extract uncovered lines from a specific fuzzer's HTML coverage report
grep -B1 "class='uncovered-line'" \
  coverage-report/html/coverage/home/h02332/po/research/cfl/<fuzzer>.cpp.html | \
  grep -oP 'data-linenumber="\K[0-9]+'

# Get branch coverage percentage
grep -oP 'Branches.*?(\d+\.\d+%)' \
  coverage-report/html/coverage/home/h02332/po/research/cfl/<fuzzer>.cpp.html
```

### Classify Each Uncovered Line

For each gap, determine the category:

| Category | Action | Example |
|----------|--------|---------|
| **Dead code** | Document and skip | Upstream parser bug makes path unreachable |
| **Allocation failure** | Skip | `new` returning NULL never happens under ASAN |
| **Missing seed** | Create targeted seed | No v5 profile → v5 code path not tested |
| **Missing dict token** | Add to dictionary | ICC tag signature not in dict |
| **Fidelity gap** | Update fuzzer source | Fuzzer doesn't call function that tool uses |

## Step 2: Expand Dictionary with ICC Specification Tokens

### LibFuzzer Dictionary Syntax Rules
- Only `\xHH` hex escapes, `\\`, and `\"` are supported
- `\n`, `\t`, `\r` are **NOT** supported — use `\x0a`, `\x09`, `\x0d`
- Empty string `""` is a parse error
- Non-ASCII must be hex-escaped (em dash `—` = `\xe2\x80\x94`)

### High-Value Dictionary Sections

```
# ICC header magic and version bytes
kw_acsp="acsp"
kw_v2="\x02\x10\x00\x00"
kw_v4="\x04\x40\x00\x00"
kw_v5="\x05\x00\x00\x00"

# Tag type signatures (4 bytes each)
kw_mluc="mluc"
kw_mAB_="mAB "
kw_mBA_="mBA "
kw_sf32="sf32"
kw_XYZ_="XYZ "

# Profile class signatures
kw_scnr="scnr"
kw_mntr="mntr"
kw_prtr="prtr"
kw_link="link"
kw_spac="spac"
kw_abst="abst"
kw_nmcl="nmcl"

# Color space signatures
kw_RGB_="RGB "
kw_CMYK="CMYK"
kw_GRAY="GRAY"
kw_Lab_="Lab "
kw_XYZ_cs="XYZ "
```

## Step 3: Create Targeted Seeds

### From xnuimagetools Pipeline
```bash
# Generate ICC-rich images across all 15 bitmap contexts
FUZZ_ICC_DIR=test-profiles FUZZ_OUTPUT_DIR=/tmp/icc-rich ./XNU\ Image\ Fuzzer

# Extract and inject into CFL corpora
python3 xnuimagetools/contrib/scripts/extract-icc-seeds.py \
  --input /tmp/icc-rich --inject-cfl cfl
```

### From Test Profiles
```bash
# Copy existing test profiles as seeds (profile/dump/toxml fuzzers)
for f in test-profiles/*.icc; do
  cp "$f" cfl/corpus-icc_profile_fuzzer/
done
```

### Synthetic Seeds for CMM Fuzzers

CMM fuzzers (link, apply, applyprofiles, applynamedcmm) need **profile pairs**:

```bash
# Concatenate two profiles for link fuzzer (4 control bytes at end)
cat test-profiles/sRGB.icc test-profiles/CMYK.icc > /tmp/pair.bin
printf '\x00\x00\x00\x00' >> /tmp/pair.bin  # control bytes
cp /tmp/pair.bin cfl/corpus-icc_link_fuzzer/srgb_cmyk_pair.icc
```

### Key Input Formats by Fuzzer

| Fuzzer | Format | Min Size |
|--------|--------|----------|
| profile, dump, deep_dump, toxml | Raw ICC bytes | 128 |
| fromxml | XML text (`<IccProfile>...</IccProfile>`) | 100 |
| fromcube | .cube text (`LUT_3D_SIZE N\n...`) | 50 |
| link | `[ICC1][ICC2][4 ctrl bytes]` | 260 |
| applyprofiles | `[ICC][control bytes]` | 150 |
| v5dspobs | `[4B size][display ICC][observer ICC]` | 264 |
| tiffdump, specsep | TIFF file with IFD | 100 |

## Step 4: Source Code Fidelity Audit

Compare each fuzzer against its corresponding iccDEV command-line tool:

```bash
# Side-by-side comparison
diff <(grep -E 'CIcc|Icc' cfl/icc_link_fuzzer.cpp | sort) \
     <(grep -E 'CIcc|Icc' cfl/iccDEV/Tools/CmdLine/IccApplyToLink/iccApplyToLink.cpp | sort)
```

### Key Questions for Each Fuzzer
1. Does the fuzzer call the same API functions as the tool?
2. Does the fuzzer exercise all parameter combinations?
3. Does the fuzzer handle errors the same way?
4. Are there tool features the fuzzer doesn't exercise?

### ASAN Ownership Rules (Critical for CMM Fuzzers)
- `CIccCmm::AddXform(CIccProfile*)` transfers ownership to `CIccXform::Create()`
- On `icCmmStatOk`: CMM owns profile — do NOT delete
- On `icCmmStatBadXform`: `Create()` already freed — do NOT delete (double-free)
- On other errors: Caller still owns — MUST delete

## Step 5: Doxygen Inheritance Analysis

Review class hierarchies to find untested leaf classes:

### CIccTag Hierarchy (35+ leaves)
Key coverage gaps identified:
- `CIccTagProfileSeqId` — ~33% coverage, needs V4+ profiles with `psid` tag
- `CIccTagDict` — ~43% coverage, needs profiles with `dict` tag type
- `CIccTagStruct` — ~50% coverage, needs V5 profiles with structured elements

### CIccMpe Hierarchy (17 leaves)
Key coverage gaps:
- `CIccMpeCalculator` — variable coverage, needs profiles with calculator elements
- `CIccMpeSpectralMatrix` — low coverage, needs V5 spectral profiles

### Finding Untested Classes
```bash
# Search Doxygen output for class with 0% coverage
grep -r "0.00%" coverage-report/html/ | grep -i "class"

# Or use the interactive SVG at:
# https://xss.cx/public/docs/iccdev/inherits.html
```

## Verification

After making changes, always verify:

```bash
# 1. ASAN smoke test (30s per fuzzer)
for f in cfl/bin/icc_*_fuzzer; do
  name=$(basename "$f")
  ASAN_OPTIONS=detect_leaks=0 LLVM_PROFILE_FILE=/dev/null \
    "$f" -max_total_time=30 "cfl/corpus-${name}/" 2>&1 | \
    grep "INITED\|DONE\|NEW" | head -2
done

# 2. Check edge count improvement
# Compare "cov:" value in INITED line before vs after

# 3. Full coverage report (after extended run)
.github/scripts/merge-profdata.sh
.github/scripts/generate-coverage-report.sh
```

## Results Tracking

Document coverage improvements in commit messages:
```
feat(cfl): improve icc_link_fuzzer coverage

- Added IXformIterator, SaveIccProfile, 8 lut types
- Coverage: 35% → 65% fidelity with IccApplyToLink tool
- Edge count: +174 new edges in 30s verification
- ASAN: 0 findings on smoke test
```

## Step 6: ICC Diversity via xnuimagetools

After Steps 1–5, use xnuimagetools' ICC variant generation to create seeds with
diverse ICC profile characteristics. This targets the remaining uncovered ICC
parsing paths that need valid-structure but unusual-content profiles.

### Generate ICC-Diverse Seeds

```bash
# Generate with all ICC variants (4 per TIFF/PNG save)
FUZZ_ICC_DIR=../research/test-profiles \
FUZZ_OUTPUT_DIR=/tmp/icc-diverse \
  open --env FUZZ_ICC_DIR=../research/test-profiles \
       --env FUZZ_OUTPUT_DIR=/tmp/icc-diverse "$APP_BUNDLE"

# Extract and inject into CFL corpus
python3 contrib/scripts/extract-icc-seeds.py \
  --input /tmp/icc-diverse --inject-cfl ../research/cfl
```

### ICC Variant Types and Their Coverage Impact

| Variant | Coverage Target | Why Effective |
|---------|----------------|---------------|
| Real ICC (round-robin) | TRC curves, A2B/B2A LUTs | Exercises full color conversion pipeline |
| Stripped (no ICC) | Fallback/default paths | Tests what happens with no color management |
| Mismatched (CMYK on RGB) | Validation + error handling | Triggers colorSpace mismatch detection |
| Mismatched (Gray on RGB) | Channel count mismatch | Tests nComponents validation |
| Mismatched (Lab abstract) | Abstract profile handling | Exercises Lab→Lab transform paths |
| Mismatched (truncated) | Size validation | Tests profile size vs declared size |
| Mutated (6 strategies) | Error recovery paths | Corrupted tags/offsets/CLUTs/headers |
| Named color spaces (7) | Per-space TRC/gamut paths | sRGB/P3/AdobeRGB/ACES/ExtLinear |

### Cross-Reference with Doxygen

After generating ICC variants, cross-reference coverage gains against the Doxygen
inheritance tree (`inherits.html`) to identify which CIccTag and CIccMpe subclasses
the new seeds reached. Leaf classes still uncovered need hand-crafted seeds targeting
their specific tag signatures:

```bash
# Check which tag types appear in the ICC variant seeds
for f in /tmp/icc-diverse/fuzzed_image_*_icc_*.tiff; do
  xxd "$f" | grep -c "acsp" && echo "$f"
done
```
