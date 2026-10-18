import AppKit
import Combine
import QuartzCore

/// Scrolling state for the prompter.
final class PrompterModel: ObservableObject {
    static let shared = PrompterModel()

    @Published var offset: CGFloat = 0
    @Published private(set) var running = false
    @Published private(set) var countdownRemaining = 0
    @Published private(set) var finished = false
    @Published var hovering = false
    @Published var contentHeight: CGFloat = 0
    @Published var viewportHeight: CGFloat = 0
    /// Space at the top of the window that is covered by the notch / menu bar.
    @Published var topInset: CGFloat = 0

    let voice = VoiceLevel()
    private let settings = Settings.shared
    private var ticker: Timer?
    private var countdownTimer: Timer?
    private var lastTick: CFTimeInterval = CACurrentMediaTime()
    private var bag = Set<AnyCancellable>()

    var text: String { ScriptStore.shared.current?.body ?? "" }

    /// True when the text is actually moving right now.
    var isMoving: Bool {
        running && countdownRemaining == 0 && !heldByHover && !heldByVoice
    }
    var heldByHover: Bool { settings.pauseOnHover && hovering }
    var heldByVoice: Bool { settings.voiceMode && !voice.speaking }

    private init() {
        voice.sensitivity = settings.voiceSensitivity
        settings.$voiceSensitivity.sink { [weak self] v in self?.voice.sensitivity = v }.store(in: &bag)
        // Re-publish voice changes so views update.
        voice.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        ScriptStore.shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    // MARK: Controls

    func start() {
        countdownTimer?.invalidate()
        offset = 0
        finished = false
        running = false
        countdownRemaining = max(settings.countdown, 0)
        if countdownRemaining == 0 {
            running = true
            return
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.countdownRemaining -= 1
            if self.countdownRemaining <= 0 {
                self.countdownRemaining = 0
                timer.invalidate()
                self.running = true
            }
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
    }

    func togglePause() {
        if countdownRemaining > 0 {
            countdownTimer?.invalidate()
            countdownRemaining = 0
            running = true
            return
        }
        if finished || (!running && offset == 0) {
            start()
            return
        }
        running.toggle()
    }

    func pause() {
        countdownTimer?.invalidate()
        countdownRemaining = 0
        running = false
    }

    func restart() { start() }

    func jump(lines: CGFloat) {
        let step = CGFloat(settings.fontSize) * 1.3 * lines
        offset = min(max(offset + step, 0), max(contentHeight, 0))
        if offset < contentHeight { finished = false }
    }

    func scroll(by delta: CGFloat) {
        offset = min(max(offset + delta, 0), max(contentHeight, 0))
        if offset < contentHeight { finished = false }
    }

    func changeSpeed(by delta: Double) {
        settings.speed = min(max(settings.speed + delta, Settings.speedRange.lowerBound), Settings.speedRange.upperBound)
    }

    func changeFont(by delta: Double) {
        settings.fontSize = min(max(settings.fontSize + delta, Settings.fontRange.lowerBound), Settings.fontRange.upperBound)
    }

    // MARK: Keyboard

    /// Returns true if the key was handled.
    func handleKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        guard mods.isEmpty else { return false }
        switch event.keyCode {
        case 49: togglePause(); return true                 // space
        case 126: changeSpeed(by: 5); return true            // up
        case 125: changeSpeed(by: -5); return true           // down
        case 123: jump(lines: -2); return true               // left
        case 124: jump(lines: 2); return true                // right
        case 53: pause(); return true                        // escape
        default: break
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "r": restart(); return true
        case "]", "=", "+": changeFont(by: 2); return true
        case "[", "-": changeFont(by: -2); return true
        default: return false
        }
    }

    // MARK: Ticker

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 0.1)
        lastTick = now
        guard isMoving else { return }
        offset += CGFloat(settings.speed * dt)
        if contentHeight > 0, offset >= contentHeight {
            offset = contentHeight
            running = false
            finished = true
        }
    }
}
