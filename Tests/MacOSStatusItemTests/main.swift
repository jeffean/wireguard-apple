import Cocoa

struct Route { let stringRepresentation: String }
struct Peer { let allowedIPs: [Route] }
struct Configuration { let peers: [Peer] }
class TunnelContainer {
    enum Status { case inactive, active, activating, waiting, reasserting, restarting, deactivating }
    var status: Status = .active
    var tunnelConfiguration: Configuration?
}

let app = NSApplication.shared
for name in ["StatusBarIcon", "StatusBarIconDimmed", "StatusBarIconDot1", "StatusBarIconDot2", "StatusBarIconDot3"] {
    let path = "Sources/WireGuardApp/UI/macOS/Assets.xcassets/\(name).imageset/\(name)@2x.png"
    let image = NSImage(contentsOfFile: path)!
    image.isTemplate = true
    image.setName(name)
}
let controller = StatusItemController()
let tunnel = TunnelContainer()
func check(_ routes: [String], purple: Bool) {
    tunnel.tunnelConfiguration = Configuration(peers: [Peer(allowedIPs: routes.map { Route(stringRepresentation: $0) })])
    controller.currentTunnel = tunnel
    let image = controller.statusItem.button!.image!
    precondition(image.isTemplate == !purple)
    if purple {
        let context = CGContext(data: nil, width: 48, height: 48, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: NSRect(x: 0, y: 0, width: 48, height: 48))
        NSGraphicsContext.restoreGraphicsState()
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
        var opaquePixels = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
                if color.alphaComponent > 0.9 {
                    precondition(color.redComponent > color.greenComponent + 0.05)
                    precondition(color.greenComponent > 0.5)
                    precondition(color.blueComponent > color.redComponent + 0.05)
                    opaquePixels += 1
                }
            }
        }
        precondition(opaquePixels > 0)
    } else {
        precondition(image === NSImage(named: "StatusBarIcon")!)
    }
}
check(["0.0.0.0/0"], purple: true)
check(["0.0.0.0/1", "128.0.0.0/1"], purple: true)
check(TunnelWidgetRouteSummarizer.publicIPv4Ranges, purple: true)
check(["192.168.0.0/16"], purple: false)
check(["0.0.0.0/0"], purple: true)
for status: TunnelContainer.Status in [.inactive, .activating, .waiting, .reasserting, .restarting, .deactivating] {
    tunnel.status = status
    controller.updateStatusItemImage()
    precondition(controller.statusItem.button!.image!.isTemplate)
}
tunnel.status = .active
tunnel.tunnelConfiguration = nil
controller.updateStatusItemImage()
precondition(controller.statusItem.button!.image!.isTemplate)
controller.currentTunnel = nil
precondition(controller.statusItem.button!.image!.isTemplate)
print("PASS: AppKit rendered icon pixels for full routes, LAN exclusion, split, missing config, and all transition states")
