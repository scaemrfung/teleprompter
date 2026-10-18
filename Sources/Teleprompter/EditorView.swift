import SwiftUI

struct EditorView: View {
    @ObservedObject var store = ScriptStore.shared
    @ObservedObject var settings = Settings.shared
    var onStart: () -> Void
    @State private var showSettings = true
    @State private var confirmDelete = false

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedID) {
                ForEach(store.scripts) { script in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(script.title.isEmpty ? "Untitled" : script.title).lineLimit(1)
                        Text(script.modified, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(Optional(script.id))
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button { store.addScript() } label: { Label("New Script", systemImage: "plus") }
                        .help("New script")
                }
            }
        } detail: {
            if let id = store.selectedID, let script = store.binding(for: id) {
                ScriptDetail(script: script, onStart: onStart)
                    .toolbar {
                        ToolbarItemGroup {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Delete Script", systemImage: "trash")
                            }
                            .help("Delete this script")
                            Button { showSettings.toggle() } label: {
                                Label("Prompter Settings", systemImage: "slider.horizontal.3")
                            }
                            .help("Show or hide prompter settings")
                        }
                    }
                    .confirmationDialog("Delete “\(script.wrappedValue.title)”?", isPresented: $confirmDelete) {
                        Button("Delete", role: .destructive) { store.remove(id: id) }
                    } message: {
                        Text("This script will be removed from this Mac.")
                    }
            } else {
                VStack(spacing: 12) {
                    Text("No script selected").font(.title3).foregroundStyle(.secondary)
                    Button("New Script") { store.addScript() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .inspector(isPresented: $showSettings) {
            SettingsForm()
                .inspectorColumnWidth(min: 250, ideal: 280, max: 360)
        }
        .frame(minWidth: 760, minHeight: 460)
    }
}

private struct ScriptDetail: View {
    @Binding var script: Script
    @ObservedObject var settings = Settings.shared
    var onStart: () -> Void

    private var wordCount: Int {
        script.body.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Title", text: $script.title)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
            TextEditor(text: $script.body)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Text("\(wordCount) words · about \(max(1, Int((Double(wordCount) / 140).rounded()))) min to read aloud")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button {
                    onStart()
                } label: {
                    Label("Start Prompter", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }
}

struct SettingsForm: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var model = PrompterModel.shared

    var body: some View {
        Form {
            Section("Position") {
                Picker("Show", selection: $settings.floating) {
                    Text("Under the camera").tag(false)
                    Text("Floating window").tag(true)
                }
                .pickerStyle(.radioGroup)
                labeledSlider("Width", value: $settings.width, range: Settings.widthRange, format: "%.0f")
                labeledSlider("Height", value: $settings.height, range: Settings.heightRange, format: "%.0f")
            }
            Section("Text") {
                labeledSlider("Speed", value: $settings.speed, range: Settings.speedRange, format: "%.0f")
                labeledSlider("Size", value: $settings.fontSize, range: Settings.fontRange, format: "%.0f pt")
                ColorPicker("Colour", selection: Binding(get: { settings.textColor },
                                                         set: { settings.textColor = $0 }),
                            supportsOpacity: false)
                Toggle("Mirror text (for glass teleprompters)", isOn: $settings.mirror)
            }
            Section("Playback") {
                Stepper("Countdown: \(settings.countdown) s", value: $settings.countdown, in: 0...10)
                Toggle("Pause when the mouse is over the text", isOn: $settings.pauseOnHover)
            }
            Section("Voice mode") {
                Toggle("Scroll only while I'm talking", isOn: $settings.voiceMode)
                if settings.voiceMode {
                    labeledSlider("Sensitivity", value: $settings.voiceSensitivity, range: 0...1, format: "%.0f%%", scale: 100)
                    HStack {
                        Text("Mic level")
                        ProgressView(value: model.voice.level)
                        Circle().fill(model.voice.speaking ? Color.green : Color.gray).frame(width: 8, height: 8)
                    }
                    if !model.voice.status.isEmpty {
                        Text(model.voice.status).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Uses the microphone level on this Mac only. Nothing is recorded or sent anywhere.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Keyboard (click the prompter first)") {
                VStack(alignment: .leading, spacing: 4) {
                    shortcut("Space", "Pause / resume")
                    shortcut("↑ ↓", "Faster / slower")
                    shortcut("← →", "Jump back / ahead")
                    shortcut("[ ]", "Smaller / bigger text")
                    shortcut("R", "Restart from the top")
                    shortcut("Esc", "Pause")
                    shortcut("Scroll", "Move the text by hand")
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                               format: String, scale: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue * scale)).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func shortcut(_ key: String, _ what: String) -> some View {
        HStack {
            Text(key).fontWeight(.semibold).frame(width: 52, alignment: .leading)
            Text(what).foregroundStyle(.secondary)
        }
    }
}
