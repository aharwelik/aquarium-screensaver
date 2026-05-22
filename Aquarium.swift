//
//  Aquarium.swift
//  AquariumScreensaver — a real coral-reef screensaver for Apple Silicon Macs
//
//  Author:   Anthony Harwelik <aharwelik@gmail.com>
//  Repo:     https://github.com/aharwelik/aquarium-screensaver
//  License:  MIT (see LICENSE in repo root)
//
//  Why this exists
//  ---------------
//  Anthony Harwelik wanted a real fish-tank screensaver, in HDR, across every
//  display on his Mac. Most "aquarium" apps on the Store are paid, ad-laden,
//  or just generic GLSL fish. This one plays a single curated 4K-HDR coral-reef
//  clip on every monitor at the same time using:
//
//      * AVPlayer + AVPlayerLayer, so AVFoundation does the hard work (hardware
//        HEVC decode on Apple Silicon, Metal compositing, automatic HDR tone
//        mapping per display).
//      * One borderless NSWindow per NSScreen, parked at the .screenSaverWindow
//        window level so the player floats above the Dock, the menu bar, and any
//        normal app — same trick the built-in ScreenSaverEngine uses.
//      * A configurable countdown that defaults to 15 minutes and *only* ticks
//        while the screen is actually unlocked. If the Mac locked before launch
//        (because Anthony was sleeping), the show pauses until the next unlock,
//        then starts the 15-minute timer fresh.
//
//  Lessons painfully learned
//  -------------------------
//  The very first cut of this binary had no input handlers and an `accessory`
//  activation policy. Anthony got trapped — couldn't move the mouse, couldn't
//  click out, couldn't even ⌘Q. Never again. Below, ANY input event on ANY
//  screen — key, click, mouse-move, scroll, drag — kills the app. We watch via
//  both a `localMonitor` (input directed at our windows) AND a `globalMonitor`
//  (input directed elsewhere), so you can always escape from anywhere on the
//  Mac. The activation policy is `.regular` so the app shows up in ⌘-Tab and
//  has a proper Dock icon — no more invisible processes.
//
//  CPU & memory
//  ------------
//  AVPlayer's hardware HEVC decoder on M1/M2/M3 sits around 1-3% CPU per stream
//  on a 4K60 source. Three streams ≈ <10% on an M1 Max. AVPlayerLayer renders
//  directly via Metal — there's no per-frame CPU compositing path. On quit,
//  every AVPlayer is paused, has its item set to nil, and the array is dropped,
//  so AVFoundation's IOSurface and Metal textures are released immediately.
//

import Cocoa
import AVKit
import AVFoundation
import SwiftUI
import IOKit.pwr_mgt

// =============================================================================
// MARK: - Constants (Anthony's defaults)
// =============================================================================

/// Bundle identifier — used as the UserDefaults domain.  Keep in sync with the
/// LaunchAgent plist installed by `install.sh`.
let kBundleID = "com.harwelik.aquarium"

/// Default location for the video file.  The install script drops the clip here
/// from `~/Movies/fishtank/` so the binary doesn't need to know about the
/// download/transcode pipeline.
let kDefaultVideoPath = NSString(string: "~/Library/Application Support/Aquarium/aquarium.mp4").expandingTildeInPath

/// Default show length (seconds). 15 minutes is the headline number from
/// Anthony's "I want to wake up to it" feature request.
let kDefaultDuration: TimeInterval = 15 * 60

/// Volume on the audio-enabled display (0.0-1.0). Low enough to be ambient.
let kDefaultVolume: Float = 0.35

/// Per-display playback offset, in seconds. Each subsequent display starts
/// `kStaggerOffset` further into the clip, faking "different angles of the
/// same tank" without needing real cross-screen continuity.
let kStaggerOffset: TimeInterval = 300

// =============================================================================
// MARK: - Settings persistence (UserDefaults wrapper)
// =============================================================================

/// Thin typed wrapper around UserDefaults so the rest of the file doesn't have
/// to remember key names.  All keys live under the `com.harwelik.aquarium`
/// suite, which means `defaults read com.harwelik.aquarium` from the terminal
/// shows everything, and `defaults delete com.harwelik.aquarium` resets to
/// factory.
struct AquariumDefaults {
    private static let d = UserDefaults(suiteName: kBundleID) ?? .standard

    /// Show length in seconds.
    static var durationSeconds: TimeInterval {
        get { d.object(forKey: "durationSeconds") as? TimeInterval ?? kDefaultDuration }
        set { d.set(newValue, forKey: "durationSeconds") }
    }

    /// Path to the video file. Allows Anthony to swap in his own footage later.
    static var videoPath: String {
        get { d.string(forKey: "videoPath") ?? kDefaultVideoPath }
        set { d.set(newValue, forKey: "videoPath") }
    }

    /// Master mute. When true, no display plays audio.
    static var audioMuted: Bool {
        get { d.object(forKey: "audioMuted") as? Bool ?? false }
        set { d.set(newValue, forKey: "audioMuted") }
    }

    /// Audio output volume on the audio-enabled display.
    static var volume: Float {
        get { d.object(forKey: "volume") as? Float ?? kDefaultVolume }
        set { d.set(newValue, forKey: "volume") }
    }

    /// Index (into NSScreen.screens) of the display that plays audio.
    /// Defaults to 0 (primary display).  Out-of-range values fall back to 0
    /// at runtime.
    static var audioScreenIndex: Int {
        get { d.object(forKey: "audioScreenIndex") as? Int ?? 0 }
        set { d.set(newValue, forKey: "audioScreenIndex") }
    }

    /// Stagger offset in seconds between displays (creates the "different
    /// angles" effect).  Set to 0 for perfectly mirrored playback.
    static var staggerSeconds: TimeInterval {
        get { d.object(forKey: "staggerSeconds") as? TimeInterval ?? kStaggerOffset }
        set { d.set(newValue, forKey: "staggerSeconds") }
    }

    /// When true, the video fills each display by cropping (panscan).
    /// When false, the video is letterboxed to preserve original framing.
    static var fillScreens: Bool {
        get { d.object(forKey: "fillScreens") as? Bool ?? true }
        set { d.set(newValue, forKey: "fillScreens") }
    }

    /// Per-screen enable: a set of NSScreen indices that should display the
    /// aquarium.  Empty (default) means "every screen".  Anthony can disable
    /// a single screen via the admin panel without unplugging it.
    static var disabledScreenIndices: Set<Int> {
        get {
            let arr = (d.array(forKey: "disabledScreenIndices") as? [Int]) ?? []
            return Set(arr)
        }
        set { d.set(Array(newValue), forKey: "disabledScreenIndices") }
    }

    /// Restore everything to factory.  Called by the admin panel's "Restore
    /// Defaults" button and by the `aquarium reset` CLI subcommand.
    static func resetAll() {
        for k in ["durationSeconds", "videoPath", "audioMuted", "volume",
                  "audioScreenIndex", "staggerSeconds", "fillScreens",
                  "disabledScreenIndices"] {
            d.removeObject(forKey: k)
        }
    }
}

// =============================================================================
// MARK: - Lock-state helpers
// =============================================================================

/// Returns `true` when the macOS login session is currently locked. Anthony's
/// 15-minute show timer only ticks while this is `false` — otherwise sleep
/// would burn through the timer on no one.
func isScreenLocked() -> Bool {
    guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
}

// =============================================================================
// MARK: - Player window (one per NSScreen)
// =============================================================================

/// A borderless NSWindow that's allowed to become key/main even while parked at
/// the .screenSaverWindow level.  Without these overrides, the OS would refuse
/// to send our window keyboard events and Anthony would be stuck again.
final class AquariumWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Content view that quits the whole app on ANY user input. This is the
/// safety belt — when in doubt, get out. Anthony was burned by the first
/// version that swallowed input. Here every plausible event is handled.
final class DismissOnAnyInputView: NSView {
    /// Closure run when the user does anything.  Set to NSApp.terminate(nil)
    /// at startup; pulled out as a closure to make the view testable.
    var onAnyInput: () -> Void = {}

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Mouse-moved events need to be explicitly enabled per-window in AppKit.
        window?.acceptsMouseMovedEvents = true
    }

    /// Same grace period the controller's event monitors use.  Without this
    /// the view's own input overrides would also catch the synthetic activation
    /// events and quit before the user saw anything.
    var readyForInputAt: Date = .distantFuture

    private func handle() {
        guard Date() > readyForInputAt else { return }
        onAnyInput()
    }

    override func keyDown(with event: NSEvent)            { handle() }
    override func mouseDown(with event: NSEvent)          { handle() }
    override func rightMouseDown(with event: NSEvent)     { handle() }
    override func otherMouseDown(with event: NSEvent)     { handle() }
    override func mouseMoved(with event: NSEvent)         { handle() }
    override func mouseDragged(with event: NSEvent)       { handle() }
    override func rightMouseDragged(with event: NSEvent)  { handle() }
    override func otherMouseDragged(with event: NSEvent)  { handle() }
    override func scrollWheel(with event: NSEvent)        { handle() }
}

// =============================================================================
// MARK: - The aquarium itself
// =============================================================================

/// Manages a set of fullscreen player windows, one per active NSScreen.
/// Owns the AVPlayer instances and the lifecycle of the 15-min show timer.
final class AquariumController {

    private var windows: [AquariumWindow] = []
    private var players: [AVPlayer] = []
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    /// Used to invalidate stale timers when the show is paused and resumed.
    /// We never call `Timer.invalidate()` — we instead capture the resume
    /// marker in the timer closure and bail if it no longer matches.
    private var lastResumeAt: Date?

    /// Effective duration for the current run (overridable from CLI / defaults).
    private let durationSeconds: TimeInterval

    /// Startup grace period (seconds).  Any input events during this window
    /// are ignored — necessary because `NSApp.activate` and the window
    /// creation cascade synthesize a couple of mouse-moved / focus events at
    /// launch which would otherwise trigger an instant terminate.  Anthony
    /// learned this the hard way: the binary "ran" for 80ms.  Five seconds
    /// is enough for AVPlayer's hardware decoder to finish warming up, for
    /// every monitor's window to settle at its final z-order, and for the
    /// terminal-launching scenario (where the user's cursor was already on
    /// the Sceptre and would otherwise immediately dismiss).
    private static let inputGracePeriod: TimeInterval = 5.0

    /// Date past which input is honored.  Set during `start()`.
    private var readyForInputAt: Date = .distantFuture

    init(durationSeconds: TimeInterval) {
        self.durationSeconds = durationSeconds
    }

    /// Spin up one window per active screen, kick off playback, install the
    /// global+local input monitors, and either start the 15-min timer (if the
    /// screen is unlocked) or wait for an unlock notification.
    func start() {
        // Set the grace deadline BEFORE we install monitors so the first
        // events the system synthesizes during activation are ignored.
        readyForInputAt = Date().addingTimeInterval(AquariumController.inputGracePeriod)
        installInputMonitors()
        buildWindows()
        // Force the app forward so our windows reliably take focus across
        // every Space — without this, Anthony's secondary displays sometimes
        // lost the focus race to whatever app already lived there.
        // `activate(ignoringOtherApps:)` is the supported call on Sonoma+;
        // the previous `.activateIgnoringOtherApps` option on NSRunningApplication
        // was deprecated and is a no-op now.
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])

        // Hook lock/unlock notifications so the timer respects "real" viewing
        // time.  See `isScreenLocked()` for why we care.
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                        object: nil, queue: .main) { [weak self] _ in self?.resume() }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
                        object: nil, queue: .main) { [weak self] _ in self?.pause() }

        if isScreenLocked() {
            pause()  // wait for next unlock to start the clock
        } else {
            resume() // ticking now
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Window construction
    // -------------------------------------------------------------------------

    private func buildWindows() {
        let disabled = AquariumDefaults.disabledScreenIndices
        let audioIdx = AquariumDefaults.audioScreenIndex
        let stagger = AquariumDefaults.staggerSeconds
        let videoURL = URL(fileURLWithPath: AquariumDefaults.videoPath)

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            // Anthony's video isn't on disk yet — bail with a visible message
            // rather than silently flashing black windows.
            let alert = NSAlert()
            alert.messageText = "Aquarium video not found"
            alert.informativeText = "Expected: \(videoURL.path)\n\n" +
                "Run the install script (or `aquarium fetch-video`) to download " +
                "and transcode the 4K HDR clip."
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        for (i, screen) in NSScreen.screens.enumerated() where !disabled.contains(i) {
            // Window: borderless, max-level, fills the entire NSScreen frame
            // including any notch area for native displays.
            let frame = screen.frame
            let w = AquariumWindow(contentRect: frame, styleMask: .borderless,
                                   backing: .buffered, defer: false, screen: screen)
            // Level: highest CGWindow level macOS exposes (`.maximumWindow`).
            // The ordinary `.screenSaverWindow` level (1000) was getting
            // demoted by the Window Server when our app's window overlapped
            // an actively-used display — confirmed via CGWindowListCopyWindowInfo
            // where the Sceptre window showed `kCGWindowIsOnscreen=false`
            // despite being at level 1000.  `.maximumWindow` (2147483630)
            // sits above every documented level and the Server stops
            // suppressing it.
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            w.backgroundColor = .black
            w.isOpaque = true
            w.hasShadow = false
            w.acceptsMouseMovedEvents = true
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.isMovable = false
            w.setFrame(frame, display: true)

            // Content view: quits the app on ANY input event AFTER the
            // startup grace period elapses.
            let view = DismissOnAnyInputView(frame: w.contentRect(forFrameRect: frame))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            view.onAnyInput = { NSApp.terminate(nil) }
            view.readyForInputAt = readyForInputAt

            // Player.  `automaticallyWaitsToMinimizeStalling = false` avoids
            // AVFoundation hesitating to keep its buffer happy — we already
            // have the whole file on disk, no network involved.
            let item = AVPlayerItem(url: videoURL)
            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = false
            player.actionAtItemEnd = .pause
            player.volume = (i == audioIdx && !AquariumDefaults.audioMuted)
                ? AquariumDefaults.volume : 0
            player.isMuted = (i != audioIdx) || AquariumDefaults.audioMuted

            // Seek to the per-screen offset BEFORE play() to avoid the
            // brief flash of the opening frame on lagging screens.
            let offset = Double(i) * stagger
            player.seek(to: CMTime(seconds: offset, preferredTimescale: 600))

            let layer = AVPlayerLayer(player: player)
            layer.frame = view.bounds
            layer.videoGravity = AquariumDefaults.fillScreens ? .resizeAspectFill : .resizeAspect
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            view.layer?.addSublayer(layer)

            w.contentView = view
            w.makeKeyAndOrderFront(nil)
            // `orderFrontRegardless` is the screensaver-style escape hatch —
            // ordinary makeKeyAndOrderFront won't force the Sceptre's window
            // forward when Safari (or any other app with a popup menu open)
            // is holding focus on that display.  Anthony hit this when his
            // mouse hovered over a Safari context menu at launch and the
            // main-display window came up below it (technically "on=false"
            // in CGWindowList terms — the Window Server skipped the paint).
            w.orderFrontRegardless()
            w.makeFirstResponder(view)

            windows.append(w)
            players.append(player)
        }

        // Post-creation re-order pass.  The Window Server sometimes drops the
        // "on screen" flag for the window that overlaps the currently-active
        // app's display.  Calling orderFrontRegardless again after every
        // window exists in the list — and after a short delay so AppKit's
        // own activation cascade has settled — reliably forces every screen
        // to paint.  Anthony's main display (Sceptre) was the consistent
        // victim of this until we added the second pass.
        for delay in [0.05, 0.25, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                for w in self.windows {
                    w.orderFrontRegardless()
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Input monitors (the "always escapable" guarantee)
    // -------------------------------------------------------------------------

    /// Install both local AND global event monitors so the app exits the moment
    /// the user does *anything*. Local catches events targeted at our windows;
    /// global catches everything else (other apps, the Finder desktop, etc.).
    private func installInputMonitors() {
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown,
                                           .otherMouseDown, .mouseMoved,
                                           .leftMouseDragged, .rightMouseDragged,
                                           .otherMouseDragged, .scrollWheel]
        // Same handler logic for both monitors: honor the startup grace
        // period.  Local monitor returns the event so AppKit can still route
        // it (we don't care; we're terminating anyway).
        let shouldDismiss = { [weak self] in
            (self?.readyForInputAt ?? .distantFuture) < Date()
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            if shouldDismiss() { NSApp.terminate(nil) }
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { _ in
            if shouldDismiss() { NSApp.terminate(nil) }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Pause / resume around lock/unlock
    // -------------------------------------------------------------------------

    /// Pause all players. Called on screen lock so the timer doesn't burn
    /// through the show while no one's watching.
    private func pause() {
        lastResumeAt = nil  // invalidates any pending terminate
        players.forEach { $0.pause() }
    }

    /// Resume playback and schedule the (Date-anchored) auto-quit timer.
    private func resume() {
        let now = Date()
        lastResumeAt = now
        players.forEach { $0.play() }
        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds) { [weak self] in
            // Captured-by-value marker: if the user locked & unlocked since
            // we scheduled, another resume() bumped `lastResumeAt`, and this
            // closure should NOT terminate the app.
            guard let self = self, self.lastResumeAt == now else { return }
            NSApp.terminate(nil)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Teardown
    // -------------------------------------------------------------------------

    /// AppKit calls into our AppDelegate at terminate time; this is the cleanup
    /// hook that releases AVFoundation's GPU-side resources promptly instead
    /// of waiting for process exit to garbage-collect them.
    func teardown() {
        for p in players { p.pause(); p.replaceCurrentItem(with: nil) }
        players.removeAll()
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        if let m = localEventMonitor  { NSEvent.removeMonitor(m) }
        if let m = globalEventMonitor { NSEvent.removeMonitor(m) }
    }
}

// =============================================================================
// MARK: - Settings (SwiftUI admin panel, opened via `--settings`)
// =============================================================================

/// SwiftUI form that exposes the settings most screensavers ship with.
/// Persisted via UserDefaults so the next launch picks them up automatically.
/// Anthony likes the macOS Settings-app aesthetic; this is a plain Form in a
/// fixed-width window to match.
struct AquariumSettingsView: View {
    @State private var durationMinutes: Double = AquariumDefaults.durationSeconds / 60
    @State private var audioMuted: Bool = AquariumDefaults.audioMuted
    @State private var volume: Double = Double(AquariumDefaults.volume)
    @State private var audioScreenIndex: Int = AquariumDefaults.audioScreenIndex
    @State private var staggerMinutes: Double = AquariumDefaults.staggerSeconds / 60
    @State private var fillScreens: Bool = AquariumDefaults.fillScreens
    @State private var videoPath: String = AquariumDefaults.videoPath

    private let screens = NSScreen.screens.enumerated().map { i, s in
        (index: i, name: s.localizedName)
    }

    var body: some View {
        Form {
            Section("Show") {
                HStack {
                    Slider(value: $durationMinutes, in: 1...120, step: 1)
                    Text("\(Int(durationMinutes)) min").monospacedDigit().frame(width: 60, alignment: .trailing)
                }
                Toggle("Fill each screen (crop) — off uses letterbox",
                       isOn: $fillScreens)
                HStack {
                    Text("Stagger between screens")
                    Slider(value: $staggerMinutes, in: 0...10, step: 0.5)
                    Text("\(staggerMinutes, specifier: "%.1f") min").monospacedDigit().frame(width: 70, alignment: .trailing)
                }
            }

            Section("Audio") {
                Toggle("Mute all audio", isOn: $audioMuted)
                HStack {
                    Text("Volume")
                    Slider(value: $volume, in: 0...1).disabled(audioMuted)
                    Text("\(Int(volume * 100))%").monospacedDigit().frame(width: 50, alignment: .trailing)
                }
                Picker("Audio output display", selection: $audioScreenIndex) {
                    ForEach(screens, id: \.index) { s in
                        Text("\(s.index): \(s.name)").tag(s.index)
                    }
                }.disabled(audioMuted)
            }

            Section("Source") {
                HStack {
                    TextField("Video path", text: $videoPath)
                    Button("Choose…") { pickVideo() }
                }
            }

            Section {
                HStack {
                    Button("Restore Defaults") {
                        AquariumDefaults.resetAll(); reload()
                    }
                    Spacer()
                    Button("Save") { save() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560, height: 540)
    }

    private func save() {
        AquariumDefaults.durationSeconds = durationMinutes * 60
        AquariumDefaults.audioMuted = audioMuted
        AquariumDefaults.volume = Float(volume)
        AquariumDefaults.audioScreenIndex = audioScreenIndex
        AquariumDefaults.staggerSeconds = staggerMinutes * 60
        AquariumDefaults.fillScreens = fillScreens
        AquariumDefaults.videoPath = videoPath
        NSApp.keyWindow?.close()
    }

    private func reload() {
        durationMinutes = AquariumDefaults.durationSeconds / 60
        audioMuted = AquariumDefaults.audioMuted
        volume = Double(AquariumDefaults.volume)
        audioScreenIndex = AquariumDefaults.audioScreenIndex
        staggerMinutes = AquariumDefaults.staggerSeconds / 60
        fillScreens = AquariumDefaults.fillScreens
        videoPath = AquariumDefaults.videoPath
    }

    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            videoPath = url.path
        }
    }
}

/// Brings up the settings window as a normal floating panel.  Returns the
/// window so the caller can hold a strong reference (otherwise SwiftUI's
/// hosting window deallocates the moment we return).
@discardableResult
func openSettingsWindow() -> NSWindow {
    let hosting = NSHostingController(rootView: AquariumSettingsView())
    let win = NSWindow(contentViewController: hosting)
    win.title = "Aquarium — Preferences"
    win.styleMask = [.titled, .closable, .miniaturizable]
    win.center()
    win.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return win
}

// =============================================================================
// MARK: - App delegate
// =============================================================================

/// Top-level coordinator.  Holds the controller (for the screensaver mode)
/// or the settings window (for `--settings` mode) so neither gets ARC-released
/// prematurely.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: AquariumController?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ note: Notification) {
        // Parse arguments fresh here so the CLI surface stays one place.
        let args = CommandLine.arguments
        if args.contains("--settings") {
            settingsWindow = openSettingsWindow()
            return
        }
        if args.contains("--version") {
            print("Aquarium 1.0.0 by Anthony Harwelik"); NSApp.terminate(nil); return
        }

        // Allow `--duration MIN` to override defaults for one run only.
        var duration = AquariumDefaults.durationSeconds
        if let i = args.firstIndex(of: "--duration"), i + 1 < args.count,
           let v = Double(args[i + 1]) {
            duration = v * 60
        }

        controller = AquariumController(durationSeconds: duration)
        controller?.start()
    }

    func applicationWillTerminate(_ note: Notification) {
        controller?.teardown()
    }
}

// =============================================================================
// MARK: - Entry point
// =============================================================================

// CLI front-door for non-GUI subcommands (so users don't always pay the cost
// of bringing up the AppKit run loop).
let argv = CommandLine.arguments
if argv.contains("--help") || argv.contains("-h") {
    print("""
    Aquarium — a real coral-reef screensaver for Apple Silicon Macs.
                by Anthony Harwelik

    Usage:
      aquarium                  Start the screensaver (default 15 min)
      aquarium --duration MIN   Override duration for this run (e.g. 30)
      aquarium --settings       Open the preferences window
      aquarium --version        Print version
      aquarium --help           This text

    Run `aquarium reset-defaults` (via the wrapper script in scripts/aquarium)
    to factory-reset all settings, or use the "Restore Defaults" button in
    the preferences panel.
    """)
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)   // Dock icon + ⌘-Tab presence so Anthony can always reach the app
let delegate = AppDelegate()
app.delegate = delegate
app.run()
