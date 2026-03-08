# Copilot Instructions — XNU Image Tools

## Project Overview

XNU Image Tools is an umbrella workspace for Apple-platform image security research.
It uses [xnuimagefuzzer](https://github.com/xsscx/xnuimagefuzzer) as a git submodule
and bundles additional projects for image generation, VideoToolbox fuzzing, and
cross-platform testing. The core fuzzer generates fuzzed images using 15 CGBitmapContext
color space and pixel format combinations (including CMYK, HDR Float16, and Indexed Color),
plus structure-aware PNG chunk mutations.

- **Language**: Objective-C (main fuzzer), Swift (generators), Python (validation scripts)
- **Platforms**: iOS 14.2+, macOS (Mac Catalyst), iPadOS, visionOS
- **License**: GPL v3
- **Author**: David Hoyt (@xsscx / @h02332)

## Clone with Submodules

```bash
git clone --recurse-submodules https://github.com/xsscx/xnuimagetools.git
# If already cloned without submodules:
git submodule update --init --recursive
```

## Documentation Map

Detailed instructions are split into specialized files. Copilot loads them
automatically based on which files you're editing.

### Path-Specific Instructions

| Document | Path | Content |
|----------|------|---------|
| **xnuimagefuzzer** | `.github/instructions/xnuimagefuzzer.instructions.md` | Bitmap contexts, ICC handling, pixel formats, testing |
| **Build & CI** | `.github/instructions/build-and-ci.instructions.md` | Build variants, CI workflows, security hardening, coding conventions |
| **CFL Seed Pipeline** | `.github/instructions/cfl-seed-pipeline.instructions.md` | ICC extraction, corpus injection, coverage optimization |
| **VideoToolbox** | `.github/instructions/videotoolbox.instructions.md` | Video fuzzer architecture, build, run, known gotchas |
| **Fuzz Apps** | `.github/instructions/fuzz-apps.instructions.md` | macOS system tool fuzzing (sips, qlmanage, mdimport) |

### Prompt Templates

| Prompt | Path | Purpose |
|--------|------|---------|
| **CI Workflow Maintenance** | `.github/prompts/ci-workflow-maintenance.prompt.md` | GitHub Actions standards and security |
| **Code Review** | `.github/prompts/code-review.prompt.md` | Multi-project review checklist |
| **Fuzzer Coverage** | `.github/prompts/fuzzer-coverage-optimization.prompt.md` | 6-step coverage improvement methodology |
| **CFL Seed Pipeline** | `.github/prompts/cfl-seed-pipeline.prompt.md` | Extract and inject ICC seeds workflow |
| **macOS Parser Fuzzing** | `.github/prompts/macos-parser-fuzzing.prompt.md` | System parser testing guide |
| **Output Quality** | `.github/prompts/output-quality-analysis.prompt.md` | Image quality validation |
| **ICC Diversity** | `.github/prompts/icc-diversity-generation.prompt.md` | ICC profile variant generation |
| **VideoToolbox Fuzzing** | `.github/prompts/videotoolbox-fuzzing.prompt.md` | Video fuzzer build and run |

## Repository Structure

```
XNU Image Fuzzer/              # ← git submodule (xsscx/xnuimagefuzzer)
├── xnuimagefuzzer.m          # Core fuzzer — 15 bitmap contexts, fuzz permutations
├── ViewController.m           # UICollectionView displaying fuzzed images
├── AppDelegate.m              # App lifecycle, exception handler
├── SceneDelegate.{h,m}        # Multi-window scene management
├── CMakeLists.txt             # CMake build (iOS arm64, Debug with ASAN)
├── Info.plist                 # UIFileSharingEnabled=YES, JPEG/PNG/GIF doc types
├── Assets.xcassets            # App icons and image assets
├── Flowers.exr / 2225.jpg     # Sample input images
└── Base.lproj/                # Storyboards
XNU Image Generator for iOS/   # iOS image generator (v1.9.0 — collision-free filenames)
XNU Image Generator/            # macOS image generator project
VideoToolbox/                   # VideoToolbox fuzzing harness
contrib/scripts/
├── validate_fuzzed_images.py  # Steganography / injection detection
├── compare_image_directories.py  # MSE, SSIM, PSNR, entropy analysis
├── read-magic-numbers.py      # 40+ magic byte signatures
└── generate_filmstrip.py      # Side-by-side comparison strips
.github/
├── workflows/                 # 7 CI/CD workflows
├── instructions/              # 5 path-specific instruction files
├── prompts/                   # 8 prompt templates
├── scripts/sanitize-sed.sh    # Input sanitization for CI
└── copilot-instructions.md    # This file (table of contents)
```

## Quick Reference

### Build (one-liner)
```bash
.github/scripts/build-native.sh           # ASAN+UBSAN+coverage — recommended
```

### Run
```bash
FUZZ_OUTPUT_DIR=/tmp/fuzzed-output timeout 120 /tmp/xnuimagetools
```

### Validate output
```bash
python3 contrib/scripts/validate_fuzzed_images.py /tmp/fuzzed-output
```

### Extract ICC seeds for CFL
```bash
python3 contrib/scripts/extract-icc-seeds.py --input fuzzed-images/ --inject-cfl ../cfl
```

See `.github/instructions/build-and-ci.instructions.md` for all build variants
and CI pipeline details.

## Submodule Workflow

The fuzzer source lives in [xsscx/xnuimagefuzzer](https://github.com/xsscx/xnuimagefuzzer).
Code changes go there first, then the submodule pointer is updated here:

```bash
# After changes are pushed to xnuimagefuzzer:
cd "XNU Image Fuzzer"
git pull origin main
cd ..
git add "XNU Image Fuzzer"
git commit -m "Update xnuimagefuzzer submodule"
git push
```

## Platform Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| macOS 14+ arm64 | ✅ | Mac Catalyst, native execution |
| macOS 15+ x86_64 | ✅ | Rosetta 2 |
| iOS 17+ | ✅ | Primary target |
| iPadOS 17+ | ✅ | Full support |
| visionOS 1.x | ✅ | Supported |
| watchOS | ❌ | Not applicable |

## Quality Validation Scripts

| Script | Purpose |
|--------|---------|
| `validate_fuzzed_images.py` | Steganography — LSB/MSB injection detection (XSS, SQLi, XXE, path traversal) |
| `read-magic-numbers.py` | 40+ file magic signatures, MIME type checking, HTML report |
| `compare_image_directories.py` | MSE, SSIM, PSNR, perceptual hash, entropy (requires opencv-python, scikit-image) |
| `generate_filmstrip.py` | Side-by-side comparison strips |

## Common Issues & Solutions

For detailed troubleshooting, see the xnuimagefuzzer repo's troubleshooting instructions.

### Pipeline Phase 2 — Cumulative Mutation Bug (Fixed v1.9.0)
`performPipelineFuzzing()` Phase 2 reloads from `cleanData` for each permutation.
Previously it mutated `cleanImage` in-place, causing cumulative mutations where
each permutation received all prior mutations instead of independent single mutations.

### 1BitMonochrome — Grayscale Drawing (Fixed v1.8.1)
1BitMonochrome and Grayscale contexts use `CGColor(gray:alpha:)` for colors and
`CGColorSpaceCreateDeviceGray()` for gradients. Using RGB colors on a grayscale
context produces 0-output images.

### Build fails with `-Wenum-conversion`
Cast `CGImageAlphaInfo` to `CGBitmapInfo`:
```objc
CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
```

### Mac Catalyst app exits immediately
Must use `open "$APP_BUNDLE"` — bare Mach-O binary doesn't initialize UIKit.

### SIGPIPE crash in CI
Never pipe Apple CLI tools through `| head`. Use `| sed -n '1,Np'` instead.

### Coverage report empty
Use `dlsym(RTLD_DEFAULT, "__llvm_profile_write_file")` — NOT `__attribute__((weak))`.
Verify `LLVM_PROFILE_FILE` reaches the process via `open --env`.

## VideoToolbox Fuzzer

See `.github/instructions/videotoolbox.instructions.md` for full details.

The VideoToolbox fuzzer exercises Apple's hardware video decoding pipeline by
extracting frames from video files, applying byte-level mutations, and encoding
fuzzed frames through VTCompressionSession.

```bash
cd VideoToolbox/Fuzzing && make          # build
ASAN_OPTIONS="detect_leaks=0:halt_on_error=0" \
  build/videotoolbox-runner -t 60 -o /tmp/fuzzed-frames big.mov
```


## Multi-Agent Collaboration

This repo works with the `xsscx/research` repo (WSL-2/Linux agent). Key coordination:

- **File ownership**: macOS agent owns `xnuimagetools/`, `fuzz/graphics/*/xig-*`, `fuzz/xnuimage*/`
- **Seeds flow**: macOS generates → `fuzz/` staging → WSL-2 seeds into `cfl/corpus-*/`
- **Crash testing**: WSL-2 finds crashes → macOS tests against ColorSync/ImageIO
- **Remote analysis**: Use MCP Docker API (`ghcr.io/xsscx/icc-profile-mcp web`) to
  analyze ICC profiles without git commit overhead. See `cfl-seed-pipeline.instructions.md`.
- **Coordination docs**: `research/.github/instructions/multi-agent.instructions.md` and
  `research/.github/prompts/cooperative-development.prompt.md`
- **Always fetch/pull** at session start: `git fetch --all && git pull`
