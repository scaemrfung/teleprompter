import AVFoundation
import Combine
import Foundation

/// Listens to the microphone level on this Mac (no recording, nothing saved,
/// nothing sent anywhere) and reports whether the user is currently speaking.
final class VoiceLevel: ObservableObject {
    @Published private(set) var speaking = false
    @Published private(set) var level: Double = 0      // 0...1 for the meter
    @Published private(set) var status = ""
    @Published private(set) var isListening = false

    var sensitivity: Double = 0.5
    /// How long the text keeps moving after the voice stops (seconds).
    var holdTime: TimeInterval = 0.8

    private let engine = AVAudioEngine()
    private var lastVoice = Date.distantPast
    private var decayTimer: Timer?

    func start() {
        guard !isListening else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            status = "Waiting for microphone permission…"
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted { self.begin() } else { self.denied() }
                }
            }
        default:
            denied()
        }
    }

    private func denied() {
        status = "Microphone is off. Turn it on in System Settings › Privacy & Security › Microphone."
        isListening = false
    }

    private func begin() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            status = "No microphone found."
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            var sum: Float = 0
            for i in 0..<n { sum += data[i] * data[i] }
            let rms = sqrt(sum / Float(n))
            let db = 20 * log10(max(rms, 0.000_001))
            DispatchQueue.main.async { self?.update(db: Double(db)) }
        }
        engine.prepare()
        do {
            try engine.start()
            isListening = true
            status = "Listening"
            decayTimer?.invalidate()
            decayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.refreshSpeaking()
            }
        } catch {
            input.removeTap(onBus: 0)
            status = "Could not start the microphone."
        }
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        decayTimer?.invalidate()
        decayTimer = nil
        isListening = false
        speaking = false
        level = 0
        status = ""
    }

    /// Threshold in dB: high sensitivity hears quieter speech.
    private var threshold: Double { -28 - sensitivity * 30 }

    private func update(db: Double) {
        level = min(max((db + 70) / 60, 0), 1)
        if db > threshold { lastVoice = Date() }
        refreshSpeaking()
    }

    private func refreshSpeaking() {
        let now = Date().timeIntervalSince(lastVoice) < holdTime
        if now != speaking { speaking = now }
    }
}
