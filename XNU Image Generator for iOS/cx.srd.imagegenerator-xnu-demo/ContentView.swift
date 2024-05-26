/**
 *  @file ContentView.swift
 *  @brief XNU Image Generator for iOS
 *  @author @h02332 | David Hoyt | @xsscx
 *  @date 21 MAY 2024
 *  @version 1.7.0
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

func generateImage(contextType: String) -> CGImage? {
    let width = 300
    let height = 300
    let context: CGContext?
    
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
    
    guard let ctx = context else {
        print("Failed to create CGContext for \(contextType)")
        return nil
    }
    
    // Drawing logic
    #if os(iOS)
    // Drawing logic
    let colors = [
        CGColor(red: 1, green: 0, blue: 0, alpha: 1),
        CGColor(red: 0, green: 0, blue: 1, alpha: 1)
    ]
    let locations: [CGFloat] = [0.0, 1.0]

    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
        print("Failed to create gradient")
        return nil
    }

    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: width, y: height), options: [])
    #endif
    
    return ctx.makeImage()
}

// MARK: - Image Saving

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

func createBitmapContextAlphaOnly(width: Int, height: Int) -> CGContext? {
    print("Alpha-only context is not supported")
    return nil
}

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

