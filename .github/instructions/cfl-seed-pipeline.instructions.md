# CFL Fuzzer Seed Pipeline — XNU Image Tools

The xnuimagetools output feeds the CFL (Crash-Free LibFuzzer) ICC profile fuzzers
in the research repo. With ICC variant generation enabled, each run produces images
with diverse ICC profiles embedded — dramatically improving CFL seed coverage.

## Output Flow

```
iOS Image Generator (v1.9.0+)  →  fuzz/xnuimagegenerator/{format}/
xnuimagefuzzer (--input-dir)   →  fuzz/xnuimagefuzzer/{format}/
                                   ├── icc/ (extracted ICC profiles)
                                   ├── chained/ (multi-pass mutations)
                                   └── pipeline/ (5-phase outputs)
extract-icc-seeds.py           →  cfl/corpus-icc_*_fuzzer/
```

### Filename Conventions (Collision-Free)

| Source | Pattern | Example |
|--------|---------|---------|
| iOS Generator | `xig-{ctx}-{WxH}[-icc_{profile}]-{hash6}.{ext}` | `xig-stdrgb-300x300-a1b2c3.png` |
| Fuzzer | `xif-{src}-perm{N}[-{variant}]-{hash6}.{ext}` | `xif-stdrgb-perm5-icc_sRGB-d4e5f6.tiff` |

Hash suffixes (6-char SHA-256 of file content) prevent collisions across runs.

## Maximizing ICC Profile Diversity

Set `FUZZ_ICC_DIR` to generate ICC-rich output:
```bash
FUZZ_ICC_DIR=../test-profiles FUZZ_OUTPUT_DIR=/tmp/icc-rich-output ./XNU\ Image\ Fuzzer
```

**Without `FUZZ_ICC_DIR`**: ICC variants still generate stripped (no-ICC) and mismatched
(CMYK/Gray/Lab on RGB) files. Only real ICC and mutated ICC variants require `FUZZ_ICC_DIR`.

**Expected output per TIFF/PNG save** (with `FUZZ_ICC_DIR` set):
- `fuzzed_image_<ctx>_icc_<profilename>.tiff` — real ICC profile embedded
- `fuzzed_image_<ctx>_icc_mutated.tiff` — mutated ICC profile
- `fuzzed_image_<ctx>_no_icc.tiff` — stripped color space
- `fuzzed_image_<ctx>_icc_mismatch.tiff` — mismatched profile

## Extract and Inject Seeds
```bash
# Extract ICC profiles + TIFF files from all fuzzed-images runs
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ \
  --output /tmp/extracted-seeds

# Extract AND inject directly into CFL corpus directories
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ \
  --inject-cfl ../cfl

# Extract from a specific device run
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/2026-03-03-030143/ \
  --output /tmp/device-seeds
```

## What Gets Extracted
- **ICC profiles** → `corpus-icc_profile_fuzzer/`, `corpus-icc_dump_fuzzer/`,
  `corpus-icc_deep_dump_fuzzer/`, `corpus-icc_toxml_fuzzer/`
- **TIFF files** → `corpus-icc_tiffdump_fuzzer/`, `corpus-icc_specsep_fuzzer/`
- **Mismatched ICC TIFFs** → Especially valuable for error-path coverage in
  `icc_profile_fuzzer` and `icc_toxml_fuzzer` (exercises ICC validation failures)

## Coverage Optimization Methodology (Proven 6-Step Process)

1. **Coverage Report Analysis** — Generate `llvm-cov` reports, identify uncovered functions
2. **Dictionary Expansion** — Add type signatures, tag names, magic bytes from uncovered code paths
3. **Targeted Seed Creation** — Synthesize seed files exercising specific functions
4. **Fidelity Audit** — Compare fuzzer input handling vs upstream iccDEV tool behavior
5. **Doxygen Inheritance Analysis** — Map class hierarchies to find untested leaf classes
6. **ICC Diversity Generation** — Use xnuimagetools ICC variants to create seeds with
   embedded/stripped/mismatched/mutated ICC profiles

## API Notes

- **`kCGImagePropertyICCProfile` does NOT exist** in Apple SDKs — do not use it
- Use `CGColorSpaceCreateWithICCData()` (iOS 10+/macOS 10.12+) to create a color space
  from raw ICC bytes, re-render through `CGBitmapContextCreate()`, and ImageIO
  auto-embeds the ICC profile when saving via `CGImageDestinationAddImage()`
- `kCGImagePropertyProfileName` (string, not data) is available on all platforms

## Remote Analysis via MCP Docker API

Instead of committing extracted ICC profiles to git for WSL-2 analysis, macOS agents
can analyze profiles directly via the MCP Docker REST API:

```bash
# Upload extracted ICC profile for analysis (no git commit needed)
curl -s -F "file=@extracted-profile.icc" http://<host>:8080/api/upload
# → {"ok":true,"path":"/tmp/mcp-uploads/a1b2c3_extracted-profile.icc",...}

# Get 141-heuristic security analysis as JSON
curl -s "http://<host>:8080/api/security-json?path=/tmp/mcp-uploads/a1b2c3_extracted-profile.icc"

# Full combined analysis
curl -s "http://<host>:8080/api/full?path=/tmp/mcp-uploads/a1b2c3_extracted-profile.icc"
```

Docker image: `ghcr.io/xsscx/icc-profile-demo` (run with `api` argument for REST mode).
See `research/.github/prompts/remote-analysis.prompt.md` for the full workflow.

**Use remote API for**: Quick triage of many profiles, spot-checks during fuzzing.
**Use git commit for**: Crash PoCs, batch reports, anything worth preserving long-term.
