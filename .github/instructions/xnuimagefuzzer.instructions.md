# xnuimagefuzzer.m — Path-Specific Instructions

## What This Is

A 5,400+-line Objective-C image fuzzer that exercises Apple's CoreGraphics rendering
pipeline through 15 distinct CGBitmapContext configurations, ICC profile variant
generation (4 strategies), structure-aware PNG chunk mutations, and 30+ output format
encodings. Runs on macOS (Mac Catalyst), iOS, iPadOS, watchOS, and visionOS.

## Build

### Xcode (Mac Catalyst — primary)
```bash
xcodebuild -project "XNU Image Fuzzer/XNU Image Fuzzer.xcodeproj" \
  -scheme "XNU Image Fuzzer" \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  SUPPORTS_MACCATALYST=YES build
```

### Native clang (ASAN + UBSAN + Coverage — recommended for CI)
```bash
.github/scripts/build-native.sh
```

### CMake (iOS arm64)
```bash
cd "XNU Image Fuzzer" && cmake -B build -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 && cmake --build build
```

## Architecture — 15 Bitmap Context Types

| # | Function | Pixel Format | Color Space |
|---|----------|-------------|-------------|
| 1 | createBitmapContextStandardRGB | RGBA premultiplied last | DeviceRGB |
| 2 | createBitmapContextPremultipliedFirstAlpha | ARGB premultiplied first | DeviceRGB |
| 3 | createBitmapContextNonPremultipliedAlpha | RGBA straight alpha | DeviceRGB |
| 4 | createBitmapContext16BitDepth | 16-bit per component | DeviceRGB |
| 5 | createBitmapContextGrayscale | 8-bit grayscale | DeviceGray |
| 6 | createBitmapContextHDRFloatComponents | 32-bit float HDR | ExtendedLinearSRGB |
| 7 | createBitmapContextAlphaOnly | Alpha channel only | none |
| 8 | createBitmapContext1BitMonochrome | 1-bit black/white | DeviceGray |
| 9 | createBitmapContextBigEndian | Big-endian 32-bit | DeviceRGB |
| 10 | createBitmapContextLittleEndian | Little-endian 32-bit | DeviceRGB |
| 11 | createBitmapContext8BitInvertedColors | Inverted 8-bit | DeviceRGB |
| 12 | createBitmapContext32BitFloat4Component | RGBA 128-bit float | DeviceRGB |
| 13 | createBitmapContextCMYK | CMYK (RGB fallback) | DeviceCMYK |
| 14 | createBitmapContextHDRFloat16 | IEEE 754 half-precision | ExtendedLinearSRGB |
| 15 | createBitmapContextIndexedColor | 5 palette variants | Indexed/DeviceRGB |

## Output Formats

Each bitmap context generates images in multiple formats plus ICC variants:
- **PNG** — with 6 post-encoding corruption strategies + ICC variants
- **JPEG** — quality 0.8
- **TIFF** — uncompressed, LZW, PackBits, JPEG-in-TIFF, Deflate + ICC variants
- **GIF** — via ImageIO
- **BMP** — via ImageIO
- **HEIF/HEIC** — when hardware encoder available
- **WebP, JP2, DNG, TGA, ASTC, KTX, PDF, ICNS, EXR** — via `encodeImageMultiFormat()`

Total output per run: 15 contexts × 17 seed specs × 6+ formats + ICC variants = **2,000+ images**

## ICC Profile Handling

### ICC Variant Generation (Lines ~2060–2305)

Every `saveFuzzedImage()` call for TIFF/PNG outputs triggers `saveFuzzedImageWithICCVariants()`,
producing up to 4 additional ICC-diverse files:

| Function | Purpose | ICC Source |
|----------|---------|-----------|
| `encodeImageWithICCProfile()` | Inject raw ICC via `kCGImagePropertyICCProfile` | `FUZZ_ICC_DIR` (round-robin) |
| `encodeImageStrippingColorSpace()` | Re-render through DeviceRGB, strip ICC | None (orphan image) |
| `encodeImageWithMismatchedProfile()` | Attach wrong-colorspace ICC header | Synthetic 132-byte header |
| `mutateICCProfile()` + encode | Corrupt real ICC data, then embed | Mutated `FUZZ_ICC_DIR` profile |

### Mismatch Strategies (cycled per call)
1. **CMYK on RGB** — `prtr` class, `CMYK` data space, `Lab` PCS
2. **Gray on RGB** — `mntr` class, `GRAY` data space, `XYZ` PCS
3. **Abstract Lab on RGB** — `abst` class, `Lab` data space, `Lab` PCS
4. **Truncated** — header says 1024 bytes, only 132 present (size mismatch)

All synthetic headers include valid `acsp` magic (offset 36) and D50 PCS illuminant
(offset 68–79) to pass initial parser validation before triggering deep-path errors.

### Legacy Embedding (Lines ~2025–2115)
```objc
// embedICCProfile — loads from FUZZ_ICC_DIR and embeds via CGImageDestination
CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)@{
    (NSString *)kCGImageDestinationEmbedThumbnail: @YES,
    (NSString *)kCGImagePropertyICCProfile: iccData
});
```

### encodeImageMultiFormat ICC Outputs
The multi-format encoder also produces ICC variants:
- `tiff-no-icc.tiff` / `png-no-icc.png` — stripped DeviceRGB
- `tiff-icc-mismatch.tiff` / `png-icc-mismatch.png` — mismatched profiles
- `tiff-cs0.tiff` through `tiff-cs6.tiff` — 7 named Apple color spaces

### Environment Variables for ICC
| Variable | Purpose | Example |
|----------|---------|---------|
| FUZZ_ICC_DIR | Directory of .icc profiles to embed | `test-profiles/` |
| FUZZ_OUTPUT_DIR | Output directory for fuzzed images | `/tmp/fuzzed-output` |
| LLVM_PROFILE_FILE | Coverage profraw output | `output_%m_%p.profraw` |

### Key Insight
**Without `FUZZ_ICC_DIR`**: ICC variants still generate stripped (no-ICC) and mismatched
(CMYK/Gray/Lab/truncated on RGB) files. Only real ICC and mutated ICC variants require
`FUZZ_ICC_DIR`. HDR float contexts (6 and 14) always embed `ExtendedLinearSRGB` ICC
because ImageIO auto-embeds non-standard color spaces.

To maximize ICC profile diversity for CFL fuzzer seeds:
```bash
FUZZ_ICC_DIR=../research/test-profiles FUZZ_OUTPUT_DIR=/tmp/icc-rich ./XNU\ Image\ Fuzzer
```

## Post-Encoding Corruption (PNG)

6 mutation strategies applied after PNG encoding (lines 2200–2400):

1. **IHDR corruption** — modify width/height/color type/bit depth fields
2. **IDAT truncation** — remove trailing bytes from compressed data
3. **CRC invalidation** — flip bits in chunk CRC32 values
4. **Chunk mangling** — corrupt chunk type signatures
5. **Extra chunk injection** — insert random tEXt/iTXt/zTXt chunks
6. **Chunk reordering** — move IDAT before IHDR, swap ancillary chunks

## Memory Management

**ARC enabled** (`CLANG_ENABLE_OBJC_ARC = YES`) — Objective-C objects are automatically
managed. Core Graphics and Core Foundation objects still require explicit release:
```objc
CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
CGContextRef ctx = CGBitmapContextCreate(...);
// ... use context ...
CGContextRelease(ctx);
CGColorSpaceRelease(colorSpace);
```

**Common leak patterns:**
- Missing `CGColorSpaceRelease()` in error paths
- Missing `CGImageRelease()` after `CGBitmapContextCreateImage()`
- Missing `CFRelease()` for `CGImageDestinationRef` and `CFStringRef`
- `@autoreleasepool` blocks required around batch operations
- ICC variant functions must release `CGContextRef`, `CGImageRef`, `CGColorSpaceRef`
  in all early-return paths

## Debugging Environment Variables

| Variable | Purpose |
|----------|---------|
| `CG_VERBOSE=1` | CoreGraphics verbose logging |
| `CG_PDF_VERBOSE=1` | PDF rendering trace |
| `CGBITMAP_CONTEXT_LOG=1` | Bitmap context creation trace |
| `CI_IMAGE_LOG=1` | CoreImage pipeline trace |
| `METAL_DEBUG_ERROR_MODE=0` | Suppress Metal errors |
| `GPU_FRAME_CAPTURE_ENABLE=0` | Disable GPU capture |
| `MTL_SHADER_VALIDATION=0` | Disable Metal validation |

## Integration with CFL Fuzzers

The `extract-icc-seeds.py` bridge script at `contrib/scripts/` connects xnuimagetools
output to the CFL LibFuzzer corpus in the parent research repo:

```bash
# Extract ICC profiles + TIFF files from fuzzed-images
python3 contrib/scripts/extract-icc-seeds.py \
  --input fuzzed-images/ --inject-cfl ../research/cfl

# Targets:
# ICC profiles → profile/dump/deep_dump/toxml fuzzers
# TIFF files   → tiffdump/specsep fuzzers
```

### Seed Value by Bitmap Context

| Context | ICC Value | TIFF Value | ICC Variants | Notes |
|---------|-----------|------------|-------------|-------|
| StandardRGB | Medium | Medium | ✅ All 4 | Most common, ICC variants add diversity |
| HDRFloat | **High** | **High** | ✅ All 4 | ExtendedLinearSRGB ICC auto-embedded |
| HDRFloat16 | **High** | **High** | ✅ All 4 | Half-precision + ICC = rare combo |
| CMYK | **High** | **High** | ✅ All 4 | CMYK ctx + CMYK mismatch ICC = double coverage |
| Grayscale | Medium | **High** | ✅ All 4 | Gray ctx + Gray mismatch ICC = error paths |
| 16BitDepth | Medium | **High** | ✅ All 4 | 16bpc TIFF + ICC exercises depth conversion |
| 32BitFloat4 | Medium | **High** | ✅ All 4 | 128-bit float TIFF + ICC exercises range |
| IndexedColor | Low | Medium | ✅ 2 (PNG) | Palette-based, ICC mismatch useful |
| AlphaOnly | Low | Low | ❌ No TIFF | Alpha-only, limited ICC relevance |
| 1BitMonochrome | Low | Medium | ✅ All 4 | Monochrome + RGB ICC = interesting mismatch |

## Testing

```bash
# Validate output integrity (Python — requires pillow, numpy)
python3 contrib/scripts/validate_fuzzed_images.py fuzzed-images/

# Magic byte verification
python3 contrib/scripts/read-magic-numbers.py fuzzed-images/

# Cross-device comparison (compare runs from different hardware)
python3 contrib/scripts/compare_image_directories.py \
  fuzzed-images/2026-03-02-iPhone/ fuzzed-images/2026-03-02-iPad/

# Feed into macOS system tools for crash detection
./fuzz-apps.sh fuzzed-images/latest/ --timeout 15
```

## Common Pitfalls

- **Mac Catalyst**: Cannot use `CLANG_ENABLE_CODE_COVERAGE=YES` — use native clang build
- **SIGPIPE**: Never pipe macOS tool output to `head` in CI — use `tee` + `head` instead
- **LLVM profraw**: Use `dlsym()` to resolve `__llvm_profile_write_file`, not weak extern
- **VideoToolbox ASAN**: 10–50× slower than non-ASAN; use short inputs and increase timeouts
- **CGColorSpaceCreateDeviceCMYK**: Falls back to RGB on some devices — always test both paths
