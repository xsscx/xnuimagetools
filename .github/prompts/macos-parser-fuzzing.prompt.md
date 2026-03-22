---
name: macOS Image Parser Fuzzing
description: Feed fuzzed images into macOS system tools (sips, qlmanage, mdimport, tiffutil) to find crashes
---

# macOS Image Parser Fuzzing

Use `fuzz-apps.sh` to feed fuzzed images into macOS system image parsers and detect
crashes, hangs, and security-relevant behavior.

## Quick Start

```bash
# Fuzz all images in the latest output directory
LATEST_RUN=$(ls -1dt fuzzed-images/*/ | sed -n '1p')
./fuzz-apps.sh "$LATEST_RUN" --timeout 15

# Fuzz with extended timeout for large/complex images
./fuzz-apps.sh "$LATEST_RUN" --timeout 30

# Fuzz only specific tools
FUZZ_APPS_TOOLS=sips-verify,sips-getprop ./fuzz-apps.sh "$LATEST_RUN"

# Fuzz CFL crash artifacts against macOS parsers
CRASH_DIR=/tmp/cfl-crashes
./fuzz-apps.sh "$CRASH_DIR" --timeout 15
```

## What to Look For

### Critical Findings (Report Immediately)
- **SIGSEGV (exit 139)**: Memory access violation — likely exploitable
- **SIGABRT (exit 134)**: Assertion failure — may indicate corruption
- **SIGBUS (exit 138)**: Bus error — often alignment or mapping issue
- **SIGILL (exit 132)**: Illegal instruction — possible code injection
- **New DiagnosticReports**: System-level crash logs with full stack traces

### Non-Critical but Interesting
- **Timeouts (exit 124)**: Possible infinite loop / algorithmic complexity
- **Non-zero exit codes**: Parser rejection — may reveal parsing assumptions
- **Empty output**: Tool failed silently — edge case worth investigating

## Analysis Workflow

### 1. Run Initial Scan
```bash
LATEST_RUN=$(ls -1dt fuzzed-images/*/ | sed -n '1p')
./fuzz-apps.sh "$LATEST_RUN" --timeout 15 --report /tmp/scan-1
```

### 2. Review Results
```bash
# Check summary
cat /tmp/scan-1/summary.txt

# Find all crashes
grep 'crash' /tmp/scan-1/findings.csv

# Find all timeouts
grep 'timeout' /tmp/scan-1/findings.csv
```

### 3. Minimize Crash-Triggering Input
```bash
# For each crash file, try to minimize
for f in /tmp/scan-1/crashes/*; do
  echo "=== $(basename "$f") ==="
  file "$f"
  ls -la "$f"
  # Re-test to confirm reproducibility
  perl -e 'alarm shift; exec @ARGV' 15 sips --debug --verify "$f" 2>&1 || echo "EXIT: $?"
done
```

### 4. Cross-Reference with CFL Findings
```bash
# Check if any crash files trigger issues in the CFL fuzzer suite
CFL_DIR=../cfl
for f in /tmp/scan-1/crashes/*.tiff; do
  ASAN_OPTIONS=detect_leaks=0 perl -e 'alarm shift; exec @ARGV' 30 \
    "$CFL_DIR/bin/icc_tiffdump_fuzzer" "$f" 2>&1 | tail -5
done
```

## Integration Points

### From xnuimagetools → fuzz-apps
```bash
# Generate images → test against macOS parsers
BINARY=/tmp/native-build/xnuimagetools
FUZZ_OUTPUT_DIR=/tmp/fresh-fuzz "$BINARY"
./fuzz-apps.sh /tmp/fresh-fuzz --timeout 15
```

### From CFL fuzzers → fuzz-apps
```bash
# Test CFL crash artifacts against macOS parsers
CRASH_DIR=/tmp/cfl-crashes
OOM_DIR=/tmp/cfl-ooms
./fuzz-apps.sh "$CRASH_DIR" --timeout 15
./fuzz-apps.sh "$OOM_DIR" --timeout 15
```

### From fuzz-apps → CFL fuzzers
```bash
# Crash-triggering images become CFL seeds
cp /tmp/scan-1/crashes/*.icc ../cfl/corpus-icc_profile_fuzzer/
cp /tmp/scan-1/crashes/*.tiff ../cfl/corpus-icc_tiffdump_fuzzer/
```

## Device-Specific Testing

Different devices may trigger different parsing paths:
```bash
# Test iPhone-generated images
./fuzz-apps.sh fuzzed-images/2026-03-03-iPhone/ --report /tmp/iphone-report

# Test Watch-generated images  
./fuzz-apps.sh fuzzed-images/2026-03-03-Watch/ --report /tmp/watch-report

# Compare crash rates
echo "iPhone crashes:"; grep -c 'crash' /tmp/iphone-report/findings.csv
echo "Watch crashes:"; grep -c 'crash' /tmp/watch-report/findings.csv
```
