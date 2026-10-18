import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let settings = Settings.shared
    private let model = PrompterModel.shared
    private let store = ScriptStore.shared

    private var statusItem: NSStatusItem!
    private var panel: PrompterPanel!
    private var editorWindow: NSWindow?
    private var bag = Set<AnyCancellable>()
    private var isLayingOut = false

    private var prompterVisible: Bool { panel?.isVisible ?? false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.clampAll()
        buildMainMenu()
        buildStatusItem()
        buildPanel()

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &bag)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.layoutPanel()
        }

        if store.isFirstLaunch || CommandLine.arguments.contains("--open-editor") {
            openEditor()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openEditor()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    // MARK: Menus

    private func buildMainMenu() {
        // Accessory apps don't show a menu bar, but key equivalents (copy/paste/undo) still need it.
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Teleprompter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Teleprompter")
            button.toolTip = "Teleprompter"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == statusItem.menu else { return }
        menu.removeAllItems()

        menu.addItem(item(prompterVisible ? "Hide Prompter" : "Show Prompter", #selector(togglePrompter), "p"))
        let playTitle: String
        if !prompterVisible { playTitle = "Start" }
        else if model.running || model.countdownRemaining > 0 { playTitle = "Pause" }
        else if model.offset > 0 && !model.finished { playTitle = "Resume" }
        else { playTitle = "Start" }
        menu.addItem(item(playTitle, #selector(playPause), " "))
        menu.addItem(item("Restart from the Top", #selector(restart), "r"))
        menu.addItem(.separator())

        let scriptsItem = NSMenuItem(title: "Script", action: nil, keyEquivalent: "")
        let scriptsMenu = NSMenu()
        for s in store.scripts {
            let i = NSMenuItem(title: s.title.isEmpty ? "Untitled" : s.title, action: #selector(chooseScript(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = s.id
            i.state = (s.id == store.current?.id) ? .on : .off
            scriptsMenu.addItem(i)
        }
        scriptsItem.submenu = scriptsMenu
        menu.addItem(scriptsItem)

        let notch = item("Under the Camera", #selector(setNotchMode), "")
        notch.state = settings.floating ? .off : .on
        menu.addItem(notch)
        let floating = item("Floating Window", #selector(setFloatingMode), "")
        floating.state = settings.floating ? .on : .off
        menu.addItem(floating)
        let voice = item("Voice Mode", #selector(toggleVoice), "")
        voice.state = settings.voiceMode ? .on : .off
        menu.addItem(voice)
        menu.addItem(.separator())
        menu.addItem(item("Open Editor…", #selector(openEditor), "e"))
        menu.addItem(.separator())
        menu.addItem(item("Quit Teleprompter", #selector(quit), "q"))
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    // MARK: Actions

    @objc func togglePrompter() {
        if prompterVisible { hidePrompter() } else { showPrompter() }
    }

    @objc func playPause() {
        if !prompterVisible {
            showPrompter()
            model.start()
        } else {
            model.togglePause()
        }
    }

    @objc func restart() {
        showPrompter()
        model.restart()
    }

    @objc func chooseScript(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        store.selectedID = id
        model.pause()
        model.offset = 0
    }

    @objc func setNotchMode() { settings.floating = false }
    @objc func setFloatingMode() { settings.floating = true }
    @objc func toggleVoice() { settings.voiceMode.toggle() }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func openEditor() {
        if editorWindow == nil {
            let hosting = NSHostingController(rootView: EditorView(onStart: { [weak self] in
                self?.showPrompter()
                self?.model.start()
            }))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Teleprompter"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.setContentSize(NSSize(width: 980, height: 600))
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("EditorWindow")
            w.center()
            editorWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        editorWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: Prompter window

    private func buildPanel() {
        panel = PrompterPanel()
        panel.delegate = self
        panel.keyHandler = { [weak self] e in self?.model.handleKey(e) ?? false }
        panel.scrollHandler = { [weak self] e in
            guard let self else { return }
            let dy = e.hasPreciseScrollingDeltas ? e.scrollingDeltaY : e.scrollingDeltaY * 10
            self.model.scroll(by: -dy)
        }
        let view = PrompterView(onResize: { [weak self] size in self?.userResized(to: size) })
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        panel.contentView = hosting
        layoutPanel()
    }

    func showPrompter() {
        layoutPanel()
        panel.orderFrontRegardless()
        panel.makeKey()
        updateVoice()
    }

    func hidePrompter() {
        model.pause()
        panel.orderOut(nil)
        updateVoice()
    }

    private func settingsChanged() {
        layoutPanel()
        updateVoice()
    }

    private func updateVoice() {
        if settings.voiceMode && (prompterVisible || editorWindow?.isVisible == true) {
            model.voice.start()
        } else {
            model.voice.stop()
        }
    }

    /// The screen with the camera notch, or the main screen.
    private var targetScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func layoutPanel() {
        guard let panel, let screen = targetScreen else { return }
        isLayingOut = true
        defer { isLayingOut = false }

        if settings.floating {
            model.topInset = 0
            panel.level = .floating
            panel.isMovable = true
            let size = NSSize(width: settings.width, height: settings.height)
            var topLeft: NSPoint
            if let saved = UserDefaults.standard.string(forKey: "floatingTopLeft") {
                topLeft = NSPointFromString(saved)
            } else {
                let vf = screen.visibleFrame
                topLeft = NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - 40)
            }
            // Keep it on some screen.
            if !NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -20, dy: -20).contains(topLeft) }) {
                let vf = screen.visibleFrame
                topLeft = NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - 40)
            }
            panel.setFrame(NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height),
                           display: true)
        } else {
            panel.level = .statusBar
            panel.isMovable = false
            var inset = screen.safeAreaInsets.top
            var minWidth: CGFloat = 0
            if inset > 0 {
                if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                    minWidth = screen.frame.width - left.width - right.width + 40
                }
            } else {
                inset = screen.frame.maxY - screen.visibleFrame.maxY
                if inset <= 0 { inset = 24 }
            }
            model.topInset = inset
            let w = max(CGFloat(settings.width), minWidth)
            let h = inset + CGFloat(settings.height)
            let f = screen.frame
            panel.setFrame(NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h), display: true)
        }
    }

    private func userResized(to size: NSSize) {
        guard settings.floating else { return }
        settings.width = min(max(Double(size.width), Settings.widthRange.lowerBound), Settings.widthRange.upperBound)
        settings.height = min(max(Double(size.height), Settings.heightRange.lowerBound), Settings.heightRange.upperBound)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isLayingOut, settings.floating, let panel else { return }
        let f = panel.frame
        UserDefaults.standard.set(NSStringFromPoint(NSPoint(x: f.minX, y: f.maxY)), forKey: "floatingTopLeft")
    }
}
