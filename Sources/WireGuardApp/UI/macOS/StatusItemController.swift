// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class StatusItemController {
    var currentTunnel: TunnelContainer? {
        didSet {
            updateStatusItemImage()
        }
    }

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusBarImageWhenActive = NSImage(named: "StatusBarIcon")!
    private lazy var statusBarImageWhenFullTunnel: NSImage = {
        let source = statusBarImageWhenActive
        let image = NSImage(size: source.size, flipped: false) { rect in
            source.draw(in: rect)
            NSColor(srgbRed: 196 / 255, green: 167 / 255, blue: 231 / 255, alpha: 1).setFill()
            rect.fill(using: .sourceIn)
            return true
        }
        image.isTemplate = false
        return image
    }()
    private let statusBarImageWhenInactive = NSImage(named: "StatusBarIconDimmed")!

    private let animationImages = [
        NSImage(named: "StatusBarIconDot1")!,
        NSImage(named: "StatusBarIconDot2")!,
        NSImage(named: "StatusBarIconDot3")!
    ]
    private var animationImageIndex: Int = 0
    private var animationTimer: Timer?

    init() {
        updateStatusItemImage()
    }

    func updateStatusItemImage() {
        guard let currentTunnel = currentTunnel else {
            stopActivatingAnimation()
            statusItem.button?.image = statusBarImageWhenInactive
            return
        }
        switch currentTunnel.status {
        case .inactive:
            stopActivatingAnimation()
            statusItem.button?.image = statusBarImageWhenInactive
        case .active:
            stopActivatingAnimation()
            statusItem.button?.image = statusBarImageWhenActive
            if let configuration = currentTunnel.tunnelConfiguration {
                let peers = configuration.peers.map {
                    TunnelWidgetPeerRoutes(allowedIPs: $0.allowedIPs.map(\.stringRepresentation), endpointHost: nil)
                }
                let route = TunnelWidgetRouteSummarizer.summarize(peers: peers, dnsServers: [])
                if route.mode.coversAllTraffic {
                    statusItem.button?.image = statusBarImageWhenFullTunnel
                }
            }
        case .activating, .waiting, .reasserting, .restarting, .deactivating:
            startActivatingAnimation()
        }
    }

    func startActivatingAnimation() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.statusItem.button?.image = self.animationImages[self.animationImageIndex]
            self.animationImageIndex = (self.animationImageIndex + 1) % self.animationImages.count
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    func stopActivatingAnimation() {
        guard let timer = self.animationTimer else { return }
        timer.invalidate()
        animationTimer = nil
        animationImageIndex = 0
    }
}
