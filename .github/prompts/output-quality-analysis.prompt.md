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
find /path/to/images -type f -printf '%s %p\n' | sort -n | sed -n '1,10p'  # Smallest files
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
python3 contrib/scripts/validate_fuzzed_images.py
```
Checks LSB/MSB of pixel data for injected attack strings:
- Buffer overflow patterns
- XSS payloads (`<script>`)
- SQL injection (`' OR ''='`)
- Format string vulnerabilities (`%d %s`)
- XXE injection
- Path traversal (`../`)
- Null byte injection

### Magic Number Analysis
```bash
pip install Pillow python-magic
python3 contrib/scripts/read-magic-numbers.py
```
Validates 40+ file signatures, checks MIME types, generates HTML report.

### Cross-Device Comparison (heavy dependencies)
```bash
pip install opencv-python scikit-image imagehash pillow-heif Pillow
python3 contrib/scripts/compare_image_directories.py
```
Computes: MSE, SSIM, PSNR, perceptual hash distance, entropy analysis.

## CI Quality Validation Step

The instrumented.yml workflow includes a built-in quality validation step
that runs after fuzzing. It uses `sips` (macOS built-in) to validate:

1. **File format** — recognized image format (PNG, JPEG, TIFF, etc.)
2. **Dimensions** — valid pixel width and height
3. **File size** — non-zero (empty files indicate failures)

Results appear in the GitHub Actions Step Summary as a per-file table.

## Expected Quality Metrics

### XNU Image Fuzzer Output
- **72+ images** across 12 bitmap contexts × 6 formats
- All files should have non-zero size
- All files should be recognized by `sips`
- Formats: PNG, JPEG, GIF, BMP, TIFF, HEIF

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
| ASAN finding during generation | 🔴 Critical | Memory safety bug in renderer |
| UBSAN finding during generation | 🟡 Medium | Undefined behavior in math |
| Injection string in LSB | ℹ️ Info | Expected for steganography fuzz |
