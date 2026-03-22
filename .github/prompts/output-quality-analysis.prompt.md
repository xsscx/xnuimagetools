---
name: Output Quality Analysis
description: Validate fuzzed images and generated output for quality and correctness
---

# Output Quality Analysis

Validate output images from all fuzzers and generators for format correctness,
structural integrity, and potential security findings.

## Quick Validation (macOS built-in tools, no dependencies)

### Check format, dimensions, and color space
```bash
for f in /path/to/images/*; do
  echo "=== $(basename "$f") ==="
  sips -g format -g pixelWidth -g pixelHeight -g space -g bitsPerSample "$f" 2>/dev/null
  file -b "$f" | cut -c1-80
  echo ""
done
```

### Validate file sizes
```bash
find /path/to/images -type f -size 0 -print  # Find empty files
find /path/to/images -type f -exec stat -f '%z %N' {} \; | sort -n | sed -n '1,10p'  # Smallest files
```

### Magic byte verification
```bash
for f in /path/to/images/*; do
  xxd -l 16 "$f" | sed -n '1p'
done
```

## Python Validation Scripts (contrib/scripts/)

### Steganography / Injection Detection
```bash
pip install Pillow
python3 contrib/scripts/validate_fuzzed_images.py \
  --input /path/to/images \
  --output /tmp/validation-report \
  --report /tmp/validation-report/report.txt
```
Checks LSB/MSB of pixel data for injected attack strings and writes a
plain-text `report.txt` for CI summaries. It currently scans:
- `.png`, `.jpg`, `.jpeg`, `.gif`, `.tiff`, `.tif`, `.bmp`
- **one directory only** (non-recursive)

Signals currently include:
- Buffer overflow patterns
- XSS payloads (`<script>`)
- SQL injection (`' OR ''='`)
- Format string vulnerabilities (`%d %s`)
- XXE injection
- Path traversal (`../`)
- Null byte injection (`\x00\x00\x00`, noisy / low-signal)

### Magic Number Analysis
```bash
pip install Pillow python-magic
python3 contrib/scripts/read-magic-numbers.py
```
Validates 40+ file signatures, checks MIME types, generates HTML report.

### Cross-Device Comparison (heavy dependencies)
```bash
pip install opencv-python scikit-image imagehash pillow-heif Pillow
```
`compare_image_directories.py` is still a helper, not a stable CLI: its current
`__main__` hardcodes `/mnt/...` paths. Refactor/patch it before relying on it in
automation. It computes MSE, SSIM, PSNR, perceptual hash distance, and entropy.

## CI Quality Validation Step

`build-and-test.yml` runs:
```bash
python3 contrib/scripts/validate_fuzzed_images.py \
  --input "$FUZZ_DIR" \
  --output /tmp/validation-report \
  --report /tmp/validation-report/report.txt
```
and appends `report.txt` to the GitHub Actions Step Summary.

`instrumented.yml` includes a separate built-in quality validation step that
runs after fuzzing. It uses `sips` (macOS built-in) to validate:

1. **File format** — recognized image format (PNG, JPEG, TIFF, etc.)
2. **Dimensions** — valid pixel width and height
3. **File size** — non-zero (empty files indicate failures)

Results appear in the GitHub Actions Step Summary as a per-file table.

## Expected Quality Metrics

### XNU Image Fuzzer Output
- Current source defines **17 bitmap contexts**, including Display P3 and BT.2020
- CI/native sanity runs should usually produce **80+ files**
- Checked-in timestamped runs under `fuzzed-images/` are currently closer to **~180 top-level files**
- Recent merged committed runs can exceed **500 total files** once `catalyst/`,
  `watch/`, and `ios-gen/` outputs are included
- All files should have non-zero size
- All files should be recognized by `sips`
- Common formats: PNG, JPEG, GIF, TIFF, plus additional format/ICC variants depending on run mode

### VideoToolbox Fuzzer Output
- **PNG frames** extracted from fuzzed video decoding
- Valid PNG magic bytes (`\x89PNG\r\n\x1a\n`)
- Dimensions match source video frame size
- Some frames may be intentionally corrupted (expected for fuzzing)

## Interpreting Results

| Finding | Severity | Action |
|---------|----------|--------|
| Empty file (0 bytes) | ⚠️ Warning | Image creation failed silently |
| Unrecognized format | ⚠️ Warning | Possible corruption or wrong extension |
| Valid format, wrong dimensions | ℹ️ Info | May be intentional fuzzing variation |
| `\x00\x00\x00` bit-plane hit | ℹ️ Info | Low-signal heuristic; correlate with decode failures or crashes before escalating |
| Pillow decode failure on Linux float TIFF | ℹ️ Info | Re-check with `sips` / Apple stack before calling it a renderer bug |
| ASAN finding during generation | 🔴 Critical | Memory safety bug in renderer |
| UBSAN finding during generation | 🟡 Medium | Undefined behavior in math |
| Injection string in LSB/MSB | ℹ️ Info | Heuristic signal only; use with parser crashes, sanitizer output, and format validation |
