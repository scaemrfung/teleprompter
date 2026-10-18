import Foundation
import SwiftUI

struct Script: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var body: String
    var modified = Date()
}

/// Saves scripts as a JSON file in ~/Library/Application Support/Teleprompter.
/// Nothing ever leaves the Mac.
final class ScriptStore: ObservableObject {
    static let shared = ScriptStore()

    @Published var scripts: [Script] = [] { didSet { scheduleSave() } }
    @Published var selectedID: UUID? {
        didSet { UserDefaults.standard.set(selectedID?.uuidString, forKey: "selectedScript") }
    }

    private(set) var isFirstLaunch = false
    private var pendingSave: DispatchWorkItem?

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Teleprompter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scripts.json")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = decoded
        }
        if scripts.isEmpty {
            isFirstLaunch = true
            scripts = [Script(title: "Welcome", body: Self.welcomeText)]
        }
        if let raw = UserDefaults.standard.string(forKey: "selectedScript"),
           let id = UUID(uuidString: raw), scripts.contains(where: { $0.id == id }) {
            selectedID = id
        } else {
            selectedID = scripts.first?.id
        }
        pendingSave?.cancel()
        saveNow()
    }

    var current: Script? {
        scripts.first(where: { $0.id == selectedID }) ?? scripts.first
    }

    func binding(for id: UUID) -> Binding<Script>? {
        guard scripts.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.scripts.first(where: { $0.id == id }) ?? Script(title: "", body: "") },
            set: { newValue in
                if let i = self.scripts.firstIndex(where: { $0.id == id }) {
                    var updated = newValue
                    updated.modified = Date()
                    self.scripts[i] = updated
                }
            }
        )
    }

    @discardableResult
    func addScript() -> Script {
        let s = Script(title: "New Script", body: "")
        scripts.append(s)
        selectedID = s.id
        return s
    }

    func remove(id: UUID) {
        scripts.removeAll { $0.id == id }
        if selectedID == id { selectedID = scripts.first?.id }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static let welcomeText = """
    Welcome to Teleprompter!

    Your script appears right under the camera, so you can read it while looking into the lens.

    Press the space bar to pause or resume. Use the up and down arrows to change the speed, and the left and right arrows to jump back or ahead.

    Move your mouse over the text to pause it. Move it away to keep going.

    Turn on Voice Mode and the text only moves while you are talking.

    Open the editor from the menu bar icon to write your own scripts. Have a great recording!
    """
}
