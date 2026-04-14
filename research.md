# Raining Code Research Brief

## Project Goal

Build a very simple Windows desktop app that launches as an installable `.exe` and shows a fullscreen "Matrix-style" raining-code visualizer. The default look should be bright red, with optional rainbow or multi-color cycling from settings. The app should be easy to install, easy to exit, and simple to configure through a hotkey the user can remap.

This should feel like a polished visual effect first, and a product framework second. Keep the first version focused on one strong effect, one reliable hotkey path, and one clear settings flow.

## Recommendation

Use **Electron + TypeScript + Vite + Canvas 2D + electron-builder (NSIS installer)**.

Why this stack fits:

- It works well with the current environment because Node.js is available and no .NET or Python toolchain is required.
- Electron gives us straightforward Windows hotkey registration, fullscreen and always-on-top window control, tray support, and a mature packaging path.
- Canvas 2D is enough for a visually strong code-rain effect without the complexity of WebGL or a native rendering engine.
- `electron-builder` can produce a normal Windows installer `.exe` and supports code signing later if the app is distributed beyond local use.

## Implementation Options Compared

| Option | Fit | Pros | Cons |
| --- | --- | --- | --- |
| Electron + Vite + Canvas 2D | Best fit | Fast to build in Node, simple hotkeys, simple installer path, good enough performance for one fullscreen effect | Larger runtime than native apps |
| Tauri + WebView2 | Good if size is the top priority | Small binaries, modern shell, web UI support | Requires Rust and Windows build dependencies; more setup than we need right now |
| Native Win32 / WinUI / C# | Technically strong but not ideal here | Best native Windows control | More implementation work, different toolchain, slower iteration |

For this project, Electron is the practical choice. The app is mostly a fullscreen animated surface with a small settings UI, so Electron's overhead is acceptable and the development path stays simple.

## Core Architecture

Keep the app split into three small parts:

- **Main process**: app lifecycle, hotkey registration, tray icon, window creation, settings load/save.
- **Preload bridge**: expose only the small settings and control API the renderer needs.
- **Renderer**: fullscreen canvas animation plus a minimal settings screen.

This separation matters because the visualizer should stay isolated from the app shell, and the settings UI should not need direct access to Node APIs.

## Hotkey Strategy

The user asked for `(Fn M)` as the default trigger, but that is not a reliable software hotkey on Windows.

### Fn feasibility issue

`Fn` is usually handled by laptop keyboard firmware or vendor software before Windows ever sees the key event. Windows hotkey APIs work with virtual-key codes and accelerators, and Microsoft's virtual-key table does not define a standard `VK_FN` key. Electron's `globalShortcut` also registers OS-level accelerators, not raw hardware-layer Fn states. In practice, that means the app should **not** depend on `Fn` being detectable.

### Practical recommendation

- Use a Windows-detectable default such as `Ctrl+Alt+M` or `Alt+Shift+M`.
- Let users remap the hotkey from a capture UI in settings.
- Validate registration immediately and show a clear warning if the chosen shortcut conflicts with another app.
- Provide a separate emergency exit hotkey, such as `Esc` locally plus a global fallback like `Ctrl+Alt+Q`.

If a user's keyboard vendor software exposes some special media command, we can support it later as an extra convenience, but it should not be the primary trigger path.

## Windowing / Overlay Behavior

The visualizer should open as a borderless fullscreen window with a black background, always on top when active.

Recommended behavior:

- Start hidden or in a tray-backed idle state.
- Show the visualizer on the hotkey.
- Use fullscreen on the active monitor for the simplest first version.
- Keep a visible escape route: `Esc`, tray menu, and a global quit shortcut.
- Avoid making kiosk mode the default. Kiosk is powerful, but it is easier to trap users if something goes wrong.

Electron supports the needed controls directly through `BrowserWindow` and related APIs, including fullscreen, kiosk, always-on-top, focusable control, and taskbar visibility.

## Rendering Approach

Use a single HTML canvas and `requestAnimationFrame`.

Why this is the right approach:

- One canvas is simpler and faster than many DOM nodes or per-character elements.
- Canvas makes it easy to create the trail effect with a fading black overlay.
- The effect can be tuned with a small set of parameters: column count, speed, alpha fade, glyph set, and glow intensity.

Implementation guidance:

- Render on a single fullscreen canvas scaled for `devicePixelRatio`.
- Use a monospace font and a glyph set that feels like code, not generic random text. A mix of digits, letters, brackets, and symbols works well.
- Use bright red as the default palette.
- For rainbow mode, cycle hue over time rather than swapping hardcoded colors every frame.
- Keep the number of active columns tied to the viewport width so the effect scales naturally.
- Pause or reduce animation work when the window is hidden or minimized.

Avoid a DOM-heavy implementation. A canvas-based loop will be more stable and easier to keep visually consistent.

## Settings and Persistence

Keep settings simple and durable:

- Store user settings in Electron's `userData` directory using `app.getPath('userData')`.
- Persist only a few values: hotkey, color mode, default color, rainbow cycle speed, startup preference if added later, and maybe intensity/trail settings.
- Load defaults if the settings file is missing or corrupted.
- Save changes with a small, atomic write pattern if possible so a crash does not corrupt the config.

Good UX for the hotkey picker:

- Click a "Record hotkey" button.
- Capture the next valid accelerator chord.
- Show the live recorded string immediately.
- Reject unsupported or conflicting bindings before saving.

Electron's docs explicitly recommend `userData` for configuration files, which keeps user settings out of the install directory and avoids permission issues.

## Packaging To `.exe`

Use `electron-builder` with the Windows `NSIS` target for the first shipping build.

Why:

- It produces a normal Windows installer `.exe`.
- It is easy to configure from Node-based tooling.
- It supports optional portable builds later if needed.
- It has a clear code-signing story when the app is ready for wider distribution.

For local development and internal testing, unsigned builds are fine. For real distribution, code signing becomes important because Windows will otherwise warn users more aggressively. Electron and electron-builder both document Windows code signing support.

## Startup And Permission Considerations

This app should not need admin rights for the core experience.

- Global hotkeys do not require elevation, but they can fail silently if another app already owns the shortcut.
- Fullscreen and always-on-top are normal user-level window operations.
- Settings should live in the user profile, not under Program Files.
- Auto-start at login should be opt-in only if we add it later.

If a future version adds startup behavior, keep it separate from the core visualizer so the app still feels safe and predictable.

## Likely Pitfalls

- `Fn` cannot be relied on as a software hotkey on standard Windows keyboards.
- `globalShortcut` registration can fail due to conflicts, so the UI must surface that clearly.
- A kiosk-style window can be hard to escape if the exit path is weak.
- A per-glyph DOM implementation will probably stutter on lower-end machines.
- Unsigned installers may trigger SmartScreen warnings.
- A bad settings write can break startup unless defaults are recovered cleanly.

## Suggested Phase Split For Planning

1. Build the app shell, settings storage, tray/exit path, and hotkey registration.
2. Build the fullscreen canvas visualizer with the red default and rainbow mode.
3. Add the settings UI for remapping hotkeys and tuning colors/intensity.
4. Package the app into a Windows installer `.exe` and verify install/launch behavior.
5. Polish performance, edge cases, and sign the build if distribution requires it.

This split keeps each phase small enough to implement and review on its own.

## Primary Sources

- [Electron `globalShortcut`](https://www.electronjs.org/docs/latest/api/global-shortcut)
- [Electron `BrowserWindow`](https://www.electronjs.org/docs/latest/api/browser-window)
- [Electron `app.getPath('userData')`](https://www.electronjs.org/docs/latest/api/app)
- [Electron security recommendations](https://www.electronjs.org/docs/latest/tutorial/security)
- [Electron context isolation](https://www.electronjs.org/docs/latest/tutorial/context-isolation)
- [Windows virtual-key codes](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)
- [Win32 `RegisterHotKey`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey)
- [electron-builder NSIS](https://www.electron.build/nsis.html)
- [electron-builder Windows code signing](https://www.electron.build/code-signing-win.html)
- [Electron packaging overview](https://www.electronjs.org/docs/latest/tutorial/application-distribution)
- [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/)
