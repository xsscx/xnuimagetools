# XNU Image Tools

## Workspace Summary

XNU Image Tools is a multi-platform image output tool designed to ensure consistency, compatibility, and quality across different devices and platforms. By starting with a baseline image and generating platform-specific outputs, this tool allows for comprehensive testing and optimization.

When these baseline images are subsequently input into fuzzing tools like XNU Image Fuzzer, Jackalope, or AFL, it is possible to identify platform-specific vulnerabilities, bugs, and other unpredictable behaviors. 

Fuzzing with pre-processed images that contain fine-grained, user-controllable inputs significantly increases the effective coverage envelope for a fault injection campaign.

## Overview

XNU Image Tools provides custom image generation and fuzz testing within XNU environments. The Workspace currently comprises two main components:
1. **XNU Image Generation Apps**: This includes iOS and Apple Watch apps for generating and sharing unique images in various formats.
2. **XNU Image Fuzzer**: A proof of concept implementation of an image fuzzer aimed at uncovering potential vulnerabilities in image processing routines.

### Reproduction for iPhone, Mac and Vision Pro

<img src="https://xss.cx/2024/05/26/img/xnuimagetools_ios-filmstrip.jpg" alt="XNU Image Tools iOS Example Output" style="height:286px; width:818px;"/>

### Reproduction for WatchOS

<img src="https://xss.cx/2024/05/26/img/xnuimagetools_watchos-filmstrip.jpg" alt="XNU Image Fuzzer OSS Project" style="height:286px; width:818px;"/>

### Build & Install Status

| Build OS & Device Info | Build | Install |
|------------------------|-------|---------|
| macOS 14.5 X86_64      | ✅     | ✅       |
| macOS 14.5 arm         | ✅     | ✅       |
| iPadOS 17.5            | ✅     | ✅       |
| iPhoneOS 17.5         | ✅     | ✅       |
| VisionPro 1.2          | ✅     | ✅       |
| watchOS 10.5           | ✅     | ✅       |

## Components

### 1. XNU Image Generation Apps

#### Features

- **iOS App**:
  - Generate different images by changing the code.
  - Browse and select the generated images.
  - Share images through built-in Share Sheet.
  
- **Apple Watch App**:
  - View generated images.
  - Select and share images directly from your wrist.

#### Requirements

- macOS 14.5 or later
- iOS 17.5 or later
- watchOS 10.5 or later
- Xcode 15.0 or later
- Swift 5.10 or later

#### Installation

1. **Open in Xcode**
   - Open \`XNU Image Tools.xcworkspace\` in Xcode.
   - Update the Team ID
   - Select the appropriate scheme for the iOS or watchOS app.
   - Build and run the app on your desired device.

#### Usage

- **iOS App**:
  1. Launch the iOS app.
  2. Tap the "Generate" button to create new images.
  3. Browse and share the generated images via AirDrop.

- **Apple Watch App**:
  1. Launch the Watch app.
  2. Scroll through the list of generated images.
  3. tap and share images directly from the Watch.

### 2. XNU Image Fuzzer

#### Project Summary

The XNU Image Fuzzer demonstrates basic fuzzing techniques on image data to uncover potential vulnerabilities in image processing routines. It includes Objective-C code implementing 12 \`CGCreateBitmap\` and \`CGColorSpace\` functions working with raw data and string injections as user-controllable inputs.

#### PermaLink

[https://srd.cx/xnu-image-fuzzer/](https://srd.cx/xnu-image-fuzzer/)

#### Project Support

- Open an Issue

#### Quick Start

1. **Open as Xcode Project**
2. **Update the Team ID**
3. **Click Run**

4. **Share a File**
   - Copy fuzzed files.
   - Open the Files app on the device.
   - Tap Share to transfer the new fuzzed images to your desktop.
   - Select all files to AirDrop to your desktop.

<img src="https://xss.cx/2024/02/26/img/xnuimagefuzzer-arm64e-sample-output-files_app-sample-file-render-iphone14promax-001.png" alt="XNU Image Fuzzer iPhone 14 Pro Max Render #1" style="height:550px; width:330px;"/> <img src="https://xss.cx/2024/02/26/img/xnuimagefuzzer-arm64e-sample-output-files_app-sample-file-render-iphone14promax-002.png" alt="XNU Image Fuzzer iPhone 14 Pro Max Render #2" style="height:550px; width:330px;"/> 

## Purpose of Using Fuzzed Images in Fuzzing

### Overview
Embedding fault mechanisms into a generic image and further processing it through fuzzing enhances the effectiveness of testing by uncovering edge cases and potential vulnerabilities in image processing software.

### Benefits

#### Uncovering Edge Cases
- **Insight:** Fuzzed images introduce a wide range of potential edge cases.
- **Analysis:** Helps uncover rare bugs and vulnerabilities that might only occur with specific, unanticipated inputs.

#### Testing Robustness and Stability
- **Insight:** Stress-tests the robustness of image processing algorithms.
- **Analysis:** Ensures the software can handle diverse and unexpected inputs without crashing or producing incorrect results.

#### Finding Security Vulnerabilities
- **Insight:** Targets specific vulnerabilities through fault injections.
- **Analysis:** Exposes security weaknesses, such as buffer overflows, by providing inputs that cause unexpected behavior.

#### Ensuring Compatibility with Various Formats
- **Insight:** Tests the software's ability to handle different image formats and types.
- **Analysis:** Reduces the risk of compatibility issues by providing comprehensive testing coverage.

#### Automating the Testing Process
- **Insight:** Integrates with automated fuzzing frameworks like Jackalope.
- **Analysis:** Enables continuous and scalable testing, improving software robustness over time.

### Process
1. **Prepare the Image:**
   - Start with a generic image.
   - Apply initial fuzzing to introduce random mutations.
   - Embed specific fault mechanisms to target vulnerabilities.
2. **Submit to Fuzzing Harness:**
   - Load the processed image into a fuzzing framework like Jackalope.
   - Configure the tool to use the image as a seed for further automated fuzzing.
3. **Monitor and Analyze:**
   - Monitor for crashes, hangs, and other signs of vulnerabilities.
   - Collect and analyze the results to identify and understand the bugs found.
