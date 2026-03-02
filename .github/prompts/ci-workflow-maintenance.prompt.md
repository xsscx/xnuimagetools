---
name: CI Workflow Maintenance
description: Guidelines for creating and maintaining secure GitHub Actions workflows
---

# CI Workflow Maintenance — XNU Image Tools

Standards for all GitHub Actions workflows in this multi-project repository.

## Security Requirements (Non-Negotiable)

### Action Pinning
Always use full SHA pins, never version tags:
```yaml
# ✅ CORRECT
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

# ❌ WRONG
uses: actions/checkout@v4
```

### Current Pinned SHAs
| Action | SHA | Version |
|--------|-----|---------|
| checkout | `11bd71901bbe5b1630ceea73d27597364c9af683` | v4.2.2 |
| upload-artifact | `ea165f8d65b6e75b540449e92b4886f43607fa02` | v4.6.2 |
| cache | `5a3ec84eff668545956fd18022155c47e93e2684` | v4.2.3 |
| download-artifact | `d3f86a106a0bac45b974a628896c90dbdf5c8093` | v4.3.0 |

### Permissions & Shell Hardening
```yaml
permissions:
  contents: read

env:
  BASH_ENV: /dev/null

defaults:
  run:
    shell: bash --noprofile --norc {0}
```

### Credential Isolation
```yaml
- uses: actions/checkout@...
  with:
    persist-credentials: false

- name: Credential hardening
  run: |
    git config --global credential.helper ""
    unset GITHUB_TOKEN || true
```

### Input Sanitization
NEVER inject user-controllable values into `run:` blocks:
```yaml
# ❌ DANGEROUS
run: echo "${{ github.event.pull_request.title }}"

# ✅ SAFE
env:
  TITLE: ${{ github.event.pull_request.title }}
run: echo "$TITLE" | LC_ALL=C sed 's/[^A-Za-z0-9._/ -]//g'
```

## Build Configurations by Sub-Project

### iOS Fuzzer (Mac Catalyst)
```yaml
xcodebuild build \
  -project "XNU Image Fuzzer/XNU Image Fuzzer.xcodeproj" \
  -scheme "XNU Image Fuzzer" \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug \
  -derivedDataPath /tmp/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

### VideoToolbox (clang)
```yaml
xcrun -sdk macosx clang \
  -arch arm64 -g -O1 -Wall -Wextra \
  -o build/videotoolbox-runner \
  videotoolbox-runner.m \
  build/videotoolbox-interposer.dylib \
  -framework VideoToolbox -framework Foundation \
  -framework AVFoundation -framework CoreFoundation \
  -framework CoreMedia -framework CoreVideo \
  -framework CoreImage -framework CoreGraphics -lz
codesign -s "-" --force build/videotoolbox-runner
```

### VideoToolbox (instrumented)
Add these flags to the above:
```
-fsanitize=address,undefined
-fno-omit-frame-pointer
-fno-optimize-sibling-calls
-fprofile-instr-generate
-fcoverage-mapping
```

## Coverage Pipeline
```bash
# 1. Set profraw output BEFORE running
export LLVM_PROFILE_FILE="/tmp/profraw/name-%m_%p.profraw"

# 2. Run the binary
./build/videotoolbox-runner -t 60 big.mov

# 3. Merge profraw files
xcrun llvm-profdata merge -sparse /tmp/profraw/*.profraw -o merged.profdata

# 4. Generate reports
xcrun llvm-cov report build/videotoolbox-runner -instr-profile=merged.profdata
xcrun llvm-cov show build/videotoolbox-runner -instr-profile=merged.profdata \
  -format=html -output-dir=html/
xcrun llvm-cov export build/videotoolbox-runner -instr-profile=merged.profdata \
  -format=lcov > coverage.lcov
```

## Git Identity for CI Commits
```yaml
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
```

## Workflow-Specific Notes

### videotoolbox.yml
- Has `workflow_dispatch` input `fuzz_duration` (default: 60)
- `fuzz-and-commit` job commits fuzzed frames to repo
- Needs `permissions: contents: write` for commit job
- Static analysis step must include all frameworks

### instrumented.yml
- Two parallel jobs: VideoToolbox + iOS (Mac Catalyst)
- Summary job on `ubuntu-latest` downloads and combines coverage
- Quality validation step validates all output images

### release.yml
- Triggered by `v*` tags only
- Builds all sub-projects
- Creates GitHub release with binary artifacts
- Multi-project release notes in body

### build-and-test.yml
- Scheduled cron: every 12 hours
- Generates images and commits to repo
- Must use `GITHUB_TOKEN` for push (needs `contents: write`)
