# Raining Code

A simple Windows desktop app that turns your screen into bright fullscreen raining code.

## What It Does

- Shows a fullscreen raining-code effect on demand.
- Keeps a lightweight background helper ready so the hotkey works without reopening the app.
- Starts in bright red by default, with many extra colors and a rainbow mode.
- Lets you pick `Small`, `Medium`, `Large`, or `Jumbo` code size.
- Keeps the helper hidden until you use the hotkey, with an optional tray icon if you want one.

## Default Controls

- Show or hide effect: `Ctrl+Alt+M`
- Quit helper: `Ctrl+Alt+Q`
- Hide locally: `Esc`
- Cycle colors locally: `C`
- Cycle size locally: `S`
- Pause locally: `Space`

`Fn+M` is not the shipped default because Windows usually does not expose `Fn` as a normal software-detectable key.

## Simplest Install

If Windows blocks unsigned `.exe` builds on your machine, use the lightweight install flow in [release](</C:/Users/super/OneDrive/Desktop/codex first project/release>):

- `Install Raining Code.cmd`
  Installs the lightweight version into your user profile, adds desktop shortcuts, and enables startup so the hotkey helper is always ready.
- `Launch Raining Code.cmd`
  Starts the lightweight hotkey helper immediately.
- `Raining Code Settings.cmd`
  Opens the settings window for startup, look, tray visibility, and hotkeys.
- `Uninstall Raining Code.cmd`
  Removes the lightweight install from this PC.

After the lightweight install:

- Toggle the effect anytime: `Ctrl+Alt+M`
- Quit the background helper: `Ctrl+Alt+Q`
- Change the mapping later: run `Raining Code Settings`

Fastest file to share:

- `Raining Code Lightweight.zip`
  A lean bundle with only the lightweight install path and instructions.

## Shareable Builds

After running:

```powershell
npm.cmd run dist
```

the Windows build artifacts are written to [release](</C:/Users/super/OneDrive/Desktop/codex first project/release>):

- `Raining Code-Setup-0.1.0-x64.exe`
  A guided Windows installer.
- `Raining Code-Portable-0.1.0-x64.exe`
  A single-file portable build that can be shared directly.
- `win-unpacked/`
  The unpacked app folder for local inspection or manual launch.

## Development

```powershell
npm.cmd install
npm.cmd run dev
```

Useful checks:

```powershell
npm.cmd run typecheck
npm.cmd run build
npm.cmd run dist
```

## Notes

- Builds are currently unsigned, so Windows may show SmartScreen warnings when shared broadly.
- The lightweight helper renders the fullscreen effect directly, so there is no settings panel on top of the animation.
- The settings window now includes plain-English tabs for `General`, `Look`, and `Hotkeys`.
- The `Look` tab lets you choose from many colors and four code sizes, and you can still cycle them live with `C` and `S`.
