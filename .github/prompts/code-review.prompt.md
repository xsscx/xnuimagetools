---
name: Code Review — XNU Image Tools
description: Review multi-project toolkit for memory safety, correctness, and build issues
---

# Code Review — XNU Image Tools

Review all sub-projects for bugs, memory safety issues, build correctness,
and opportunities to improve fuzzing coverage.

## Sub-Projects to Review

### 1. VideoToolbox Fuzzer (Critical — C/ObjC, manual memory)
**Files**: `VideoToolbox/Fuzzing/videotoolbox-runner.m`, `videotoolbox-interposer.c`,
`runner.c`, `runner_dist.c`, `interpose.c`

#### Checklist
- [ ] All `malloc()` / `calloc()` returns checked for NULL
- [ ] All `CVPixelBufferLockBaseAddress` paired with Unlock
- [ ] All `CMSampleBufferRef` released with `CFRelease`
- [ ] All `CVImageBufferRef` properly retained/released
- [ ] `AVAssetReader` error handling complete
- [ ] `CIContext` and `CGColorSpace` properly released in `save_fuzzed_frame()`
- [ ] No buffer overflows in fuzzing mutation code
- [ ] `timeout` handling — clean exit on SIGALRM
- [ ] CLI argument parsing handles edge cases (-t 0, -t negative, missing file)

### 2. iOS Fuzzer (ObjC, shared with xnuimagefuzzer)
**Files**: `XNU Image Fuzzer/XNU Image Fuzzer/xnuimagefuzzer.m`

#### Checklist
- [ ] All 12 bitmap context functions have NULL checks
- [ ] Memory released on all error paths
- [ ] `CGBitmapInfo` uses explicit casts from `CGImageAlphaInfo`
- [ ] No duplicate `#define` macros
- [ ] Buffer sizes correct for each pixel format depth

### 3. iOS Image Generator (Swift)
**Files**: `XNU Image Generator for iOS/.../ContentView.swift`

#### Checklist
- [ ] Image save operations handle errors
- [ ] File paths properly constructed
- [ ] No force-unwrapping of optionals
- [ ] Memory pressure handled for large image generation

### 4. Watch App (Swift)
**Files**: `XNU Image Generator for Watch/.../ContentView.swift`

#### Checklist
- [ ] Memory constraints respected (watchOS has limited RAM)
- [ ] Image sizes appropriate for watch display
- [ ] Sharing via Transferable protocol works correctly

## Build Verification

### Required Framework Links (VideoToolbox)
The videotoolbox-runner MUST link ALL of these:
```
-framework VideoToolbox
-framework Foundation
-framework AVFoundation
-framework CoreFoundation
-framework CoreMedia
-framework CoreVideo
-framework CoreImage
-framework CoreGraphics  ← CRITICAL: needed for save_fuzzed_frame()
-lz
```

### Makefile Targets
Verify the Makefile builds all targets without errors:
```bash
cd VideoToolbox/Fuzzing && make clean && make all
```

Check iOS targets separately (require iphoneos SDK):
```bash
make videotoolbox-interposer-arm64e.dylib
make videotoolbox-runner.app
```

## Common Bug Patterns

### VideoToolbox
```c
// BAD: CVPixelBuffer lock without unlock on error
CVPixelBufferLockBaseAddress(pixelBuffer, 0);
if (error) return;  // Leaked lock!

// GOOD: Always unlock
CVPixelBufferLockBaseAddress(pixelBuffer, 0);
if (error) {
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return;
}
// ... use pixel buffer ...
CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
```

### CoreGraphics
```objc
// BAD: Missing CoreGraphics framework link
CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();  // Linker error!

// GOOD: Ensure -framework CoreGraphics in build command
```

### Build System
```makefile
# BAD: Duplicate framework
-framework VideoToolbox -framework VideoToolbox

# GOOD: Each framework listed once
-framework VideoToolbox
```
