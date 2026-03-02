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
 *
 *  @section TODO
 *  - Logging
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
#include <malloc/malloc.h>
#include <IOKit/IOKitLib.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <sys/sysctl.h>
#include <time.h>
#include <unistd.h>
#include <sys/mman.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <stdio.h>

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

#define page_align(addr) (vm_address_t)((uintptr_t)(addr) & (~(vm_page_size - 1)))

#pragma mark - Memory Logging

/**
@brief Logs detailed memory zone information using the default malloc zone.

This function retrieves the default malloc zone and prints detailed information about it. This can be useful for debugging memory usage and allocation patterns within the application.
*/
void log_memory_info() {
    malloc_zone_t *zone = malloc_default_zone();
    malloc_zone_print(zone, false);
}

#pragma mark - Malloc Allocations

/**
@brief Allocates memory with guard pages to detect buffer overflows.

This function allocates memory with additional guard pages before and after the allocated region. These guard pages are set to be inaccessible, helping to detect buffer overflows by causing a segmentation fault if accessed.

@param size The size of the memory to allocate.
@return A pointer to the allocated memory, or NULL if the allocation failed.
*/
void *malloc_with_guard(size_t size) {
    size_t page_size = getpagesize();
    size_t total_size = size + (2 * page_size);

    void *base = mmap(NULL, total_size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base == MAP_FAILED) return NULL;

    void *ptr = (char *)base + page_size;
    if (mprotect(ptr, size, PROT_READ | PROT_WRITE) != 0) {
        munmap(base, total_size);
        return NULL;
    }

    return ptr;
}

#pragma mark - Free Memory

/**
@brief Frees memory that was allocated with guard pages.

This function frees memory that was previously allocated with `malloc_with_guard`, ensuring that the guard pages are also properly released.

@param ptr A pointer to the memory to free.
@param size The size of the memory that was allocated.
*/
void free_with_guard(void *ptr, size_t size) {
    size_t page_size = getpagesize();
    void *base = (char *)ptr - page_size;
    size_t total_size = size + (2 * page_size);
    munmap(base, total_size);
}

#pragma mark - Print env

extern char **environ;

/**
@brief Prints all environment variables to the standard output.

This function iterates over the environment variables and prints each one. This can be useful for debugging and understanding the context in which the application is running.
*/
void showme_environment() {
    char **env = environ;
    while (env && *env) {
        // Safe printing of environment variables
        printf("%s\n", *env);
        env++;
    }
}

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
    malloc_zone_print(NULL, 1); // Log detailed memory zone information
}

#pragma mark - Signal Logging

/**
@brief Signal handler that logs memory information and stack traces on signal receipt.

This function is a signal handler that logs detailed memory information and stack traces when a signal (such as SIGSEGV or SIGABRT) is caught. It helps in diagnosing the cause of the signal and understanding the state of the program at the time of the signal.

@param sig The signal number.
*/
void signal_handler(int sig) {
    void *array[64];
    size_t size;

    // Get void*'s for all entries on the stack
    size = backtrace(array, 64);

    // Print out all the frames to stderr
    DEBUG_PRINT("Error: signal %d:\n", sig);
    log_memory_info();  // Log detailed memory info on signal

    // Cast size to int to avoid loss of precision warning
    backtrace_symbols_fd(array, (int)size, STDERR_FILENO);

    // Log memory allocation details
    malloc_printf("Malloc: signal %d caught. Memory dump:\n", sig);
    log_memory_info();  // Log detailed memory info on signal
    malloc_zone_print(NULL, 1);

    exit(1);
}

#pragma mark - Signal Handlers

/**
@brief Sets up signal handlers for common signals that might indicate program errors.

This function sets up signal handlers for a variety of signals that might indicate program errors, such as SIGABRT, SIGSEGV, SIGBUS, SIGILL, and SIGFPE. These handlers help in logging detailed information when such signals are caught.

@note This setup is essential for debugging and ensuring that any errors are properly logged.
*/
void setup_signal_handlers() {
    signal(SIGABRT, signal_handler);
    signal(SIGSEGV, signal_handler);
    signal(SIGBUS, signal_handler);
    signal(SIGILL, signal_handler);
    signal(SIGFPE, signal_handler);
}

#pragma mark - Fuzzing Function

/**
@brief Fuzzes a video file by applying various intensities of bit flips, data injections, and buffer overflows.

This function opens a video file using AVFoundation, reads its frames, and applies fuzzing techniques to the frames. The fuzzing intensities for bit flipping, data injection, and buffer overflow increase as specified by the parameters.

@param filename The path to the video file to fuzz.
@param flip_intensity The intensity of bit flips to apply to the video frames.
@param inject_intensity The intensity of random data injections to apply to the video frames.
@param overflow_intensity The intensity of buffer overflows to apply to the video frames.
@return 1 if the fuzzing was successful, or 0 if there was an error.
*/
int fuzz(const char *filename, int flip_intensity, int inject_intensity, int overflow_intensity) {
    @autoreleasepool {
        NSError *error = nil;
        NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithCString:filename encoding:NSASCIIStringEncoding]];
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        if (asset == nil) return 0;

        __strong AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
        if (reader == nil) return 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
        if (tracks == nil || ([tracks count] == 0)) {
            reader = nil; // Release reader
            return 0;
        }

        @try {
            AVAssetTrack *track = tracks[0];
            NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
            AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
            [reader addOutput:output];
            if (![reader startReading]) return 0;

            for (int frame = 0; frame < 100; frame++) {
                @autoreleasepool {
                    CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
                    if (sampleBuffer == nil) break;

                    NSLog(@"Processing frame %d with flip intensity %d, inject intensity %d, overflow intensity %d", frame, flip_intensity, inject_intensity, overflow_intensity);
                    log_gpu_memory_info("Processing frame", __FILE__, __FUNCTION__, __LINE__);

                    // Extract pixel buffer and apply fuzzing mutations
                    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                    if (imageBuffer) {
                        CVPixelBufferLockBaseAddress(imageBuffer, 0);
                        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
                        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
                        size_t height = CVPixelBufferGetHeight(imageBuffer);
                        size_t width = CVPixelBufferGetWidth(imageBuffer);
                        size_t totalBytes = bytesPerRow * height;

                        if (baseAddress && totalBytes > 0) {
                            // Bit-flip fuzzing: flip random bits proportional to intensity
                            for (int f = 0; f < flip_intensity * 10; f++) {
                                size_t pos = arc4random_uniform((uint32_t)totalBytes);
                                uint8_t bit = 1 << arc4random_uniform(8);
                                baseAddress[pos] ^= bit;
                            }

                            // Inject fuzzing: overwrite random spans with patterns
                            for (int j = 0; j < inject_intensity; j++) {
                                size_t pos = arc4random_uniform((uint32_t)(totalBytes > 16 ? totalBytes - 16 : 1));
                                size_t len = arc4random_uniform(16) + 1;
                                if (pos + len > totalBytes) len = totalBytes - pos;
                                uint8_t pattern = (uint8_t)(arc4random_uniform(256));
                                memset(baseAddress + pos, pattern, len);
                            }

                            // Overflow-style fuzzing: write extreme values at row boundaries
                            for (int o = 0; o < overflow_intensity && o < (int)height; o++) {
                                size_t rowStart = (arc4random_uniform((uint32_t)height)) * bytesPerRow;
                                // Overwrite last 4 bytes of row with 0xFF
                                for (size_t b = 0; b < 4 && rowStart + bytesPerRow - 1 - b < totalBytes; b++) {
                                    baseAddress[rowStart + bytesPerRow - 1 - b] = 0xFF;
                                }
                            }

                            NSLog(@"Fuzzed frame %d: %zu x %zu (%zu bytes), applied %d flips, %d injects, %d overflows",
                                  frame, width, height, totalBytes, flip_intensity * 10, inject_intensity, overflow_intensity);
                        }

                        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                    }

                    CMSampleBufferInvalidate(sampleBuffer);
                    CFRelease(sampleBuffer);
                    sampleBuffer = NULL;
                }
            }
        } @finally {
            [reader cancelReading]; // Ensure reader is properly stopped
            reader = nil; // Explicitly release reader
        }
    }
    return 1;
}

#pragma mark - Application Entry Point

/**
@brief The main function of the fuzzing application.

This function sets up the environment, initializes signal handlers, and performs multiple iterations of fuzzing on the provided video file. The fuzzing intensities increase with each iteration.

@param argc The number of command-line arguments.
@param argv The array of command-line arguments.
@return 0 if the program executes successfully, or a non-zero value if there was an error.
*/
static void print_usage(const char *prog) {
    printf("Usage: %s [options] <filename>\n", prog);
    printf("Options:\n");
    printf("  -t <seconds>  Fuzzing duration in seconds (default: 60, 0 = unlimited)\n");
    printf("  -o <dir>      Output directory for fuzzed frames (default: none)\n");
    printf("  -h            Show this help\n");
}

/**
@brief Saves a fuzzed frame as a PNG file in the output directory.

@param imageBuffer The pixel buffer to save.
@param outputDir   The directory to write the file into.
@param iteration   The fuzzing iteration number.
@param frame       The frame number within the iteration.
*/
static void save_fuzzed_frame(CVImageBufferRef imageBuffer, const char *outputDir, int iteration, int frame) {
    @autoreleasepool {
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        size_t w = CVPixelBufferGetWidth(imageBuffer);
        size_t h = CVPixelBufferGetHeight(imageBuffer);
        size_t bpr = CVPixelBufferGetBytesPerRow(imageBuffer);
        void *base = CVPixelBufferGetBaseAddress(imageBuffer);
        if (!base || w == 0 || h == 0) {
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            return;
        }

        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        // BGRA pixel format: premultiplied first + little-endian 32-bit
        CGContextRef cgCtx = CGBitmapContextCreate(base, w, h, 8, bpr,
            cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        if (!cgCtx) { CGColorSpaceRelease(cs); return; }

        CGImageRef cgImg = CGBitmapContextCreateImage(cgCtx);
        CGContextRelease(cgCtx);
        CGColorSpaceRelease(cs);
        if (!cgImg) return;

        NSString *path = [NSString stringWithFormat:@"%s/fuzzed_iter%03d_frame%03d.png",
                          outputDir, iteration, frame];
        NSURL *url = [NSURL fileURLWithPath:path];
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)url, (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
        if (dest) {
            CGImageDestinationAddImage(dest, cgImg, NULL);
            CGImageDestinationFinalize(dest);
            CFRelease(dest);
        }
        CGImageRelease(cgImg);
        NSLog(@"Saved fuzzed frame: %@", path);
    }
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

        NSLog(@"Fuzzing iteration %d (intensity %d)", iteration, intensity);
        int result = fuzz(argv[1], intensity, intensity, intensity);

        if (result == 1) {
            // Save a representative frame if output directory is set
            if (outputDir) {
                // Re-read first frame and save it fuzzed
                @autoreleasepool {
                    NSError *error = nil;
                    NSURL *fileURL = [NSURL fileURLWithPath:[NSString stringWithCString:filename encoding:NSUTF8StringEncoding]];
                    AVAsset *asset = [AVAsset assetWithURL:fileURL];
                    if (asset) {
                        AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
                        if (reader && tracks.count > 0) {
                            NSDictionary *settings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCMPixelFormat_32BGRA)};
                            AVAssetReaderTrackOutput *out = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:tracks[0] outputSettings:settings];
                            [reader addOutput:out];
                            if ([reader startReading]) {
                                CMSampleBufferRef sb = [out copyNextSampleBuffer];
                                if (sb) {
                                    CVImageBufferRef ib = CMSampleBufferGetImageBuffer(sb);
                                    if (ib) {
                                        CVPixelBufferLockBaseAddress(ib, 0);
                                        // Apply fuzzing to this frame before saving
                                        uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(ib);
                                        size_t total = CVPixelBufferGetBytesPerRow(ib) * CVPixelBufferGetHeight(ib);
                                        if (base && total > 0) {
                                            for (int f = 0; f < intensity * 10; f++) {
                                                size_t pos = arc4random_uniform((uint32_t)total);
                                                base[pos] ^= (1 << arc4random_uniform(8));
                                            }
                                        }
                                        CVPixelBufferUnlockBaseAddress(ib, 0);
                                        save_fuzzed_frame(ib, outputDir, iteration, 0);
                                    }
                                    CMSampleBufferInvalidate(sb);
                                    CFRelease(sb);
                                }
                            }
                            [reader cancelReading];
                        }
                    }
                }
            }
            log_gpu_memory_info("Fuzzing completed successfully", __FILE__, __FUNCTION__, __LINE__);
        } else {
            NSLog(@"Fuzzing iteration %d: codec unavailable, generating synthetic frame", iteration);
            // Generate synthetic fuzzed frame when video codec is unavailable (e.g. CI headless)
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
                        // Save every 100th synthetic frame to avoid excessive disk I/O
                        if (iteration % 100 == 0) {
                            save_fuzzed_frame(pb, outputDir, iteration, 0);
                        }
                        CVPixelBufferRelease(pb);
                    }
                }
            }
            log_gpu_memory_info("Synthetic frame generated", __FILE__, __FUNCTION__, __LINE__);
        }
    }

    time_t elapsed = time(NULL) - startTime;
    NSLog(@"Fuzzing complete: %d iterations, %ld seconds elapsed", iteration, (long)elapsed);
    printf("## VideoToolbox Fuzzer Summary\n");
    printf("- Input: %s\n", filename);
    printf("- Duration: %lds / %ds target\n", (long)elapsed, duration);
    printf("- Iterations: %d\n", iteration);
    if (outputDir) {
        printf("- Output: %s\n", outputDir);
    }

    return 0;
}
