# Teleprompter

A small, free teleprompter for the Mac. Your script scrolls in a dark strip that hangs from the top of the screen, right under the camera, so you can read while looking into the lens.

## Download and install

1. Go to the [latest release](https://github.com/scaemrfung/teleprompter/releases/latest) and download **Teleprompter.dmg**.
2. Open the DMG and drag **Teleprompter** onto the **Applications** folder.
3. **First launch:** the app isn't signed by Apple, so macOS will show a warning.
   - Open Applications, **right-click** (or Control-click) Teleprompter and choose **Open**, then click **Open** again.
   - If it still won't open, go to **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to Teleprompter.

Needs macOS 14 Sonoma or newer. Works on Apple Silicon and Intel Macs.

## Using it

Teleprompter lives in the **menu bar** (the icon with lines of text). It has no Dock icon. From the menu you can show or hide the prompter, start or pause, pick a script, switch between **Under the Camera** and **Floating Window**, turn on **Voice Mode**, and open the **editor**.

- **Editor:** write and save as many scripts as you like. Press **⌘↩** or **Start Prompter** to begin.
- **Countdown** before the text starts moving (0–10 seconds).
- **Settings** (in the editor's side panel): speed, text size, text colour, width and height, mirror text, pause on hover.
- **Floating window:** drag the bar at the top to move it, drag the bottom-right corner to resize it.
- **Voice mode:** the text only moves while you're talking and stops when you stop. It uses the microphone level on your Mac. Nothing is recorded or sent anywhere. macOS asks for microphone permission the first time.
- **Hidden from screen sharing:** the prompter is marked as not shareable, so it shouldn't show up in screen shares, recordings or screenshots. Some apps and newer macOS versions may handle this differently, so do a quick test recording first.

### Keyboard (click the prompter first)

| Key | Does |
| --- | --- |
| Space | Pause / resume (clicking the text works too) |
| ↑ / ↓ | Faster / slower |
| ← / → | Jump back / ahead |
| [ / ] | Smaller / bigger text |
| R | Restart from the top |
| Esc | Pause |
| Scroll | Move the text by hand |

Moving the mouse over the text pauses it (you can turn this off).

## Privacy

Scripts are saved in `~/Library/Application Support/Teleprompter` on your Mac. No accounts, no internet, no analytics.

## Building from source

On a Mac with Xcode 15 or newer:

```sh
./scripts/build_dmg.sh        # makes dist/Teleprompter.app and dist/Teleprompter.dmg
./scripts/smoke_test.sh       # mounts the DMG and launches the app
```

GitHub Actions builds the DMG on every push (download it from the run's artifacts). Pushing a tag like `v1.0.0` attaches the DMG to a GitHub release.
