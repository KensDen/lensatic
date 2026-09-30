// Rewrites PNG screenshots without their alpha channel, for the App Store (session 9, section 5.1): the Simulator
// saves RGBA, and the store wants RGB with no alpha. Every pixel must already be opaque, so nothing is flattened onto
// a colour: a file with any pixel that is not fully opaque is refused and left as it is. The pixels are drawn into an
// 8-bit RGB context in the image's own colour space, so no colour is converted. With --content it writes nothing and
// prints, for each image, the SHA-256 of its RGB pixels below the status bar (the top 8 percent of the rows are left
// out): two captures of one screen differ in their files, and can differ in a status bar icon, but not there.
// tools/ios_shots.sh --store compiles this into .tmp/ with the Xcode toolchain.
// Usage: png_opaque FILE.png...
//        png_opaque --content FILE.png...
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

var args = Array(CommandLine.arguments.dropFirst())
let contentOnly = args.first == "--content"
if contentOnly { args.removeFirst() }
var failed = false
for path in args {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = image.colorSpace, space.model == .rgb else {
        print("REFUSED \(path): not an RGB image")
        failed = true
        continue
    }
    let width = image.width, height = image.height, rect = CGRect(x: 0, y: 0, width: width, height: height)
    // read the alpha channel first: an opaque pixel reads 255 exactly
    guard let rgba = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                               space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let rgb = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        print("REFUSED \(path): no drawing context")
        failed = true
        continue
    }
    if contentOnly {
        rgb.draw(image, in: rect)
        let bytes = rgb.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var packed = Data(capacity: width * height * 3)
        // the context's first row is the image's top row
        for i in stride(from: height * 8 / 100 * width * 4, to: width * height * 4, by: 4) { packed.append(contentsOf: [bytes[i], bytes[i + 1], bytes[i + 2]]) }
        print("\(SHA256.hash(data: packed).map { String(format: "%02x", $0) }.joined())  \(path)")
        continue
    }
    rgba.draw(image, in: rect)
    let pixels = rgba.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var translucent = 0
    for i in stride(from: 3, to: width * height * 4, by: 4) where pixels[i] != 255 { translucent += 1 }
    if translucent > 0 {
        print("REFUSED \(path): \(translucent) pixels are not fully opaque")
        failed = true
        continue
    }
    rgb.draw(image, in: rect)
    guard let opaque = rgb.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("REFUSED \(path): cannot write")
        failed = true
        continue
    }
    CGImageDestinationAddImage(destination, opaque, nil)
    if CGImageDestinationFinalize(destination) {
        print("opaque \(path): \(width) x \(height)")
    } else {
        print("REFUSED \(path): the write failed")
        failed = true
    }
}
exit(failed ? 1 : 0)
