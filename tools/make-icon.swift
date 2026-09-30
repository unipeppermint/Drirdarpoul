import AppKit
import Foundation

// Import one 1024px source. Xcode generates the required device sizes at build time.
guard CommandLine.arguments.count >= 2 else {
    fatalError("Usage: swift tools/make-icon.swift <1024px-image> [appiconset-directory]")
}
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments.count > 2
    ? CommandLine.arguments[2] : "Drirdarpoul/Assets.xcassets/AppIcon.appiconset")
guard let image = NSImage(contentsOf: source),
      let input = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      input.width == 1024, input.height == 1024 else {
    fatalError("The app icon must be 1024 × 1024 pixels.")
}
// App Store icons must be opaque. Keep the supplied artwork at its original size.
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 4096, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.965, green: 0.949, blue: 0.91, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.draw(input, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("AppIcon.png"))
let contents: [String: Any] = [
    "images": [["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]],
    "info": ["author": "xcode", "version": 1]
]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: destination.appendingPathComponent("Contents.json"))
print("Imported AppIcon.png (1024 × 1024, opaque).")
