//
//  AquariumView.swift
//  Aquarium.saver — a real coral-reef screensaver for Apple Silicon Macs
//                   as a proper macOS .saver bundle.
//
//  Author:  Anthony Harwelik <aharwelik@gmail.com>
//  Repo:    https://github.com/aharwelik/aquarium-screensaver
//  License: MIT
//
//  This is the macOS-native sibling of the standalone Aquarium binary.
//  Drops into ~/Library/Screen Savers/ and the OS picks it up:
//
//      System Settings → Wallpaper → Choose your screensaver → Aquarium
//
//  Apple's ScreenSaverEngine handles activation, sleep transitions,
//  multi-display, and dismissal-on-input — we just paint AVPlayerLayer
//  into the ScreenSaverView the engine hands us.  No LaunchAgent, no
//  HIDIdleTime poll, no caffeinate dance.  This is the *right* way and
//  Anthony Harwelik should've shipped it first.
//
//  Where the video lives
//  ---------------------
//  Two paths checked in order:
//      1.  Contents/Resources/aquarium.mp4 inside this bundle
//      2.  ~/Library/Application Support/Aquarium/aquarium.mp4
//  The second is the canonical install location used by the standalone
//  binary, so a user with both installed only stores one copy of the file.
//

import Cocoa
import ScreenSaver
import AVKit
import AVFoundation

/// `@objc(AquariumView)` gives the class a stable Objective-C name so
/// `NSPrincipalClass = AquariumView` in Info.plist resolves correctly.
/// Without the attribute, Swift mangles the name and ScreenSaverEngine
/// loads nothing.
@objc(AquariumView)
final class AquariumView: ScreenSaverView {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    /// One-time per-instance setup.  The engine creates one AquariumView
    /// per display, including a small "preview" view inside the Settings
    /// panel — we mute and lower volume for previews so Anthony's
    /// preferences window doesn't blast water sounds.
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupPlayer(isPreview: isPreview)
        // ScreenSaverEngine animates at this rate; we don't actually
        // draw per-frame ourselves (AVPlayerLayer handles that on the
        // GPU), but the engine still wants a value.
        animationTimeInterval = 1.0 / 30.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupPlayer(isPreview: false)
    }

    // -------------------------------------------------------------------------
    // MARK: Video source resolution
    // -------------------------------------------------------------------------

    /// Finds the aquarium video file.  Prefers the in-bundle copy so a
    /// .saver dropped on a fresh Mac still works without the App Support
    /// install, but falls back to the shared install location to avoid
    /// duplicating 1.5 GB of video on disk.
    private func locateVideo() -> URL? {
        // 1. Bundle resource
        if let bundleURL = Bundle(for: type(of: self)).url(forResource: "aquarium", withExtension: "mp4") {
            return bundleURL
        }
        // 2. Canonical install location used by the standalone binary
        let appSupport = NSString(string: "~/Library/Application Support/Aquarium/aquarium.mp4").expandingTildeInPath
        if FileManager.default.fileExists(atPath: appSupport) {
            return URL(fileURLWithPath: appSupport)
        }
        return nil
    }

    // -------------------------------------------------------------------------
    // MARK: Player construction
    // -------------------------------------------------------------------------

    private func setupPlayer(isPreview: Bool) {
        guard let videoURL = locateVideo() else {
            // Surface the problem to anyone watching Console.app —
            // ScreenSaverView itself shows just a black panel.
            NSLog("Aquarium.saver: aquarium.mp4 not found in bundle or ~/Library/Application Support/Aquarium/")
            return
        }

        let item = AVPlayerItem(url: videoURL)
        let player = AVPlayer(playerItem: item)
        // The screensaver engine is happy to feed us frames as fast as
        // we'll take them — disable stall-minimization to keep playback
        // smooth from the first frame.
        player.automaticallyWaitsToMinimizeStalling = false
        // Loop the clip indefinitely — the saver might run for hours
        // before Anthony comes back to dismiss it.
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // Audio: mute the live preview pane in System Settings, otherwise
        // play at the same low ambient volume the standalone binary uses.
        player.isMuted = isPreview
        player.volume = isPreview ? 0 : 0.35

        let layer = AVPlayerLayer(player: player)
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill   // fill each display, crop overflow
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(layer)

        self.player = player
        self.playerLayer = layer
    }

    // -------------------------------------------------------------------------
    // MARK: ScreenSaverView lifecycle
    // -------------------------------------------------------------------------

    override func startAnimation() {
        super.startAnimation()
        player?.play()
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
    }

    // We don't draw anything ourselves; AVPlayerLayer paints via Metal.
    override func draw(_ rect: NSRect) {
        // intentionally empty — layer-backed view handles compositing
    }

    // Anthony doesn't want a config sheet — duration is handled by the OS,
    // audio is handled by the standalone binary if a user wants to tweak.
    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    // Clean up the AVPlayer when the view goes away so AVFoundation
    // releases its IOSurface / Metal textures immediately rather than
    // waiting for the host process to exit.
    deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
}
