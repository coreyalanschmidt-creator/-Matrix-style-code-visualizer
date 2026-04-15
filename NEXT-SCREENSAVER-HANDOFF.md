# Next Screensaver App Handoff

Use this handoff in a fresh context window to build a new Windows screensaver-style app that keeps the same install and usage model as `Raining Code`, but uses a different visual style and theme.

## Copy/Paste Starter

```md
We are creating a new Windows screensaver-style app based on the same setup and user experience model as the current `Raining Code` app, but this is a separate project with a new visual identity.

Before implementation, decide the new theme and style in this fresh context window. The new app should be more intricate, more graphically impressive, and more visually premium than `Raining Code`, while keeping the same core interaction model:

- easy to install
- easy to share
- hidden in the background when idle
- always ready for hotkey toggle
- fullscreen visual effect on demand
- separate settings window
- startup on login
- no visible idle window sitting on screen

Treat `Raining Code` as the reference implementation for app structure and install flow, not as the visual direction.

Do not overwrite the current app unless explicitly asked. Build this as a separate successor app with its own name, theme, assets, settings copy, and release files.
```

## What Must Stay The Same

- Windows-first desktop utility.
- Lightweight daily-use feel.
- Hidden background helper when idle.
- Fullscreen effect toggled by hotkey.
- Separate settings window instead of on-screen controls over the effect.
- Easy install and uninstall.
- Easy sharing path.
- Start on login support.
- Desktop shortcut for the main app and a separate settings shortcut.
- Default hotkey should remain a Windows-detectable fallback such as `Ctrl+Alt+M` unless the user changes it.

## What Should Change

- The visual theme.
- The artistic direction.
- The animation system and visual complexity.
- The brand name.
- The settings labels and look to match the new theme.
- The visual controls if the new effect benefits from different options.

## Theme Decision Rule

Do not assume the new theme is `Matrix`, code rain, cyberpunk red, or any variation of the current app.

In the fresh context window:

1. Propose 3 to 5 strong visual directions.
2. Make them distinct from one another.
3. Recommend one direction based on "intricate and graphically impressive" while still being practical to ship.
4. Wait for the user to choose or refine the theme.

## Required Product Behavior

The successor app should behave like this:

- Install once and stay ready in the background.
- No idle window should remain on screen.
- A hotkey should show the visualizer instantly.
- The same hotkey should hide it.
- A quit hotkey should fully close the helper.
- A settings shortcut should open a clean settings window.
- Startup should work after sign-in without depending on the user opening the app first.

## Important Lessons From `Raining Code`

- Raw `Fn` is not reliable on Windows. Do not depend on it.
- The startup setting should use the Windows `Run` registry path, not just a shortcut in the Startup folder.
- Keep the helper hidden by default.
- Keep settings wording in plain English.
- Make sure any settings options exactly match the live effect behavior.
  Example: if the effect cycles through 10 color modes, the settings UI must visibly expose the same 10 modes.
- Avoid extra controls that add clutter without helping the main experience.
- If unsigned `.exe` builds are blocked on the machine, keep a lightweight fallback install path available.

## Current App Reference Points

Use these files as reference for structure and install behavior:

- `release/Raining Code Hotkeys.ps1`
- `release/Raining Code Settings.ps1`
- `release/Install Raining Code.cmd`
- `release/Launch Raining Code.cmd`
- `release/Uninstall Raining Code.cmd`
- `README.md`
- `plan.md`
- `workflow/WORKFLOW.md`

Reference them for:

- hidden helper pattern
- fullscreen toggle flow
- settings window structure
- install/uninstall behavior
- startup wiring
- release file layout

Do not copy the current visual identity forward unless the user explicitly wants that.

## Suggested Workflow In The Fresh Context

1. Research agent:
   Research visual directions, rendering options, performance tradeoffs, and Windows delivery best practices for the new theme. Write `research.md`.
2. Planner agent:
   Turn that into a phased `plan.md` with realistic stages and status tracking.
3. Reviewer agent:
   Review the plan in fresh context and fix any gaps.
4. Coder agent:
   Implement one phase at a time and update `plan.md` with status and deviations.

## Strong Recommendation For The New App

Keep the same operational simplicity, but raise the visual ambition:

- more layered motion
- richer depth
- stronger lighting and atmosphere
- more intentional typography or shape language
- cleaner transitions
- more premium settings styling

The app should feel more like a polished interactive visual artwork than a simple novelty effect.

## Constraints

- The app must still feel simple to use.
- Do not turn it into a complex dashboard product.
- The settings UI should stay focused and understandable.
- The effect should remain performant enough for fullscreen use on a normal Windows desktop.
- The install/share experience matters as much as the visuals.

## Acceptance Criteria For The Successor

- New theme is clearly distinct from `Raining Code`.
- Visual result feels materially more impressive and intricate.
- App remains easy to install, share, and use.
- Hotkey toggle is reliable.
- Hidden helper behavior is preserved.
- Startup on login works reliably.
- Settings window matches the actual runtime behavior.
- The project has a complete `research.md` and `plan.md`.

## Final Rule

This is a successor blueprint, not a patch request for the current app.

Unless explicitly told otherwise, build the new app as a separate project or clearly separated successor within the workspace.
