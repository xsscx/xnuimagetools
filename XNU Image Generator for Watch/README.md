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
