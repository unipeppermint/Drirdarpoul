import AppKit
import Foundation

// Original, code-drawn archive mark; no external image or licensed artwork.
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Drirdarpoul/Assets.xcassets/AppIcon.appiconset"
let specs: [(String, Int, Int)] = [("20x20",20,2),("20x20",20,3),("29x29",29,2),("29x29",29,3),("40x40",40,2),("40x40",40,3),("60x60",60,2),("60x60",60,3),("1024x1024",1024,1)]
var images: [[String:String]] = []
for (size, points, scale) in specs {
    let pixels = points * scale
    let context = CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:pixels*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:false)
    context.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
    NSColor(srgbRed:0.965,green:0.949,blue:0.91,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:1024,height:1024)).fill()
    let ink = NSColor(srgbRed:0.145,green:0.17,blue:0.153,alpha:1)
    let wine = NSColor(srgbRed:0.514,green:0.239,blue:0.275,alpha:1)
    ink.withAlphaComponent(0.5).setStroke()
    let box = NSBezierPath(roundedRect:NSRect(x:174,y:144,width:676,height:736),xRadius:24,yRadius:24); box.lineWidth = 5; box.stroke()
    let seam=NSBezierPath(); seam.move(to:NSPoint(x:512,y:162));seam.line(to:NSPoint(x:512,y:862));seam.move(to:NSPoint(x:192,y:512));seam.line(to:NSPoint(x:832,y:512));seam.lineWidth=3;seam.stroke()
    for (symbol,x,y,color) in [("♠",235,539,ink),("♥",573,539,wine),("♦",235,191,wine),("♣",573,191,ink)] {
        (symbol as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:260),.foregroundColor:color])
    }
    wine.setFill();NSBezierPath(roundedRect:NSRect(x:636,y:829,width:172,height:60),xRadius:5,yRadius:5).fill()
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon-\(pixels).png"
    let bitmap = NSBitmapImageRep(cgImage:context.makeImage()!)
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:root).appendingPathComponent(name))
    images.append(["filename":name,"idiom":points == 1024 ? "ios-marketing":"iphone","scale":"\(scale)x","size":size])
}
let data = try JSONSerialization.data(withJSONObject:["images":images,"info":["author":"xcode","version":1]],options:[.prettyPrinted,.sortedKeys])
try data.write(to:URL(fileURLWithPath:root).appendingPathComponent("Contents.json"))
