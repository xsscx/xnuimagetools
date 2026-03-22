# Copilot Instructions — XNU Image Tools

## Scope For This Checkout

Treat `xnuimagetools/` as the working root. Validate commands and paths locally
before assuming anything about sibling repos or generated artifacts.

### Local-First Rules

- Work in this repo unless a task explicitly requires the adjacent research checkout.
- `XNU Image Fuzzer/` is a git submodule. Fuzzer source edits happen inside that
  directory; repo-local docs, workflows, generators, scripts, and VideoToolbox code
  live here.
- Prefer repo-local paths: `contrib/scripts/...`, `.github/scripts/...`,
  `fuzz-apps.sh`, `fuzzed-images/<timestamp>/`, and `fuzzed-video/<timestamp>/`.
- In this workspace, optional sibling resources live at `../cfl`, `../fuzz`,
  `../test-profiles`, `../extended-test-profiles`, and `../.github/...`.
  Do not hardcode `../research/...` paths.

## Project Overview

XNU Image Tools is a multi-project Apple-platform image generation and fuzzing
workspace.

- **Objective-C**: `XNU Image Fuzzer/` submodule and `VideoToolbox/Fuzzing/`
- **Swift**: `XNU Image Generator for iOS/`, `XNU Image Generator for Watch/`
- **Python**: validation and extraction tooling under `contrib/scripts/`
- **License**: GPL v3
- **Author**: David Hoyt (@xsscx / @h02332)

The current `xnuimagefuzzer.m` source exposes **17** bitmap-context entry points,
including newer Display P3 and BT.2020 wide-gamut paths.

## Clone With Submodules

```bash
git clone --recurse-submodules https://github.com/xsscx/xnuimagetools.git
# If already cloned without submodules:
git submodule update --init --recursive
```

## Documentation Map

Detailed instructions are split into specialized files.

### Path-Specific Instructions

| Document | Path | Content |
|----------|------|---------|
| **xnuimagefuzzer** | `.github/instructions/xnuimagefuzzer.instructions.md` | Bitmap contexts, ICC handling, pipeline/chained modes, testing |
| **Build & CI** | `.github/instructions/build-and-ci.instructions.md` | Build variants, CI workflows, security hardening, coding conventions |
| **CFL Seed Pipeline** | `.github/instructions/cfl-seed-pipeline.instructions.md` | ICC extraction, corpus injection, coverage workflow |
| **VideoToolbox** | `.github/instructions/videotoolbox.instructions.md` | Video fuzzer architecture, build, run, known gotchas |
| **Fuzz Apps** | `.github/instructions/fuzz-apps.instructions.md` | macOS system tool fuzzing (`sips`, `qlmanage`, `mdimport`, `tiffutil`) |

### Prompt Templates

| Prompt | Path | Purpose |
|--------|------|---------|
| **CI Workflow Maintenance** | `.github/prompts/ci-workflow-maintenance.prompt.md` | GitHub Actions standards and security |
| **Code Review** | `.github/prompts/code-review.prompt.md` | Multi-project review checklist |
| **Fuzzer Coverage** | `.github/prompts/fuzzer-coverage-optimization.prompt.md` | Coverage improvement methodology |
| **CFL Seed Pipeline** | `.github/prompts/cfl-seed-pipeline.prompt.md` | Extract and inject ICC seeds workflow |
| **macOS Parser Fuzzing** | `.github/prompts/macos-parser-fuzzing.prompt.md` | System parser testing guide |
| **Output Quality** | `.github/prompts/output-quality-analysis.prompt.md` | Image quality validation |
| **ICC Diversity** | `.github/prompts/icc-diversity-generation.prompt.md` | ICC profile variant generation |
| **VideoToolbox Fuzzing** | `.github/prompts/videotoolbox-fuzzing.prompt.md` | Video fuzzer build and run |

## Repository Structure

```text
XNU Image Fuzzer/               # git submodule with the Obj-C fuzzer source
├── XNU Image Fuzzer/           # app sources, assets, CMakeLists.txt
├── contrib/scripts/            # submodule-local scripts
└── codeql-queries/             # custom CodeQL query pack (no workflow here)
XNU Image Generator for iOS/    # iOS image generator project
XNU Image Generator for Watch/  # watchOS image generator project
VideoToolbox/
└── Fuzzing/                    # VideoToolbox runner, interposer, build files
contrib/scripts/                # repo-local validation and extraction scripts
.github/
├── workflows/                  # 6 tracked workflows
├── instructions/               # path-specific instruction files
├── prompts/                    # prompt templates
├── scripts/build-native.sh     # native clang build + run + coverage
└── copilot-instructions.md     # this file
fuzz-apps.sh                    # macOS parser harness
fuzzed-images/                  # checked-in image runs (timestamped dirs)
fuzzed-video/                   # checked-in VideoToolbox runs
XNU Image Tools.xcodeproj       # top-level Xcode project
```

## Quick Reference

### Build

```bash
.github/scripts/build-native.sh           # build + run + coverage
.github/scripts/build-native.sh --build-only
```

### Run The Native Binary

```bash
BINARY=/tmp/native-build/xnuimagetools

FUZZ_OUTPUT_DIR=/tmp/fuzzed-output \
FUZZ_ICC_DIR=../test-profiles \
LLVM_PROFILE_FILE=/tmp/profraw/tools-%m_%p.profraw \
ASAN_OPTIONS="detect_leaks=0:halt_on_error=0" \
UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0" \
  "$BINARY"
```

### Validate Output

```bash
python3 contrib/scripts/validate_fuzzed_images.py /tmp/fuzzed-output
python3 contrib/scripts/read-magic-numbers.py /tmp/fuzzed-output
```

### Feed A Checked-In Run Into macOS Parsers

```bash
LATEST_RUN=$(ls -1dt fuzzed-images/*/ | sed -n '1p')
./fuzz-apps.sh "$LATEST_RUN" --timeout 15
```

### Extract ICC Seeds For CFL

```bash
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ \
  --inject-cfl ../cfl
```

## Build / CI Snapshot

| Workflow | Purpose | Current Trigger |
|----------|---------|-----------------|
| `code-quality.yml` | Lightweight Obj-C/C/Swift/Python checks | push, pull request, manual |
| `build-and-test.yml` | Build, generate images, commit corpus, extract seeds | push, pull request, weekly Monday 06:00 UTC, manual |
| `cached-build.yml` | DerivedData-cached Xcode build and analysis | push, pull request, manual |
| `instrumented.yml` | Mac Catalyst sanitizers plus native clang coverage | push, pull request, manual |
| `videotoolbox.yml` | VideoToolbox build, coverage, static analysis, fuzz run | push, pull request on `VideoToolbox/**`, manual |
| `release.yml` | Tagged/manual release artifacts | tags `v*`, manual |

There is currently **no** `codeql-analysis.yml` workflow under `.github/workflows/`.

## Submodule Workflow

Only update the submodule pointer when files under `XNU Image Fuzzer/` changed.
If you are editing repo-local docs, workflows, generators, or VideoToolbox files,
stay in this repo.

```bash
# After changes are pushed to the xnuimagefuzzer submodule:
cd "XNU Image Fuzzer"
git pull origin main
cd ..
git add "XNU Image Fuzzer"
git commit -m "Update xnuimagefuzzer submodule"
git push
```

## Output Expectations

- The native build script uses **80+ files** as its current success threshold for
  default runs.
- Checked-in runs under `fuzzed-images/` currently contain roughly **180** top-level
  files per timestamped directory.
- `--pipeline` mode writes additional `pipeline-*` subdirectories under the chosen
  `FUZZ_OUTPUT_DIR`.

## Cross-Repo Coordination

If the adjacent research checkout is present, shared coordination docs are:

- `../.github/instructions/multi-agent.instructions.md`
- `../.github/prompts/cooperative-development.prompt.md`
- `../.github/prompts/remote-analysis.prompt.md`

When a sibling repo is not present, keep work fully repo-local and avoid assuming
those paths exist.
