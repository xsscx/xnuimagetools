/**
 *  @file ContentView.swift
 *  @brief XNU Image Generator for iOS
 *  @author @h02332 | David Hoyt | @xsscx
 *  @date 27 MAY 2024
 *  @version 1.7.5
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
func generateImage(contextType: String) -> CGImage? {
    let width = 300
    let height = 300
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
    case "AlphaOnly":
        context = createBitmapContextAlphaOnly(width: width, height: height)
    case "1BitMonochrome":
        context = createBitmapContext1BitMonochrome(width: width, height: height)
    case "BigEndian":
        context = createBitmapContextBigEndian(width: width, height: height)
    case "LittleEndian":
        context = createBitmapContextLittleEndian(width: width, height: height)
    case "32BitFloat4Component":
        context = createBitmapContext32BitFloat4Component(width: width, height: height)
    default:
        context = nil
    }
    
    // Ensure context creation was successful
    guard let ctx = context else {
        print("Failed to create CGContext for \(contextType)")
        return nil
    }
    
    // Generate random colors for the gradient
    let color1 = CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1)
    let color2 = CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1)
    let colors = [color1, color2]
    let locations: [CGFloat] = [0.0, 1.0]

    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
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
        switch elementType {
        case 0:
            // Draw a random circle
            let centerX = CGFloat.random(in: 0...CGFloat(width))
            let centerY = CGFloat.random(in: 0...CGFloat(height))
            let radius = CGFloat.random(in: 10...50)
            ctx.setFillColor(CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1))
            ctx.fillEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
        case 1:
            // Draw a random rectangle
            let rectX = CGFloat.random(in: 0...CGFloat(width))
            let rectY = CGFloat.random(in: 0...CGFloat(height))
            let rectWidth = CGFloat.random(in: 20...100)
            let rectHeight = CGFloat.random(in: 20...100)
            ctx.setFillColor(CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1))
            ctx.fill(CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight))
        case 2:
            // Draw a random line
            let lineStartX = CGFloat.random(in: 0...CGFloat(width))
            let lineStartY = CGFloat.random(in: 0...CGFloat(height))
            let lineEndX = CGFloat.random(in: 0...CGFloat(width))
            let lineEndY = CGFloat.random(in: 0...CGFloat(height))
            ctx.setStrokeColor(CGColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1))
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
func saveImage(_ image: CGImage, to url: URL, uti: UTType) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti.identifier as CFString, 1, nil) else {
        print("Failed to create CGImageDestination for \(url.path)")
        return false
    }
    
    CGImageDestinationAddImage(destination, image, nil)
    
    if CGImageDestinationFinalize(destination) {
        print("Failed to create CGImageDestination for URL: \(url)")
        return true
    } else {
        print("Failed to finalize the image destination for URL: \(url.path)")
        return false
    }
}

func generateAndSaveImages(basePath: String) -> [URL] {
    let contextTypes = [
        "StandardRGB", "PremultipliedFirstAlpha", "NonPremultipliedAlpha",
        "16BitDepth", "Grayscale", "HDRFloatComponents",
        "BigEndian", "LittleEndian", "32BitFloat4Component"
    ]
    
    let formats: [(String, UTType)] = [
        ("image.png", .png),
        ("image.jpg", .jpeg),
        ("image.tiff", .tiff),
        ("image.bmp", .bmp),
        ("image.gif", .gif),
        ("image.heic", .heic)
    ]

    var savedURLs = [URL]()
    let fileManager = FileManager.default

    // Ensure base path exists
    do {
        if !fileManager.fileExists(atPath: basePath) {
            try fileManager.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
            print("Created directory at path: \(basePath)")
        }
    } catch {
        print("Failed to create directory at path: \(basePath) with error: \(error)")
        return []
    }
    
    for contextType in contextTypes {
        guard let image = generateImage(contextType: contextType) else {
            print("Failed to generate image for context type \(contextType)")
            continue
        }
        
        for (suffix, format) in formats {
            if contextType == "Grayscale" && format == .heic {
                // Skip HEIC format for Grayscale context type due to known issues
                print("Skipping HEIC format for \(contextType) due to compatibility issues")
                continue
            }

            let fileName = "\(contextType)-\(suffix)"
            let fileURL = URL(fileURLWithPath: basePath).appendingPathComponent(fileName)
            print("Attempting to save image to: \(fileURL.path)")
            if saveImage(image, to: fileURL, uti: format) {
                savedURLs.append(fileURL)
                print("Successfully saved image: \(fileName) at path: \(fileURL.path)") 
            } else {
                print("Failed to save image: \(fileName) at path: \(fileURL.path)")
            }
        }
    }
    
    return savedURLs
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
 @brief Function to create a CGContext with Alpha Only.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContextAlphaOnly(width: Int, height: Int) -> CGContext? {
    print("Alpha-only context is not supported")
    return nil
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
 @brief Function to create a CGContext with 32-bit Float 4-Component.
 
 @param width The width of the context.
 @param height The height of the context.
 @return An optional CGContext.
 */
func createBitmapContext32BitFloat4Component(width: Int, height: Int) -> CGContext? {
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

// MARK: - ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

