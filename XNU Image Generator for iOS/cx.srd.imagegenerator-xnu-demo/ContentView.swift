/**
 *  @file ContentView.swift
 *  @brief XNU Image Generator for iOS
 *  @author @h02332 | David Hoyt | @xsscx
 *  @date 08 MAR 2026
 *  @version 1.8.0
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
 *  - 21/05/2024, h02332: Initial commit.
 *  - 27/05/2024, h02332: Add Random Image Generator for iOS + Watch
 *  - 08/03/2026, h02332: v1.8.0 — ICC profile embedding, P3/sRGB/AdobeRGB color spaces,
 *    1BitMonochrome generation, dimension diversity, 32BitFloat differentiation
 *  - 08/03/2026, h02332: v1.8.1 — Fix 1BitMonochrome grayscale drawing, autoreleasepool
 *    for memory pressure, skip ICC on GIF/BMP, error logging to errors.log
 *  - 08/03/2026, h02332: v1.9.0 — Collision-free filenames with SHA-256 hash suffix,
 *    short context names (xig- prefix), CryptoKit integration
 *
 */

// MARK: - Headers

/**
@brief Core and external libraries necessary for the fuzzer functionality.

@details This section includes the necessary headers for the Foundation framework, UIKit, Core Graphics,
standard input/output, standard library, memory management, mathematical functions,
Boolean type, floating-point limits, and string functions. These libraries support
image processing, UI interaction, and basic C operations essential for the application.
*/
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var imageUrls: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var selectedImageUrl: URL?
    
    var body: some View {
        VStack {
            VStack {
                Text("XNU Image Generator")
                    .font(.headline)
                    .padding(.top)
                Text("Images ready to share")
                    .font(.subheadline)
                    .padding(.bottom)
            }
            
            ScrollView(.horizontal) {
                HStack {
                    ForEach(imageUrls, id: \.self) { url in
                        if let image = loadImage(from: url) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .onTapGesture {
                                    selectedImageUrl = url
                                }
                        }
                    }
                }
            }
            .frame(height: 120)
            
            if !imageUrls.isEmpty {
                Button(action: shareImage) {
                    Text("Share Image")
                }
                .padding()
            }
        }
        .onAppear(perform: generateImages)
        .sheet(isPresented: $isShareSheetPresented, content: {
            if let selectedImageUrl = selectedImageUrl {
                #if os(iOS)
                ActivityViewController(activityItems: [selectedImageUrl])
                #elseif os(macOS)
                ActivityViewController(activityItems: [selectedImageUrl])
                #endif
            }
        })
    }
    
// MARK: - ImageGenerator Class
    /// The ImageGenerator class provides methods to create and save images with various bitmap contexts.
    func generateImages() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = paths.first else { return }
        imageUrls = generateAndSaveImages(basePath: documentsDirectory.path)
        if !imageUrls.isEmpty {
            selectedImageUrl = imageUrls.first
        }
    }

// MARK: - loadImage
    func loadImage(from url: URL) -> UIImage? {
        #if os(iOS)
        do {
            let data = try Data(contentsOf: url)
            print("Successfully loaded image from URL: \(url)")
            return UIImage(data: data)
        } catch {
            print("Failed to load image from URL: \(url) with error: \(error)")
            return nil
        }
        #elseif os(macOS)
        do {
            let data = try Data(contentsOf: url)
            guard let nsImage = NSImage(data: data) else {
                print("Failed to create NSImage from data at URL: \(url)")
                return nil
            }
            let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            print("Successfully created CGImage from URL: \(url)")
            return cgImage.map { UIImage(cgImage: $0) }
        } catch {
            print("Failed to load image from URL: \(url) with error: \(error)")
            return nil
        }
        #endif
    }
    
    func shareImage() {
        isShareSheetPresented = true
    }
}

#if os(iOS)
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ActivityViewController: NSViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        let picker = NSSharingServicePicker(items: activityItems)
        picker.delegate = context.coordinator
        
        controller.view = NSView()
        picker.show(relativeTo: .zero, of: controller.view, preferredEdge: .minY)
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
    
    class Coordinator: NSObject, NSSharingServicePickerDelegate {
        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            // Handle the selection if needed
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}
#endif

// MARK: - Image Generation

/**
 @brief Function to generate an image with a specific context type.
 
 @discussion This function creates a CGContext with the specified context type and draws a gradient on it.
 
 @param contextType The type of context to create.
 @return An optional CGImage if the image is successfully generated, otherwise nil.
 */
func generateImage(contextType: String, width: Int = 300, height: Int = 300) -> CGImage? {
    let context: CGContext?
    
    // Switch case to handle different context types
    switch contextType {
    case "StandardRGB":
        context = createBitmapContextStandardRGB(width: width, height: height)
    case "PremultipliedFirstAlpha":
        context = createBitmapContextPremultipliedFirstAlpha(width: width, height: height)
    case "NonPremultipliedAlpha":
        context = createBitmapContextNonPremultipliedAlpha(width: width, height: height)
    case "16BitDepth":
        context = createBitmapContext16BitDepth(width: width, height: height)
    case "Grayscale":
        context = createBitmapContextGrayscale(width: width, height: height)
    case "HDRFloatComponents":
        context = createBitmapContextHDRFloatComponents(width: width, height: height)
    case "1BitMonochrome":
        context = createBitmapContext1BitMonochrome(width: width, height: height)
    case "BigEndian":
        context = createBitmapContextBigEndian(width: width, height: height)
    case "LittleEndian":
        context = createBitmapContextLittleEndian(width: width, height: height)
    case "32BitFloat4Component":
        context = createBitmapContext32BitFloat4Component(width: width, height: height)
    case "DisplayP3":
        context = createBitmapContextDisplayP3(width: width, height: height)
    case "sRGB":
        context = createBitmapContextSRGB(width: width, height: height)
    case "AdobeRGB1998":
        context = createBitmapContextAdobeRGB(width: width, height: height)
    default:
        context = nil
    }
    
    // Ensure context creation was successful
    guard let ctx = context else {
        print("Failed to create CGContext for \(contextType)")
        return nil
    }
    
    // Use grayscale colors for monochrome/grayscale contexts, RGB for everything else
    let isGrayscaleContext = (contextType == "1BitMonochrome" || contextType == "Grayscale")
    let color1: CGColor
    let color2: CGColor
    let gradientColorSpace: CGColorSpace
    
    if isGrayscaleContext {
        color1 = CGColor(gray: CGFloat.random(in: 0...1), alpha: 1)
        color2 = CGColor(gray: CGFloat.random(in: 0...1), alpha: 1)
        gradientColorSpace = CGColorSpaceCreateDeviceGray()
    } else {
        color1 = CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1)
        color2 = CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1)
        gradientColorSpace = CGColorSpaceCreateDeviceRGB()
    }
    let colors = [color1, color2]
    let locations: [CGFloat] = [0.0, 1.0]

    guard let gradient = CGGradient(colorsSpace: gradientColorSpace, colors: colors as CFArray, locations: locations) else {
        print("Failed to create gradient")
        return nil
    }

    // Randomize gradient direction
    let startX = CGFloat.random(in: 0...CGFloat(width))
    let startY = CGFloat.random(in: 0...CGFloat(height))
    let endX = CGFloat.random(in: 0...CGFloat(width))
    let endY = CGFloat.random(in: 0...CGFloat(height))

    ctx.drawLinearGradient(gradient, start: CGPoint(x: startX, y: startY), end: CGPoint(x: endX, y: endY), options: [])

    // Add random elements (circles, lines, etc.)
    for _ in 0..<10 {
        let elementType = Int.random(in: 0...2)
        let fillColor: CGColor = isGrayscaleContext
            ? CGColor(gray: CGFloat.random(in: 0...1), alpha: 1)
            : CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1)
        switch elementType {
        case 0:
            // Draw a random circle
            let centerX = CGFloat.random(in: 0...CGFloat(width))
            let centerY = CGFloat.random(in: 0...CGFloat(height))
            let radius = CGFloat.random(in: 10...50)
            ctx.setFillColor(fillColor)
            ctx.fillEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
        case 1:
            // Draw a random rectangle
            let rectX = CGFloat.random(in: 0...CGFloat(width))
            let rectY = CGFloat.random(in: 0...CGFloat(height))
            let rectWidth = CGFloat.random(in: 20...100)
            let rectHeight = CGFloat.random(in: 20...100)
            ctx.setFillColor(fillColor)
            ctx.fill(CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight))
        case 2:
            // Draw a random line
            let lineStartX = CGFloat.random(in: 0...CGFloat(width))
            let lineStartY = CGFloat.random(in: 0...CGFloat(height))
            let lineEndX = CGFloat.random(in: 0...CGFloat(width))
            let lineEndY = CGFloat.random(in: 0...CGFloat(height))
            ctx.setStrokeColor(fillColor)
            ctx.setLineWidth(CGFloat.random(in: 1...5))
            ctx.move(to: CGPoint(x: lineStartX, y: lineStartY))
            ctx.addLine(to: CGPoint(x: lineEndX, y: lineEndY))
            ctx.strokePath()
        default:
            break
        }
    }

    return ctx.makeImage()
}

// MARK: - Image Saving

/**
 @brief Function to save an image to a URL.
 
 @discussion This function saves the given CGImage to the specified URL with the provided UTType.
 
 @param image The CGImage to save.
 @param url The URL to save the image to.
 @param uti The UTType of the image format.
 @return A Boolean value indicating whether the image was successfully saved.
 */
func saveImage(_ image: CGImage, to url: URL, uti: UTType, iccProfileData: Data? = nil) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti.identifier as CFString, 1, nil) else {
        print("Failed to create CGImageDestination for \(url.path)")
        return false
    }
    
    var imageToSave = image
    if let iccData = iccProfileData,
       let colorSpace = CGColorSpace(iccData: iccData as CFData),
       let converted = image.copy(colorSpace: colorSpace) {
        imageToSave = converted
    }
    
    CGImageDestinationAddImage(destination, imageToSave, nil)
    
    if CGImageDestinationFinalize(destination) {
        print("Successfully saved image to URL: \(url)")
        return true
    } else {
        print("Failed to finalize the image destination for URL: \(url.path)")
        return false
    }
}

/// Saves an image to a file with a 6-char SHA-256 hash suffix for collision-free filenames.
/// Final filename: `{baseName}.{ext}.{hash6}` where hash6 is derived from file content.
func saveImageWithHash(_ image: CGImage, basePath: String, baseName: String, ext: String, uti: UTType, iccProfileData: Data? = nil) -> URL? {
    let tempURL = URL(fileURLWithPath: basePath).appendingPathComponent("\(baseName).\(ext)")
    guard saveImage(image, to: tempURL, uti: uti, iccProfileData: iccProfileData) else {
        return nil
    }
    
    guard let fileData = try? Data(contentsOf: tempURL) else {
        return tempURL
    }
    let hash = SHA256.hash(data: fileData)
    let hash6 = hash.prefix(3).map { String(format: "%02x", $0) }.joined()
    
    let finalName = "\(baseName)-\(hash6).\(ext)"
    let finalURL = URL(fileURLWithPath: basePath).appendingPathComponent(finalName)
    
    if finalURL != tempURL {
        try? FileManager.default.moveItem(at: tempURL, to: finalURL)
    }
    
    return finalURL
}

func generateAndSaveImages(basePath: String) -> [URL] {
    // Context types with short names for filenames
    let contextTypes: [(String, String)] = [
        ("StandardRGB", "stdrgb"),
        ("PremultipliedFirstAlpha", "premul"),
        ("NonPremultipliedAlpha", "nonpremul"),
        ("16BitDepth", "16bit"),
        ("Grayscale", "gray"),
        ("HDRFloatComponents", "hdr"),
        ("BigEndian", "bigend"),
        ("LittleEndian", "litend"),
        ("32BitFloat4Component", "float4"),
        ("1BitMonochrome", "1bit"),
        ("DisplayP3", "p3"),
        ("sRGB", "srgb"),
        ("AdobeRGB1998", "adobergb")
    ]
    
    let formats: [(String, UTType)] = [
        ("png", .png),
        ("jpg", .jpeg),
        ("tiff", .tiff),
        ("bmp", .bmp),
        ("gif", .gif),
        ("heic", .heic)
    ]
    
    // ICC embedding is reliable for PNG, TIFF, JPEG, and HEIC
    let iccSupportedFormats: Set<UTType> = [.png, .tiff, .jpeg, .heic]
    
    let dimensions: [(Int, Int)] = [
        (300, 300),
        (1, 1),
        (16, 16),
        (1024, 1024),
        (4096, 1)
    ]
    
    let iccProfiles = getICCProfiles()

    var savedURLs = [URL]()
    var failedOps: [(String, String)] = []
    let fileManager = FileManager.default

    do {
        if !fileManager.fileExists(atPath: basePath) {
            try fileManager.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
            print("Created directory at path: \(basePath)")
        }
    } catch {
        print("Failed to create directory at path: \(basePath) with error: \(error)")
        return []
    }
    
    for (contextType, shortName) in contextTypes {
        for (width, height) in dimensions {
            autoreleasepool {
                guard let image = generateImage(contextType: contextType, width: width, height: height) else {
                    let msg = "xig-\(shortName)-\(width)x\(height): CGContext or makeImage() returned nil"
                    failedOps.append((contextType, msg))
                    print("⚠️ \(msg)")
                    return
                }
                
                let isGrayscaleType = (contextType == "Grayscale" || contextType == "1BitMonochrome")
                
                for (ext, format) in formats {
                    if isGrayscaleType && format == .heic {
                        continue
                    }
                    
                    // Save to temp, hash, rename with unique suffix
                    let baseName = "xig-\(shortName)-\(width)x\(height)"
                    if let url = saveImageWithHash(image, basePath: basePath, baseName: baseName, ext: ext, uti: format) {
                        savedURLs.append(url)
                    } else {
                        failedOps.append((contextType, "\(baseName).\(ext): save failed"))
                    }
                    
                    if !isGrayscaleType && iccSupportedFormats.contains(format) {
                        for (iccName, iccData) in iccProfiles {
                            let iccBaseName = "xig-\(shortName)-\(width)x\(height)-icc_\(iccName)"
                            if let url = saveImageWithHash(image, basePath: basePath, baseName: iccBaseName, ext: ext, uti: format, iccProfileData: iccData) {
                                savedURLs.append(url)
                            } else {
                                failedOps.append((contextType, "\(iccBaseName).\(ext): ICC save failed"))
                            }
                        }
                    }
                }
            }
        }
    }
    
    if !failedOps.isEmpty {
        let errorLog = failedOps.map { "[\($0.0)] \($0.1)" }.joined(separator: "\n")
        let errorURL = URL(fileURLWithPath: basePath).appendingPathComponent("errors.log")
        try? errorLog.write(to: errorURL, atomically: true, encoding: .utf8)
        print("⚠️ \(failedOps.count) failures logged to errors.log")
    }
    
    print("Total images saved: \(savedURLs.count), failures: \(failedOps.count)")
    return savedURLs
}

/// Returns ICC profile data for sRGB, Display P3, and AdobeRGB color spaces.
func getICCProfiles() -> [(String, Data)] {
    var profiles: [(String, Data)] = []
    
    let namedSpaces: [(String, CFString)] = [
        ("sRGB", CGColorSpace.sRGB as CFString),
        ("DisplayP3", CGColorSpace.displayP3 as CFString),
        ("AdobeRGB", CGColorSpace.adobeRGB1998 as CFString)
    ]
    
    for (name, spaceName) in namedSpaces {
        if let cs = CGColorSpace(name: spaceName),
           let data = cs.copyICCData() as Data? {
            profiles.append((name, data))
        }
    }
    
    return profiles
}

// MARK: - CGContext Creation Functions

/**
 @brief Function to create a CGContext with Standard RGB.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextStandardRGB(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with Premultiplied First Alpha.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextPremultipliedFirstAlpha(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with Non-Premultiplied Alpha.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextNonPremultipliedAlpha(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with 16-bit Depth.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContext16BitDepth(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 16,
        bytesPerRow: width * 8,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with Grayscale.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextGrayscale(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let bitmapInfo = CGImageAlphaInfo.none.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with HDR Float Components.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextHDRFloatComponents(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 32,
        bytesPerRow: width * 16,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with 1-bit Monochrome.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContext1BitMonochrome(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let bitmapInfo = CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrderDefault.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 1,
        bytesPerRow: (width + 7) / 8,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with Big Endian.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextBigEndian(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with Little Endian.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextLittleEndian(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with 32-bit Float 4-Component (non-premultiplied).
 
 @discussion Unlike HDRFloatComponents which uses premultiplied alpha, this context
 uses noneSkipLast alpha to exercise different decoder paths.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContext32BitFloat4Component(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.floatComponents.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 32,
        bytesPerRow: width * 16,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

// MARK: - Named Color Space Contexts

/**
 @brief Function to create a CGContext with Display P3 color space.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextDisplayP3(width: Int, height: Int) -> CGContext? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) else {
        print("Failed to create Display P3 color space")
        return nil
    }
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with sRGB color space.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextSRGB(width: Int, height: Int) -> CGContext? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        print("Failed to create sRGB color space")
        return nil
    }
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

/**
 @brief Function to create a CGContext with Adobe RGB 1998 color space.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextAdobeRGB(width: Int, height: Int) -> CGContext? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.adobeRGB1998) else {
        print("Failed to create Adobe RGB 1998 color space")
        return nil
    }
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

// MARK: - ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

