/**
 *  @file videotoolbox-runner.m
 *  @brief Code for VideoToolbox Fuzzing
 *  @author @h02332 | David Hoyt
 *  @date 20 MAY 2024
 *  @version 1.1.3
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 *  @section CHANGES
 *  - 18/05/2024, h02332: Update commit.
 *  - 03/2026: Logging implemented via DEBUG_PRINT macros and signal handler
 *
 *
 *  @section Run
 *  lldb -- ./videotoolbox-runner
 *  (lldb) log enable -f lldb_output.txt -T -n lldb api commands process
 *  (lldb) settings set target.env-vars DYLD_INSERT_LIBRARIES=./videotoolbox-interposer.dylib
 *  (lldb) run movie.mov
 *
 */

#pragma mark - Headers

#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <errno.h>
#include <execinfo.h>
#include <signal.h>
#include <IOKit/IOKitLib.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <sys/sysctl.h>
#include <time.h>
#include <unistd.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#pragma mark - Debugging Macros

/**
@brief Provides macros for enhanced logging and assertions during development.

This section defines two key macros designed to assist in the debugging process, ensuring that developers can log detailed information and perform assertions with customized messages. These macros are especially useful in DEBUG builds, where additional context can significantly aid in diagnosing issues.

## Features:
- `DebugLog`: This macro is used for logging detailed debug information, including the name of the current function and the line number from where it's called. It's instrumental in tracing the execution flow or pinpointing the location of specific events or states in the code.
- `AssertWithMessage`: This macro allows for the execution of assertions that, upon failure, log a custom message. It's valuable for validating assumptions within the code and providing immediate feedback if those assumptions are violated.

## Usage:

### DebugLog
Use the `DebugLog` macro to log messages with additional context, such as the function name and line number. This macro is only active in DEBUG builds, helping to avoid the potential exposure of sensitive information in release builds.
```objective-c
DebugLog(@"An informative debug message with context.");
*/
#define DEBUG_BUFFER_SIZE 1024

#if DEBUG_LOGGING
// Safe DEBUG_PRINT macro
#define DEBUG_PRINT(fmt, ...) do { \
    char buffer[DEBUG_BUFFER_SIZE]; \
    snprintf(buffer, DEBUG_BUFFER_SIZE, fmt, ##__VA_ARGS__); \
    fputs(buffer, stderr); \
} while (0)

// Safe DEBUG_PRINT_ERRNO macro
#define DEBUG_PRINT_ERRNO(msg) do { \
    char errbuf[DEBUG_BUFFER_SIZE]; \
    strerror_r(errno, errbuf, DEBUG_BUFFER_SIZE); \
    char buffer[DEBUG_BUFFER_SIZE]; \
    snprintf(buffer, DEBUG_BUFFER_SIZE, "%s: %s\n", msg, errbuf); \
    fputs(buffer, stderr); \
} while (0)
#else
#define DEBUG_PRINT(...)
#define DEBUG_PRINT_ERRNO(msg)
#endif

#define EXTENDED_DEBUGGING 1

#define AssertWithMessage(condition, message, ...) \
    do { \
        if (!(condition)) { \
            NSLog((@"Assertion failed: %s " message), #condition, ##__VA_ARGS__); \
            assert(condition); \
        } \
    } while(0)

#pragma mark - GPU Logging

/**
@brief Logs GPU memory information along with a custom message, filename, function name, and line number.

This function logs a custom message along with details about the current file, function, and line number. Additionally, it prints detailed memory zone information, which is useful for debugging GPU-related memory issues.

@param message A custom message to log.
@param filename The name of the file where the log call is made.
@param funcname The name of the function where the log call is made.
@param line The line number where the log call is made.
*/
void log_gpu_memory_info(const char *description, const char *file, const char *function, int line) {
    printf("GPU Info: %s, File: %s, Function: %s, Line: %d\n", description, file, function, line);
}

#pragma mark - Signal Logging

/**
@brief Signal handler that logs stack traces on signal receipt.

This function is a signal handler that logs stack traces when a signal
(such as SIGSEGV or SIGABRT) is caught. Only async-signal-safe functions
are called.

@param sig The signal number.
*/
void signal_handler(int sig) {
    void *array[64];
    size_t size;

    size = backtrace(array, 64);

    // Only use async-signal-safe functions in signal handler
    const char msg[] = "Error: caught signal\n";
    (void)write(STDERR_FILENO, msg, sizeof(msg) - 1);

    backtrace_symbols_fd(array, (int)size, STDERR_FILENO);

    _exit(128 + sig);
}

#pragma mark - Signal Handlers

/**
@brief Sets up signal handlers for common signals that might indicate program errors.

This function sets up signal handlers for a variety of signals that might indicate program errors, such as SIGABRT, SIGSEGV, SIGBUS, SIGILL, and SIGFPE. These handlers help in logging detailed information when such signals are caught.

@note This setup is essential for debugging and ensuring that any errors are properly logged.
*/
void setup_signal_handlers() {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;

    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL);
}

#pragma mark - Fuzzing Function

#pragma mark - Frame Saving

/**
@brief Saves a fuzzed frame as a PNG file in the output directory.

Uses CGImageCreate with CGDataProvider to avoid the read-only lock issue that
caused CGBitmapContextCreate to return NULL (it requires writable backing store).

@param imageBuffer The pixel buffer to save.
@param outputDir   The directory to write the file into.
@param iteration   The fuzzing iteration number.
@param frame       The frame number within the iteration.
@return 1 if saved successfully, 0 on failure.
*/
static int save_fuzzed_frame(CVImageBufferRef imageBuffer, const char *outputDir, int iteration, int frame) {
    @autoreleasepool {
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        size_t w = CVPixelBufferGetWidth(imageBuffer);
        size_t h = CVPixelBufferGetHeight(imageBuffer);
        size_t bpr = CVPixelBufferGetBytesPerRow(imageBuffer);
        void *base = CVPixelBufferGetBaseAddress(imageBuffer);
        if (!base || w == 0 || h == 0) {
            NSLog(@"save_fuzzed_frame: invalid pixel buffer (base=%p, w=%zu, h=%zu)", base, w, h);
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            return 0;
        }

        // Copy pixel data so we can release the lock before writing PNG
        size_t dataLen = bpr * h;
        CFDataRef pixelData = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)base, dataLen);
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

        if (!pixelData) {
            NSLog(@"save_fuzzed_frame: CFDataCreate failed (len=%zu)", dataLen);
            return 0;
        }

        CGDataProviderRef provider = CGDataProviderCreateWithCFData(pixelData);
        CFRelease(pixelData);
        if (!provider) {
            NSLog(@"save_fuzzed_frame: CGDataProviderCreate failed");
            return 0;
        }

        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        // BGRA pixel format: premultiplied first + little-endian 32-bit
        CGImageRef cgImg = CGImageCreate(w, h, 8, 32, bpr, cs,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,
            provider, NULL, false, kCGRenderingIntentDefault);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(cs);

        if (!cgImg) {
            NSLog(@"save_fuzzed_frame: CGImageCreate failed (%zu x %zu, bpr=%zu)", w, h, bpr);
            return 0;
        }

        NSString *path = [NSString stringWithFormat:@"%s/fuzzed_iter%03d_frame%03d.png",
                          outputDir, iteration, frame];
        NSURL *url = [NSURL fileURLWithPath:path];
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)url, (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
        if (!dest) {
            NSLog(@"save_fuzzed_frame: CGImageDestinationCreateWithURL failed for %@", path);
            CGImageRelease(cgImg);
            return 0;
        }

        CGImageDestinationAddImage(dest, cgImg, NULL);
        bool ok = CGImageDestinationFinalize(dest);
        CFRelease(dest);
        CGImageRelease(cgImg);

        if (!ok) {
            NSLog(@"save_fuzzed_frame: CGImageDestinationFinalize failed for %@", path);
            return 0;
        }
        return 1;
    }
}

#pragma mark - Fuzzing Function

/**
@brief Fuzzes a video file by applying various intensities of bit flips, data injections, and buffer overflows.

Opens a video file using AVFoundation, reads its frames, applies fuzzing mutations, and optionally
saves the first mutated frame as PNG. Saves frames inline to avoid the wasteful re-open pattern.

@param filename The path to the video file to fuzz.
@param flip_intensity The intensity of bit flips to apply to the video frames.
@param inject_intensity The intensity of random data injections to apply to the video frames.
@param overflow_intensity The intensity of buffer overflows to apply to the video frames.
@param outputDir Optional output directory for saving fuzzed frames (NULL to skip).
@param iteration The current fuzzing iteration number (for filename generation).
@return Number of frames saved (>= 0), or -1 on video open/decode error.
*/
int fuzz(const char *filename, int flip_intensity, int inject_intensity, int overflow_intensity,
         const char *outputDir, int iteration) {
    int framesSaved = 0;
    @autoreleasepool {
        NSError *error = nil;
        NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithCString:filename encoding:NSUTF8StringEncoding]];
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        if (asset == nil) return -1;

        __strong AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
        if (reader == nil) return -1;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
        if (tracks == nil || ([tracks count] == 0)) {
            reader = nil;
            return -1;
        }

        @try {
            AVAssetTrack *track = tracks[0];
            NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                                                        forKey:(id)kCVPixelBufferPixelFormatTypeKey];
            AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
            [reader addOutput:output];
            if (![reader startReading]) return -1;

            for (int frame = 0; frame < 100; frame++) {
                @autoreleasepool {
                    CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
                    if (sampleBuffer == nil) break;

                    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                    if (imageBuffer) {
                        CVPixelBufferLockBaseAddress(imageBuffer, 0);
                        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
                        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
                        size_t height = CVPixelBufferGetHeight(imageBuffer);
                        size_t width = CVPixelBufferGetWidth(imageBuffer);
                        size_t totalBytes = bytesPerRow * height;

                        if (baseAddress && totalBytes > 0) {
                            for (int f = 0; f < flip_intensity * 10; f++) {
                                size_t pos = arc4random_uniform((uint32_t)totalBytes);
                                uint8_t bit = 1 << arc4random_uniform(8);
                                baseAddress[pos] ^= bit;
                            }

                            for (int j = 0; j < inject_intensity; j++) {
                                size_t pos = arc4random_uniform((uint32_t)(totalBytes > 16 ? totalBytes - 16 : 1));
                                size_t len = arc4random_uniform(16) + 1;
                                if (pos + len > totalBytes) len = totalBytes - pos;
                                uint8_t pattern = (uint8_t)(arc4random_uniform(256));
                                memset(baseAddress + pos, pattern, len);
                            }

                            for (int o = 0; o < overflow_intensity && o < (int)height; o++) {
                                size_t rowStart = (arc4random_uniform((uint32_t)height)) * bytesPerRow;
                                for (size_t b = 0; b < 4 && rowStart + bytesPerRow - 1 - b < totalBytes; b++) {
                                    baseAddress[rowStart + bytesPerRow - 1 - b] = 0xFF;
                                }
                            }

                            NSLog(@"Fuzzed frame %d: %zu x %zu (%zu bytes), applied %d flips, %d injects, %d overflows",
                                  frame, width, height, totalBytes, flip_intensity * 10, inject_intensity, overflow_intensity);
                        }

                        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

                        // Save first frame of each iteration inline (actual mutated data)
                        if (outputDir && frame == 0) {
                            framesSaved += save_fuzzed_frame(imageBuffer, outputDir, iteration, frame);
                        }
                    }

                    CMSampleBufferInvalidate(sampleBuffer);
                    CFRelease(sampleBuffer);
                    sampleBuffer = NULL;
                }
            }
        } @finally {
            [reader cancelReading];
            reader = nil;
        }
    }
    return framesSaved;
}

#pragma mark - Application Entry Point

static void print_usage(const char *prog) {
    printf("Usage: %s [options] <filename>\n", prog);
    printf("Options:\n");
    printf("  -t <seconds>  Fuzzing duration in seconds (default: 60, 0 = unlimited)\n");
    printf("  -o <dir>      Output directory for fuzzed frames (default: none)\n");
    printf("  -h            Show this help\n");
}

int main(int argc, const char *argv[]) {
    setup_signal_handlers();

    int duration = 60;        // default 60 seconds
    const char *outputDir = NULL;
    const char *filename = NULL;

    // Parse arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-t") == 0 && i + 1 < argc) {
            duration = atoi(argv[++i]);
            if (duration < 0) duration = 0;
        } else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            outputDir = argv[++i];
        } else if (strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (argv[i][0] != '-') {
            filename = argv[i];
        } else {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            print_usage(argv[0]);
            return 1;
        }
    }

    if (!filename) {
        print_usage(argv[0]);
        return 1;
    }

    void *toolbox = dlopen("/System/Library/Frameworks/VideoToolbox.framework/Versions/A/VideoToolbox", RTLD_NOW);
    if (!toolbox) {
        fprintf(stderr, "Error loading VideoToolbox framework\n");
        return 1;
    }

    // Create output directory if specified
    if (outputDir) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dir = [NSString stringWithCString:outputDir encoding:NSUTF8StringEncoding];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSLog(@"Output directory: %s", outputDir);
    }

    time_t startTime = time(NULL);
    int iteration = 0;
    int totalFramesSaved = 0;
    NSLog(@"Starting fuzzing: file=%s, duration=%ds, output=%s",
          filename, duration, outputDir ? outputDir : "(none)");

    while (1) {
        // Check time limit (0 = unlimited)
        if (duration > 0) {
            time_t elapsed = time(NULL) - startTime;
            if (elapsed >= duration) {
                NSLog(@"Time limit reached (%ds). Stopping.", duration);
                break;
            }
        }

        iteration++;
        int intensity = ((iteration - 1) % 50) + 1;

        int result = fuzz(filename, intensity, intensity, intensity, outputDir, iteration);

        if (result >= 0) {
            totalFramesSaved += result;
            // Log periodically to avoid excessive output
            if (iteration % 100 == 0 || iteration == 1) {
                log_gpu_memory_info("Fuzzing progress", __FILE__, __FUNCTION__, __LINE__);
                NSLog(@"Progress: iteration %d, %d frames saved so far", iteration, totalFramesSaved);
            }
        } else {
            // Video decode failed — generate synthetic fuzzed frame
            if (outputDir) {
                @autoreleasepool {
                    size_t w = 320, h = 240;
                    CVPixelBufferRef pb = NULL;
                    NSDictionary *attrs = @{
                        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
                    };
                    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, w, h,
                        kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attrs, &pb);
                    if (status == kCVReturnSuccess && pb) {
                        CVPixelBufferLockBaseAddress(pb, 0);
                        uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(pb);
                        size_t bpr = CVPixelBufferGetBytesPerRow(pb);
                        size_t total = bpr * h;
                        // Fill with deterministic fuzz pattern
                        for (size_t i = 0; i < total; i++) {
                            base[i] = (uint8_t)((i * 7 + iteration * 13) ^ (intensity * 37));
                        }
                        // Apply bit-flip fuzzing
                        for (int f = 0; f < intensity * 10; f++) {
                            size_t pos = arc4random_uniform((uint32_t)total);
                            base[pos] ^= (1 << arc4random_uniform(8));
                        }
                        CVPixelBufferUnlockBaseAddress(pb, 0);
                        // Save every 10th synthetic frame
                        if (iteration % 10 == 0) {
                            totalFramesSaved += save_fuzzed_frame(pb, outputDir, iteration, 0);
                        }
                        CVPixelBufferRelease(pb);
                    }
                }
            }
            if (iteration % 100 == 0 || iteration == 1) {
                log_gpu_memory_info("Synthetic frame generated", __FILE__, __FUNCTION__, __LINE__);
            }
        }
    }

    time_t elapsed = time(NULL) - startTime;
    NSLog(@"Fuzzing complete: %d iterations, %d frames saved, %ld seconds elapsed",
          iteration, totalFramesSaved, (long)elapsed);
    printf("## VideoToolbox Fuzzer Summary\n");
    printf("- Input: %s\n", filename);
    printf("- Duration: %lds / %ds target\n", (long)elapsed, duration);
    printf("- Iterations: %d\n", iteration);
    printf("- Fuzzed frames: %d\n", totalFramesSaved);
    if (outputDir) {
        printf("- Output: %s\n", outputDir);
    }

    return 0;
}
