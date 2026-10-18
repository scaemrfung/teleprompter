import SwiftUI
import AppKit

/// All user preferences, stored in UserDefaults on this Mac only.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// Scroll speed in points per second.
    @Published var speed: Double { didSet { defaults.set(speed, forKey: "speed") } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    @Published var textColorHex: String { didSet { defaults.set(textColorHex, forKey: "textColorHex") } }
    @Published var width: Double { didSet { defaults.set(width, forKey: "width") } }
    @Published var height: Double { didSet { defaults.set(height, forKey: "height") } }
    @Published var floating: Bool { didSet { defaults.set(floating, forKey: "floating") } }
    @Published var countdown: Int { didSet { defaults.set(countdown, forKey: "countdown") } }
    @Published var pauseOnHover: Bool { didSet { defaults.set(pauseOnHover, forKey: "pauseOnHover") } }
    @Published var mirror: Bool { didSet { defaults.set(mirror, forKey: "mirror") } }
    @Published var voiceMode: Bool { didSet { defaults.set(voiceMode, forKey: "voiceMode") } }
    /// 0 = needs a loud voice, 1 = picks up quiet speech.
    @Published var voiceSensitivity: Double { didSet { defaults.set(voiceSensitivity, forKey: "voiceSensitivity") } }

    private init() {
        defaults.register(defaults: [
            "speed": 40.0,
            "fontSize": 30.0,
            "textColorHex": "#FFFFFF",
            "width": 520.0,
            "height": 180.0,
            "floating": false,
            "countdown": 3,
            "pauseOnHover": true,
            "mirror": false,
            "voiceMode": false,
            "voiceSensitivity": 0.5,
        ])
        speed = defaults.double(forKey: "speed")
        fontSize = defaults.double(forKey: "fontSize")
        textColorHex = defaults.string(forKey: "textColorHex") ?? "#FFFFFF"
        width = defaults.double(forKey: "width")
        height = defaults.double(forKey: "height")
        floating = defaults.bool(forKey: "floating")
        countdown = defaults.integer(forKey: "countdown")
        pauseOnHover = defaults.bool(forKey: "pauseOnHover")
        mirror = defaults.bool(forKey: "mirror")
        voiceMode = defaults.bool(forKey: "voiceMode")
        voiceSensitivity = defaults.double(forKey: "voiceSensitivity")
    }

    static let speedRange: ClosedRange<Double> = 5...300
    static let fontRange: ClosedRange<Double> = 14...96
    static let widthRange: ClosedRange<Double> = 280...1600
    static let heightRange: ClosedRange<Double> = 80...900

    var textColor: Color {
        get { Color(nsColor: NSColor(hex: textColorHex) ?? .white) }
        set { textColorHex = NSColor(newValue).hexString }
    }

    func clampAll() {
        speed = min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        fontSize = min(max(fontSize, Self.fontRange.lowerBound), Self.fontRange.upperBound)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? .white
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
