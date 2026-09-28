/*
 * Copyright (C) 2024-2026 David Hoyt
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or any later version.
 */

import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum ProfileMode: String {
    case none
    case with
    case both

    var includesUnprofiled: Bool { self != .with }
    var includesProfiled: Bool { self != .none }
}

private struct OutputFormat {
    let extensionName: String
    let type: UTType
    let supportsICC: Bool
}

private struct RenderCase {
    let name: String
    let width: Int
    let height: Int
    let style: Int
}

private struct ICCProfile {
    let name: String
    let data: Data
    let sha256: String
    let supportedExtensions: Set<String>
}

private struct ManifestEntry: Codable {
    let path: String
    let format: String
    let width: Int
    let height: Int
    let renderCase: String
    let iccMode: String
    let iccProfile: String?
    let sourceICCSHA256: String?
    let fileSHA256: String
}

private struct Manifest: Codable {
    let schemaVersion: Int
    let generator: String
    let requestedICCMode: String
    let entries: [ManifestEntry]
}

private enum GenerationError: LocalizedError {
    case invalidMode(String)
    case invalidProfile(String)
    case cannotCreateContext(String)
    case cannotCreateDestination(String)
    case cannotConvert(String)
    case cannotFinalize(String)

    var errorDescription: String? {
        switch self {
        case .invalidMode(let mode): return "Invalid XNU_IMAGE_ICC_MODE: \(mode)"
        case .invalidProfile(let name): return "Invalid ICC profile: \(name)"
        case .cannotCreateContext(let name): return "Cannot create render context: \(name)"
        case .cannotCreateDestination(let path): return "Cannot create image destination: \(path)"
        case .cannotConvert(let name): return "Cannot convert image to ICC profile: \(name)"
        case .cannotFinalize(let path): return "Cannot finalize image: \(path)"
        }
    }
}

struct ContentView: View {
    @State private var imageURLs: [URL] = []
    @State private var status = "Preparing deterministic QA images"

    var body: some View {
        VStack(spacing: 12) {
            Text("XNU Image Generator")
                .font(.headline)
            Text(status)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(imageURLs.prefix(24), id: \.self) { url in
                        if let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                        }
                    }
                }
            }
            .frame(height: 110)
        }
        .padding()
        .onAppear(perform: generateImages)
    }

    private func generateImages() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try CleanImageGenerator().run()
                DispatchQueue.main.async {
                    imageURLs = result.files
                    status = "Generated and recorded \(result.files.count) clean images in \(result.output.path)"
                }
            } catch {
                DispatchQueue.main.async {
                    status = "Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct CleanImageGenerator {
    private let formats = [
        OutputFormat(extensionName: "png", type: .png, supportsICC: true),
        OutputFormat(extensionName: "jpg", type: .jpeg, supportsICC: true),
        OutputFormat(extensionName: "tiff", type: .tiff, supportsICC: true),
        OutputFormat(extensionName: "bmp", type: .bmp, supportsICC: false),
        OutputFormat(extensionName: "gif", type: .gif, supportsICC: false)
    ]

    private let renderCases = [
        RenderCase(name: "chart-square", width: 300, height: 300, style: 0),
        RenderCase(name: "chart-wide", width: 640, height: 360, style: 1),
        RenderCase(name: "chart-small", width: 32, height: 32, style: 2),
        RenderCase(name: "chart-single-pixel", width: 1, height: 1, style: 3)
    ]

    func run() throws -> (files: [URL], output: URL) {
        let environment = ProcessInfo.processInfo.environment
        let modeValue = environment["XNU_IMAGE_ICC_MODE"] ?? ProfileMode.both.rawValue
        guard let mode = ProfileMode(rawValue: modeValue) else {
            throw GenerationError.invalidMode(modeValue)
        }

        let outputURL: URL
        if let path = environment["XNU_IMAGE_OUTPUT_DIR"], !path.isEmpty {
            outputURL = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            outputURL = documents.appendingPathComponent("CleanGeneratedImages", isDirectory: true)
        }

        try prepareOutput(at: outputURL)
        let profiles = try loadProfiles()
        var entries = [ManifestEntry]()
        var files = [URL]()

        for renderCase in renderCases {
            try autoreleasepool {
                let image = try render(renderCase)
                if mode.includesUnprofiled {
                    for format in formats {
                        let relative = "no-icc/\(renderCase.name).\(format.extensionName)"
                        let url = outputURL.appendingPathComponent(relative)
                        let fileHash = try write(image: image, profile: nil, format: format, to: url)
                        entries.append(ManifestEntry(
                            path: relative,
                            format: format.extensionName,
                            width: renderCase.width,
                            height: renderCase.height,
                            renderCase: renderCase.name,
                            iccMode: "none",
                            iccProfile: nil,
                            sourceICCSHA256: nil,
                            fileSHA256: fileHash
                        ))
                        files.append(url)
                    }
                }

                if mode.includesProfiled {
                    for profile in profiles {
                        for format in formats where profile.supportedExtensions.contains(format.extensionName) {
                            let relative = "with-icc/\(profile.name)/\(renderCase.name).\(format.extensionName)"
                            let url = outputURL.appendingPathComponent(relative)
                            let fileHash = try write(image: image, profile: profile, format: format, to: url)
                            entries.append(ManifestEntry(
                                path: relative,
                                format: format.extensionName,
                                width: renderCase.width,
                                height: renderCase.height,
                                renderCase: renderCase.name,
                                iccMode: "with",
                                iccProfile: profile.name,
                                sourceICCSHA256: profile.sha256,
                                fileSHA256: fileHash
                            ))
                            files.append(url)
                        }
                    }
                }
            }
        }

        let manifest = Manifest(
            schemaVersion: 1,
            generator: "xnuimagetools-clean-image-generator",
            requestedICCMode: mode.rawValue,
            entries: entries.sorted { $0.path < $1.path }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
        return (files, outputURL)
    }

    private func prepareOutput(at outputURL: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        for name in ["no-icc", "with-icc", "manifest.json", "generation-errors.txt"] {
            let target = outputURL.appendingPathComponent(name)
            if manager.fileExists(atPath: target.path) {
                try manager.removeItem(at: target)
            }
        }
        try manager.createDirectory(at: outputURL.appendingPathComponent("no-icc"), withIntermediateDirectories: true)
        try manager.createDirectory(at: outputURL.appendingPathComponent("with-icc"), withIntermediateDirectories: true)
    }

    private func loadProfiles() throws -> [ICCProfile] {
        let names: [(String, CFString, Set<String>)] = [
            ("srgb", CGColorSpace.sRGB as CFString, ["tiff"]),
            ("display-p3", CGColorSpace.displayP3 as CFString, ["png", "jpg", "tiff"]),
            ("adobe-rgb-1998", CGColorSpace.adobeRGB1998 as CFString, ["jpg", "tiff"])
        ]
        return try names.map { outputName, colorSpaceName, supportedExtensions in
            guard let colorSpace = CGColorSpace(name: colorSpaceName),
                  let profileData = colorSpace.copyICCData() as Data? else {
                throw GenerationError.invalidProfile(outputName)
            }
            try validate(profileData, named: outputName)
            return ICCProfile(
                name: outputName,
                data: profileData,
                sha256: sha256(profileData),
                supportedExtensions: supportedExtensions
            )
        }
    }

    private func validate(_ data: Data, named name: String) throws {
        guard data.count >= 132,
              data[36..<40] == Data("acsp".utf8) else {
            throw GenerationError.invalidProfile(name)
        }
        let declaredSize = data.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        guard declaredSize == data.count else {
            throw GenerationError.invalidProfile(name)
        }
        let tagCount = data[128..<132].reduce(0) { ($0 << 8) | Int($1) }
        guard tagCount <= (data.count - 132) / 12 else {
            throw GenerationError.invalidProfile(name)
        }
        let tableEnd = 132 + tagCount * 12
        for index in 0..<tagCount {
            let entry = 132 + index * 12
            let offset = data[(entry + 4)..<(entry + 8)].reduce(0) { ($0 << 8) | Int($1) }
            let size = data[(entry + 8)..<(entry + 12)].reduce(0) { ($0 << 8) | Int($1) }
            guard offset >= tableEnd, size > 0, offset <= data.count - size else {
                throw GenerationError.invalidProfile(name)
            }
        }
    }

    private func render(_ renderCase: RenderCase) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: renderCase.width,
            height: renderCase.height,
            bitsPerComponent: 8,
            bytesPerRow: renderCase.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw GenerationError.cannotCreateContext(renderCase.name)
        }

        let width = CGFloat(renderCase.width)
        let height = CGFloat(renderCase.height)
        let palettes: [[CGColor]] = [
            [CGColor(red: 0.06, green: 0.18, blue: 0.42, alpha: 1), CGColor(red: 0.95, green: 0.72, blue: 0.12, alpha: 1)],
            [CGColor(red: 0.10, green: 0.55, blue: 0.35, alpha: 1), CGColor(red: 0.78, green: 0.12, blue: 0.30, alpha: 1)],
            [CGColor(red: 0.42, green: 0.12, blue: 0.62, alpha: 1), CGColor(red: 0.12, green: 0.72, blue: 0.86, alpha: 1)],
            [CGColor(red: 0.25, green: 0.50, blue: 0.75, alpha: 1), CGColor(red: 0.25, green: 0.50, blue: 0.75, alpha: 1)]
        ]
        let palette = palettes[renderCase.style]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: palette as CFArray, locations: [0, 1]) else {
            throw GenerationError.cannotCreateContext(renderCase.name)
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: width, y: height),
            options: []
        )

        if renderCase.width > 1 && renderCase.height > 1 {
            let swatches: [CGColor] = [
                CGColor(red: 0.92, green: 0.16, blue: 0.14, alpha: 0.85),
                CGColor(red: 0.12, green: 0.72, blue: 0.28, alpha: 0.85),
                CGColor(red: 0.10, green: 0.32, blue: 0.88, alpha: 0.85),
                CGColor(gray: 0.92, alpha: 0.85)
            ]
            let blockWidth = width / CGFloat(swatches.count)
            for (index, color) in swatches.enumerated() {
                context.setFillColor(color)
                context.fill(CGRect(
                    x: CGFloat(index) * blockWidth,
                    y: height * 0.62,
                    width: blockWidth,
                    height: height * 0.24
                ))
            }
            context.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
            context.setLineWidth(max(1, min(width, height) / 80))
            context.stroke(CGRect(x: width * 0.08, y: height * 0.08, width: width * 0.84, height: height * 0.84))
        }

        guard let image = context.makeImage() else {
            throw GenerationError.cannotCreateContext(renderCase.name)
        }
        return image
    }

    private func write(image: CGImage, profile: ICCProfile?, format: OutputFormat, to url: URL) throws -> String {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.type.identifier as CFString,
            1,
            nil
        ) else {
            throw GenerationError.cannotCreateDestination(url.path)
        }

        let outputImage: CGImage
        if let profile {
            guard format.supportsICC,
                  let colorSpace = CGColorSpace(iccData: profile.data as CFData),
                  let converted = image.copy(colorSpace: colorSpace) else {
                throw GenerationError.cannotConvert(profile.name)
            }
            outputImage = converted
        } else {
            outputImage = image
        }

        CGImageDestinationAddImage(destination, outputImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw GenerationError.cannotFinalize(url.path)
        }
        return sha256(try Data(contentsOf: url))
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
