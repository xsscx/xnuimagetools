/**
 *  @file ContentView.swift
 *  @brief XNU Image Generator for watchOS
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
 *
 */

// MARK: - Headers

/**
 @brief Core and external libraries necessary for the fuzzer functionality.
 
 @details This section includes all required libraries.
 */
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

// MARK: - Custom Transferable Type

/**
 @struct TransferableImage
 @brief Struct for managing transferable images.
 
 @discussion This struct is used to define a custom transferable type for sharing images.
 */
struct TransferableImage: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .image) { image in
            SentTransferredFile(image.url)
        }
    }
}

// MARK: - ContentView

/**
 @struct ContentView
 @brief Main view of the watch app.
 
 @discussion This struct defines the main user interface of the watch app. It includes a scrollable list of generated images and a button to share the selected image.
 */
struct ContentView: View {
    // State variables to manage the list of image URLs and the currently selected image URL
    @State private var imageUrls: [URL] = []
    @State private var selectedImageUrl: URL?
    
    /**
     @brief The body property defines the view's content and layout.
     */
    var body: some View {
         VStack {
             Spacer(minLength: 30) // Add spacer to push the text down

             VStack {
                 Text("XNU Image Generator")
                     .font(.headline) // Original font size
                     .font(.system(size: 16)) // Adjusted font size to be smaller
                     .padding(.top, 5) // Adjusted top padding
                     .minimumScaleFactor(0.8) // Scale down to fit if necessary

                 Text("Images ready to share")
                     .font(.subheadline) // Original font size
                     .font(.system(size: 14)) // Adjusted font size to be smaller
                     .padding(.bottom, 5) // Adjusted bottom padding
                     .minimumScaleFactor(0.8) // Scale down to fit if necessary
             }
             .padding([.leading, .trailing], 8) // Adjusted side padding

             ScrollView(.horizontal) {
                 HStack {
                     ForEach(imageUrls, id: \.self) { url in
                         if let image = loadImage(from: url) {
                             Image(uiImage: image)
                                 .resizable()
                                 .scaledToFit()
                                 .frame(width: 60, height: 60) // Adjusted frame size
                                 .onTapGesture {
                                     selectedImageUrl = url
                                 }
                         }
                     }
                 }
             }
             .frame(height: 80) // Adjusted frame height

             if let selectedImageUrl = selectedImageUrl {
                 ShareLink(item: selectedImageUrl, preview: SharePreview("Generated Image", image: Image(uiImage: loadImage(from: selectedImageUrl)!))) {
                     Text("Share Image")
                 }
                 .padding(5) // Adjusted padding
             }

             Spacer()
         }
         .edgesIgnoringSafeArea(.all)
         .onAppear(perform: generateImages)
     }

    
    // MARK: - Image Generation
    
    /**
     @brief Function to generate and save images.
     
     @discussion This function generates images and saves them to the document directory, then updates the `imageUrls` state.
     */
    func generateImages() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = paths.first else { return }
        imageUrls = generateAndSaveImages(basePath: documentsDirectory.path)
        if !imageUrls.isEmpty {
            selectedImageUrl = imageUrls.first
        }
    }

    // MARK: - Load Image
    
    /**
     @brief Function to load an image from a URL.
     
     @discussion This function attempts to load image data from the given URL and returns a UIImage if successful.
     
     @param url The URL of the image to load.
     @return An optional UIImage if the image is successfully loaded, otherwise nil.
     */
    func loadImage(from url: URL) -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            print("Successfully loaded image from URL: \(url)")
            return UIImage(data: data)
        } catch {
            print("Failed to load image from URL: \(url) with error: \(error)")
            return nil
        }
    }
}

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
          print("Successfully created CGImageDestination for URL: \(url)")
          return true
      } else {
          print("Failed to finalize the image destination for URL: \(url.path)")
          return false
      }
  }

  /**
   @brief Function to generate and save images with different context types and formats.
   
   @discussion This function generates images with various context types and saves them in multiple formats.
   
   @param basePath The base path to save the images.
   @return An array of URLs where the images were saved.
   */
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
