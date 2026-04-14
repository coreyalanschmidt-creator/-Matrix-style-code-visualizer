# Raining Code Plan

This plan turns `research.md` into an execution-ready delivery path for a simple Windows desktop Matrix-style visualizer. The first release stays focused on four things: a clean installable `.exe`, a strong fullscreen red rain effect, a configurable activation hotkey, and a minimal settings screen with color controls.

Assumptions:
- The workspace is a greenfield Windows app project.
- The recommended stack from `research.md` is the implementation path unless a phase review proves otherwise: Electron + TypeScript + Vite + Canvas 2D + electron-builder (NSIS).
- Each phase must be understandable to a fresh coder agent using only `research.md`, `plan.md`, and the current phase artifacts.
- The shipped app must not depend on a raw hardware `Fn` hotkey, because Windows cannot reliably detect it.

## Plan Controls

- Status values: `Not started`, `In progress`, `Ready for review`, `Blocked`, `Done`.
- Every phase and subtask must have a current status.
- A phase can move to `Ready for review` only after implementation, self-verification, and deviation logging are complete.
- A phase can move to `Done` only after an independent review pass is complete and any blocking findings are resolved.
- `plan.md` is the living source of truth. After each phase, update:
  - the phase status
  - the subtask statuses
  - the deviations/notes section
  - the status overview table
- If a phase changes direction, record the deviation before closing the phase.
- If there are no deviations, write `None`.

## Hotkey Rule

The user asked for `Fn+M` as the default command. That is not a dependable Windows hotkey because `Fn` is usually handled in firmware or vendor software before Windows sees it.

Plan for the first release:
- Treat `Fn+M` as the user-facing intent, not a guaranteed OS-level binding.
- Ship a Windows-detectable default hotkey such as `Ctrl+Alt+M`.
- Surface this clearly in the settings UI as the default activation shortcut.
- Let users remap the shortcut to any supported OS-level chord.
- Do not allow raw `Fn` to be recorded as a binding.
- If later hardware or vendor support exposes a special Fn-layer action, treat that as an optional enhancement, not a dependency.

## Status Overview

| Phase | Status | Primary role | Depends on | Exit gate |
| --- | --- | --- | --- | --- |
| Phase 1 - App shell, storage, and hotkey contract | Done | Coder + Reviewer | `research.md` | App boots in a safe idle state, persists and recovers settings, registers a safe default hotkey, and exposes a reliable show/hide and exit path |
| Phase 2 - Fullscreen Matrix rain engine | Done | Coder + Reviewer | Phase 1 | The app renders a polished red Matrix effect in fullscreen and handles resize/perf basics |
| Phase 3 - Settings UI and hotkey remapping | Done | Coder + Reviewer | Phases 1-2 | Users can change color mode and remap the activation hotkey through a simple settings screen |
| Phase 4 - Windows packaging and installer | Done | Coder + Reviewer | Phases 1-3 | The project builds into a usable NSIS installer `.exe` and launches correctly after install |
| Phase 5 - Hardening, polish, and release review | Done | Coder + Reviewer | Phases 1-4 | Edge cases, defaults, and release readiness are verified and documented |

## Phase 1 - App Shell, Storage, and Hotkey Contract

Status: Done

Objective:
Create the smallest working Electron shell that can launch in a safe idle state, persist and recover settings, register a safe default activation hotkey, and show or hide the primary window reliably.

Inputs:
- `research.md`
- Current workspace files

Scope:
- Scaffold the Electron + TypeScript + Vite app structure.
- Implement the main process, preload bridge, and renderer boundaries.
- Add a simple settings store in Electron `userData` with default recovery for missing or corrupted config.
- Register the default activation hotkey using a Windows-detectable fallback.
- Add a reliable escape route, tray-based recovery path, and a global quit fallback.
- Define the app state needed for later visualizer and settings phases.

Out of scope:
- The actual Matrix rain rendering.
- The full settings UI.
- Installer packaging.
- Any advanced theme or animation polish.

Dependencies:
- Research recommendation from `research.md`.
- Windows-compatible Electron APIs.

Deliverables:
- Running app shell with main, preload, and renderer entry points.
- Settings load/save implementation with safe defaults and recovery from missing or corrupted config.
- Hotkey registration and unregistration flow.
- Tray menu or equivalent recovery controls.
- A safe idle startup path that does not depend on the activation hotkey.
- A documented hotkey policy that explains the `Fn` limitation and the fallback choice.

Acceptance criteria:
- The app starts cleanly on Windows.
- The app starts in a safe idle state and can show and hide its primary window through the registered default shortcut.
- Settings are loaded from and saved to a durable user location.
- If the settings file is missing or corrupted, the app loads defaults and still starts cleanly.
- If hotkey registration fails, the app reports the failure clearly and remains usable.
- The plan records the `Fn` constraint and the fallback policy as an explicit product decision.
- The app can be exited or recovered without depending on the activation hotkey.

Verification:
- Start the app in dev mode and confirm it opens without errors.
- Confirm settings persist across a restart.
- Delete or corrupt the settings file and confirm the app recovers with defaults.
- Confirm the default hotkey registers and toggles the app surface.
- Confirm the tray, escape key, or global quit path can recover the app if the shortcut conflicts.

Subtasks:
| Subtask | Status | Notes |
| --- | --- | --- |
| Scaffold Electron + TypeScript + Vite | Done | Keep the structure minimal and readable |
| Add settings persistence | Done | Store only the values needed for later phases and recover missing or corrupted config |
| Implement safe default hotkey | Done | Use a Windows-detectable shortcut, not raw `Fn` |
| Add show/hide and escape path | Done | Ensure the app is never trapped open and can quit safely |
| Document hotkey policy | Done | Explain the `Fn` limitation in product terms |

Deviations / notes:
- What changed: Added shareability-friendly app metadata and naming in `package.json` (`name`, `productName`, `appId`, and `artifactName`), and aligned the scaffold build output with Electron-Vite's `out/` directory.
  Why: The app should be easy to share, so the product identity and future distributable names needed to be stable from Phase 1.
  Impact: No runtime behavior change. The scaffold is now easier to package and share later without renaming the app.
  Follow-up: Phase 4 can reuse the same product identity when installer work starts.
  Decision: Accepted.

## Phase 2 - Fullscreen Matrix Rain Engine

Status: Done

Objective:
Build the actual fullscreen visual effect with a red Matrix-style rain animation that looks strong, simple, and stable.

Inputs:
- Phase 1 shell and state contract
- Visual direction from `research.md`

Scope:
- Build the canvas-based visualizer renderer.
- Create the falling-code animation and trail effect.
- Set bright red as the default palette.
- Support a rainbow or cycling color mode at the renderer level.
- Handle fullscreen sizing, `devicePixelRatio`, and monitor resize changes.
- Pause or reduce animation work when hidden or minimized.

Out of scope:
- Settings UI for choosing colors.
- Hotkey remapping logic.
- Packaging and installer work.
- Non-essential effects that add complexity without improving the first release.

Dependencies:
- Phase 1 app shell, windowing, and shared settings model.

Deliverables:
- Fullscreen canvas visualizer.
- Red default visual style with Matrix-like glyph rain.
- Basic rainbow mode plumbing ready for settings control later.
- Performance-safe animation loop.

Acceptance criteria:
- The app fills the screen with a visually convincing Matrix-style code rain effect.
- The default look is bright red, not green.
- The animation remains smooth during common resize and focus changes.
- The visualizer can be shown and hidden through the shell controls from Phase 1.

Verification:
- Manually inspect the fullscreen effect on Windows.
- Confirm the red default looks intentional and readable.
- Confirm rainbow mode changes color over time rather than flashing randomly.
- Confirm resizing and hide/show do not break the animation.

Subtasks:
| Subtask | Status | Notes |
| --- | --- | --- |
| Build canvas renderer | Done | Single-canvas implementation only |
| Add rain columns and trail effect | Done | Keep the effect simple and legible |
| Add red default palette | Done | Bright and high contrast |
| Add rainbow cycling mode | Done | Renderer-level support only |
| Add resize and pause handling | Done | Protect performance and state |

Deviations / notes:
- Rainbow mode now uses second-based hue progression so it cycles smoothly instead of flashing.
- The canvas backing store now refreshes on devicePixelRatio changes as well as resize, so monitor moves keep the effect crisp.

## Phase 3 - Settings UI and Hotkey Remapping

Status: Done

Objective:
Add a minimal settings experience that lets the user remap the activation hotkey and switch color behavior without turning the app into a heavy preferences project.

Inputs:
- Phases 1-2
- Settings model from Phase 1

Scope:
- Build a simple settings screen or panel.
- Add a hotkey capture flow with validation.
- Add controls for color mode selection, including red default and rainbow mode.
- Persist settings changes immediately and safely.
- Show the user when a shortcut cannot be registered.

Out of scope:
- Deep customization menus.
- Advanced theme editors.
- Non-essential preferences unrelated to activation or color.

Dependencies:
- Stable settings persistence from Phase 1.
- Renderer state hooks from Phase 2.

Deliverables:
- Settings UI with a clear hotkey capture control.
- Color mode selector with at least red default and rainbow mode.
- Validation and feedback for invalid or conflicting shortcuts.
- Save/load behavior that survives app restarts.

Acceptance criteria:
- A user can change the activation hotkey without editing files manually.
- A user can switch color modes from the UI and see the change apply.
- The UI explains the default hotkey choice clearly, including why raw `Fn` is not guaranteed.
- Invalid or conflicting shortcuts are rejected with a clear message.
- Unsupported chords, including raw `Fn`, cannot be recorded as bindings.

Verification:
- Record a new shortcut and confirm it activates the visualizer.
- Change the color mode, restart the app, and confirm the setting persists.
- Attempt a conflicting or unsupported shortcut and verify the UI blocks it.

Subtasks:
| Subtask | Status | Notes |
| --- | --- | --- |
| Build settings screen | Done | Keep the layout minimal and polished |
| Add hotkey capture and validation | Done | Must surface conflicts immediately |
| Add color mode controls | Done | Red default and rainbow mode at minimum |
| Persist and reload settings | Done | No manual config editing required |
| Update user-facing hotkey copy | Done | Explain the `Fn` fallback clearly |

Deviations / notes:
- The settings experience is implemented as a compact in-app drawer over the existing visualizer instead of a separate route, which keeps the first release simple and easy to recover from.
- Hotkey capture is limited to supported OS-level chords and reports registration failures both inline in the drawer and in the existing recovery messages.
- The save path now re-registers the current activation hotkey when it has gone stale, so resetting to the default shortcut can recover the binding even if the stored value did not change.

## Phase 4 - Windows Packaging and Installer

Status: Done

Objective:
Package the app into a straightforward Windows installer `.exe` and confirm it installs and launches cleanly.

Inputs:
- Phases 1-3
- Electron builder configuration expectations from `research.md`

Scope:
- Add `electron-builder` configuration for NSIS.
- Produce an installable `.exe`.
- Confirm installed launch behavior matches the dev build.
- Add any required app metadata, icons, or shortcuts needed for a clean install experience.

Out of scope:
- Full release signing setup unless the project is ready for distribution.
- Major app feature work.
- Extra installer complexity that does not help the first release.

Dependencies:
- Stable app shell, visualizer, and settings behavior from Phases 1-3.

Deliverables:
- Working Windows installer build.
- Repeatable packaging command or script.
- Basic install/launch verification notes.

Acceptance criteria:
- The project can build a Windows NSIS installer `.exe`.
- A fresh install launches the app successfully.
- The installer does not break settings persistence or hotkey behavior.

Verification:
- Run the packaging command.
- Install the produced `.exe` on Windows.
- Launch the installed app and confirm the visualizer and settings still work.

Subtasks:
| Subtask | Status | Notes |
| --- | --- | --- |
| Add electron-builder config | Done | Includes NSIS plus a portable target for easier sharing |
| Produce NSIS installer | Done | `npm.cmd run dist` now produces both the setup and portable executables |
| Verify installed launch flow | Done | Portable launch and installed-app launch were both verified locally |
| Add packaging notes | Done | `npm.cmd run dist` produces the final release artifacts |

Deviations / notes:
- A custom NSIS script in `build/installer.nsi` was added so electron-builder skips the failing pre-sign/uninstaller pass on this machine and can complete the setup build.
- `npm.cmd run dist` now succeeds end to end and produces `release/Raining Code-Setup-0.1.0-x64.exe`, `release/Raining Code-Setup-0.1.0-x64.exe.blockmap`, `release/Raining Code-Portable-0.1.0-x64.exe`, and `release/win-unpacked/`.
- The portable executable launches successfully, and the installed app launched successfully from the path created by the setup installer.

## Phase 5 - Hardening, Polish, and Release Review

Status: Done

Objective:
Use a fresh coder agent to close the gaps that matter for a simple first release: reliability, escape routes, visual polish, and release readiness.

Inputs:
- Phases 1-4
- The packaged build and verification results

Scope:
- Fix usability issues found during packaging or manual testing.
- Tighten the escape path, tray behavior, and hotkey conflict handling.
- Improve the visual polish only where it materially helps the first release.
- Confirm the app still behaves well after settings reset or corrupted config recovery.
- Prepare the final `plan.md` state for handoff or release.

Out of scope:
- Large feature expansion.
- Secondary modes that do not ship in the first release.
- Re-architecting the app shell unless a blocking defect requires it.

Dependencies:
- A working packaged build from Phase 4.
- Any review findings from earlier phases.

Deliverables:
- Final bug fixes and polish changes.
- Confirmed recovery behavior for settings or hotkey issues.
- Release notes in `plan.md` summarizing any deviations from the original plan.

Acceptance criteria:
- No blocking issues remain in the user flow from launch to visualizer to exit.
- The app still feels simple and focused after polish work.
- Any deviations from the plan are documented clearly in `plan.md`.

Verification:
- Run a final manual pass through launch, hotkey activation, settings changes, and exit.
- Confirm the packaged build still works after the final fixes.
- Re-check that the default hotkey policy is still clear and accurate.

Subtasks:
| Subtask | Status | Notes |
| --- | --- | --- |
| Fix review findings | Done | Closed the stale-hotkey recovery gap before final packaging |
| Polish edge cases | Done | Added release-facing README and cleaned package metadata for sharing |
| Final manual smoke test | Done | Verified `typecheck`, `build`, `dist`, portable launch, setup launch, and installed-app launch |
| Update release notes in `plan.md` | Done | Recorded packaging workaround, shareability outcome, and final smoke coverage |

Deviations / notes:
- The packaged app still uses the default Electron icon because a custom Windows `.ico` asset was not added in this pass.
- A custom NSIS script in `build/installer.nsi` is part of the release process on this machine because it avoids the failing uninstaller pre-sign path in electron-builder.
- Startup now shows the visualizer window immediately on launch so the packaged app does not appear inert when a user double-clicks the `.exe`; tray and hotkey controls remain available for later hide/show behavior.
- A lightweight fallback release was added in `release/` using a PowerShell fullscreen visualizer, hotkey helper, install scripts, and a separate hotkey editor script so the app can still be installed, toggled with `Ctrl+Alt+M`, kept always ready, and configured without showing controls on top of the visualizer on Windows systems that block unsigned custom executables.
- The lightweight settings flow was later upgraded from a plain command/notepad path into a tabbed PowerShell settings panel for startup behavior, colors, tray visibility, and hotkeys while keeping the background helper itself invisible.
- Separate shortcut icons were added for the main visualizer and the settings shortcut, and the user-facing settings shortcut label was shortened to `Raining Code Settings`.
- A lean `Raining Code Lightweight.zip` share bundle was added so the lightweight install path can be handed off without the larger Electron artifacts.
- Final smoke coverage included `npm.cmd run typecheck`, `npm.cmd run build`, `npm.cmd run dist`, a successful launch of `release/Raining Code-Portable-0.1.0-x64.exe`, a successful launch of `release/Raining Code-Setup-0.1.0-x64.exe`, and a successful launch of the installed app executable created by the setup installer.
- Sharing is now straightforward through either the portable executable or the guided setup executable in `release/`.

## Review Gates

- Each phase ends with a self-check, then a review pass by a fresh coder or reviewer context.
- The reviewer should use `research.md`, `plan.md`, and the changed files for that phase only.
- A phase is not `Done` until the reviewer confirms the phase met its acceptance criteria or any findings are resolved.
- If a review finds a gap, update the active phase section in `plan.md` with the issue, the fix, and the resulting status before starting the next phase.
- If a phase discovers a better implementation detail, record it in `Deviations / notes:` instead of letting the knowledge live only in chat.

## Handoff Rules

- The next coder agent should read `research.md` first, then the current phase block in `plan.md`, then the relevant code.
- Each phase should be small enough that a fresh agent can finish it without inheriting unbounded context from previous phases.
- If a phase cannot be completed cleanly, stop at the nearest safe boundary and mark the phase `Blocked` with a short note in `Deviations / notes:`.
