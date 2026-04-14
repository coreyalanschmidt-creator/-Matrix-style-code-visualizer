import './style.css'
import type { AppState, ColorMode, SettingsUpdateInput } from '../../shared/types'

const appRootElement = document.querySelector<HTMLDivElement>('#app')

if (!appRootElement) {
  throw new Error('Application root not found.')
}

const appRoot = appRootElement

appRoot.innerHTML = `
  <main class="visualizer-shell" data-mode="red">
    <canvas class="matrix-canvas" aria-hidden="true"></canvas>
    <div class="ambient-glow" aria-hidden="true"></div>

    <section class="hud" aria-label="Matrix visualizer controls">
      <div class="hud__title">
        <span class="eyebrow">Matrix Visualizer</span>
        <h1>Red rain</h1>
        <p class="lede">
          A fullscreen code storm with a simple escape hatch. Press <kbd>Esc</kbd> to hide
          it, or use the tray when you want it back.
        </p>
      </div>

      <div class="status-grid">
        <div class="stat">
          <span class="label">Activation hotkey</span>
          <strong data-field="activationHotkey">Loading...</strong>
        </div>
        <div class="stat">
          <span class="label">Rain mode</span>
          <strong data-field="colorMode">Loading...</strong>
        </div>
        <div class="stat">
          <span class="label">Quit fallback</span>
          <strong data-field="quitHotkey">Loading...</strong>
        </div>
        <div class="stat">
          <span class="label">Window state</span>
          <strong data-field="windowVisible">Loading...</strong>
        </div>
      </div>

      <div class="actions">
        <button data-action="toggle" type="button">Toggle visualizer</button>
        <button data-action="show" type="button">Show</button>
        <button data-action="hide" type="button">Hide</button>
        <button data-action="settings" type="button" class="secondary">Settings</button>
        <button data-action="quit" type="button" class="secondary">Quit app</button>
      </div>

      <div class="hint">
        Bright red is the default. Rainbow cycling is ready under the hood for later settings.
      </div>
    </section>

    <aside class="settings-panel" data-settings-panel hidden aria-label="Settings panel">
      <div class="settings-panel__header">
        <div>
          <span class="eyebrow">Settings</span>
          <h2>Quick controls</h2>
          <p>
            Keep the app simple: pick a supported shortcut, choose a color mode, and keep the
            visualizer easy to recover.
          </p>
        </div>
        <button data-action="close-settings" type="button" class="secondary">Close</button>
      </div>

      <div class="settings-stack">
        <section class="settings-block">
          <span class="label">Activation hotkey</span>
          <code class="hotkey-chip" data-field="hotkeyPreview">Ctrl+Alt+M</code>
          <div class="settings-actions">
            <button data-action="record-hotkey" type="button">Record hotkey</button>
            <button data-action="reset-hotkey" type="button" class="secondary">Reset default</button>
          </div>
          <p class="settings-copy">
            Press a supported OS-level chord such as Ctrl+Alt+M. Raw Fn is handled in firmware and
            cannot be recorded as a binding.
          </p>
          <p class="settings-copy" data-field="hotkeyStatus">Waiting for the current shortcut status.</p>
        </section>

        <section class="settings-block">
          <span class="label">Color mode</span>
          <div class="segmented" role="radiogroup" aria-label="Color mode">
            <button data-color-mode="red" type="button">Bright red</button>
            <button data-color-mode="rainbow" type="button">Rainbow</button>
          </div>
          <p class="settings-copy">
            Red stays on by default. Rainbow cycles smoothly if you want a more playful look.
          </p>
        </section>

        <section class="settings-block">
          <span class="label">Save status</span>
          <p class="settings-status" data-field="settingsStatus">Ready.</p>
        </section>
      </div>
    </aside>

    <section class="messages" data-messages hidden></section>
  </main>
`

const canvas = appRoot.querySelector<HTMLCanvasElement>('.matrix-canvas')

if (!canvas) {
  throw new Error('Matrix canvas not found.')
}

const fields = {
  activationHotkey: appRoot.querySelector<HTMLElement>('[data-field="activationHotkey"]'),
  quitHotkey: appRoot.querySelector<HTMLElement>('[data-field="quitHotkey"]'),
  colorMode: appRoot.querySelector<HTMLElement>('[data-field="colorMode"]'),
  windowVisible: appRoot.querySelector<HTMLElement>('[data-field="windowVisible"]'),
  hotkeyPreview: appRoot.querySelector<HTMLElement>('[data-field="hotkeyPreview"]'),
  hotkeyStatus: appRoot.querySelector<HTMLElement>('[data-field="hotkeyStatus"]'),
  settingsStatus: appRoot.querySelector<HTMLElement>('[data-field="settingsStatus"]'),
  messages: appRoot.querySelector<HTMLElement>('[data-messages]')
}

const actionButtons = {
  toggle: appRoot.querySelector<HTMLButtonElement>('[data-action="toggle"]'),
  show: appRoot.querySelector<HTMLButtonElement>('[data-action="show"]'),
  hide: appRoot.querySelector<HTMLButtonElement>('[data-action="hide"]'),
  settings: appRoot.querySelector<HTMLButtonElement>('[data-action="settings"]'),
  closeSettings: appRoot.querySelector<HTMLButtonElement>('[data-action="close-settings"]'),
  recordHotkey: appRoot.querySelector<HTMLButtonElement>('[data-action="record-hotkey"]'),
  resetHotkey: appRoot.querySelector<HTMLButtonElement>('[data-action="reset-hotkey"]'),
  quit: appRoot.querySelector<HTMLButtonElement>('[data-action="quit"]')
}

const colorModeButtons = Array.from(
  appRoot.querySelectorAll<HTMLButtonElement>('[data-color-mode]')
)
const settingsPanel = appRoot.querySelector<HTMLElement>('[data-settings-panel]')

const MATRIX_GLYPHS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$%&*+-=/\\<>[]{}'
const FONT_STACK = '"Cascadia Mono", "Segoe UI Mono", Consolas, "Courier New", monospace'
const CELL_WIDTH = 22
const CELL_HEIGHT = 28
const FONT_SIZE = 18
const MAX_DPR = 2.25
const FADE_ALPHA = 0.14
const DEFAULT_ACTIVATION_HOTKEY = 'Ctrl+Alt+M'
type ModePalette = {
  head: string
  glow: string
  trail: string
  wash: string
}

interface RainColumn {
  x: number
  y: number
  speed: number
  trailLength: number
  lastRow: number
  history: string[]
  hueSeed: number
}

function setText(element: HTMLElement | null, value: string): void {
  if (element) {
    element.textContent = value
  }
}

function randomFloat(min: number, max: number): number {
  return min + Math.random() * (max - min)
}

function randomInt(min: number, max: number): number {
  return Math.floor(randomFloat(min, max + 1))
}

function pickGlyph(): string {
  const index = Math.floor(Math.random() * MATRIX_GLYPHS.length)
  return MATRIX_GLYPHS[index] ?? '0'
}

type SettingsNoticeTone = 'neutral' | 'success' | 'error'

function isModifierKey(code: string): boolean {
  return code === 'ControlLeft' || code === 'ControlRight' || code === 'AltLeft' || code === 'AltRight' ||
    code === 'ShiftLeft' || code === 'ShiftRight' || code === 'MetaLeft' || code === 'MetaRight'
}

function normalizeCaptureKey(code: string): string | null {
  if (/^Key[A-Z]$/.test(code)) {
    return code.slice(3)
  }

  if (/^Digit[0-9]$/.test(code)) {
    return code.slice(5)
  }

  if (/^F([1-9]|1[0-9]|2[0-4])$/.test(code)) {
    return code
  }

  return null
}

function buildAcceleratorFromEvent(event: KeyboardEvent): { accelerator: string | null; message: string | null } {
  if (event.key === 'Fn' || event.code === 'Fn') {
    return {
      accelerator: null,
      message: 'Fn cannot be recorded because Windows does not expose it as a software key.'
    }
  }

  if (event.key === 'Escape') {
    return {
      accelerator: null,
      message: 'Press Esc again to cancel recording.'
    }
  }

  if (event.repeat) {
    return {
      accelerator: null,
      message: 'Hold the shortcut once, then release it.'
    }
  }

  if (isModifierKey(event.code)) {
    return {
      accelerator: null,
      message: 'Choose one non-modifier key as well.'
    }
  }

  const key = normalizeCaptureKey(event.code)

  if (!key) {
    return {
      accelerator: null,
      message: 'Choose a letter, number, or function key after the modifiers.'
    }
  }

  const modifiers: string[] = []

  if (event.ctrlKey) {
    modifiers.push('Ctrl')
  }

  if (event.altKey) {
    modifiers.push('Alt')
  }

  if (event.shiftKey) {
    modifiers.push('Shift')
  }

  if (event.metaKey) {
    modifiers.push('Super')
  }

  if (modifiers.length === 0) {
    return {
      accelerator: null,
      message: 'Hold Ctrl, Alt, Shift, or Windows together with one key.'
    }
  }

  return {
    accelerator: `${modifiers.join('+')}+${key}`,
    message: null
  }
}

function formatColorMode(mode: ColorMode): string {
  return mode === 'rainbow' ? 'Rainbow cycling' : 'Bright red'
}

function getPalette(mode: ColorMode, time: number, hueSeed: number, age: number): ModePalette {
  const elapsed = time / 1000

  if (mode === 'rainbow') {
    const hue = (hueSeed + elapsed * 24 + age * 12) % 360

    return {
      head: `hsla(${hue}, 96%, 78%, 0.98)`,
      glow: `hsla(${hue}, 98%, 66%, 0.95)`,
      trail: `hsla(${hue}, 90%, ${Math.max(42, 60 - age * 4)}%, 0.76)`,
      wash: `hsla(${hue}, 88%, 26%, 0.22)`
    }
  }

  return {
    head: 'rgba(255, 248, 248, 0.98)',
    glow: 'rgba(255, 108, 108, 0.96)',
    trail: age === 0 ? 'rgba(255, 96, 96, 0.92)' : 'rgba(199, 28, 28, 0.84)',
    wash: 'rgba(52, 0, 0, 0.24)'
  }
}

class MatrixRainScene {
  private readonly canvas: HTMLCanvasElement
  private readonly ctx: CanvasRenderingContext2D
  private readonly columns: RainColumn[] = []
  private readonly handleDprChange = (): void => {
    this.requestResize()
  }
  private animationFrame: number | null = null
  private width = 0
  private height = 0
  private dpr = 1
  private dprMediaQuery: MediaQueryList | null = null
  private lastFrame = 0
  private running = false
  private mode: ColorMode = 'red'
  private windowVisible = false
  private resizeQueued = false

  constructor(canvasElement: HTMLCanvasElement) {
    const context = canvasElement.getContext('2d')

    if (!context) {
      throw new Error('Canvas 2D context is not available.')
    }

    this.canvas = canvasElement
    this.ctx = context
    this.ctx.textAlign = 'center'
    this.ctx.textBaseline = 'middle'
    this.ctx.font = `${FONT_SIZE}px ${FONT_STACK}`

    this.bindDprWatcher()
    this.handleResize()
  }

  setMode(mode: ColorMode): void {
    this.mode = mode
  }

  setWindowVisible(visible: boolean): void {
    this.windowVisible = visible

    if (visible) {
      this.start()
    } else {
      this.stop()
    }
  }

  requestResize(): void {
    if (this.resizeQueued) {
      return
    }

    this.resizeQueued = true
    window.requestAnimationFrame(() => {
      this.resizeQueued = false
      this.handleResize()
    })
  }

  start(): void {
    if (this.running || !this.windowVisible || document.hidden) {
      return
    }

    this.running = true
    this.lastFrame = 0
    this.animationFrame = window.requestAnimationFrame(this.tick)
  }

  stop(): void {
    this.running = false

    if (this.animationFrame !== null) {
      window.cancelAnimationFrame(this.animationFrame)
      this.animationFrame = null
    }
  }

  private handleResize(): void {
    const rect = this.canvas.getBoundingClientRect()
    const nextWidth = Math.max(1, Math.round(rect.width || window.innerWidth))
    const nextHeight = Math.max(1, Math.round(rect.height || window.innerHeight))
    const nextDpr = Math.min(window.devicePixelRatio || 1, MAX_DPR)

    this.width = nextWidth
    this.height = nextHeight
    this.dpr = nextDpr

    this.canvas.width = Math.max(1, Math.floor(nextWidth * nextDpr))
    this.canvas.height = Math.max(1, Math.floor(nextHeight * nextDpr))
    this.canvas.style.width = `${nextWidth}px`
    this.canvas.style.height = `${nextHeight}px`
    this.ctx.setTransform(nextDpr, 0, 0, nextDpr, 0, 0)
    this.ctx.font = `${FONT_SIZE}px ${FONT_STACK}`
    this.bindDprWatcher()

    this.buildColumns()
    this.drawStaticFrame()
  }

  private bindDprWatcher(): void {
    if (this.dprMediaQuery) {
      this.dprMediaQuery.removeEventListener('change', this.handleDprChange)
    }

    const query = window.matchMedia(`(resolution: ${window.devicePixelRatio}dppx)`)
    query.addEventListener('change', this.handleDprChange)
    this.dprMediaQuery = query
  }

  private buildColumns(): void {
    const count = Math.max(18, Math.ceil(this.width / CELL_WIDTH))
    this.columns.length = 0

    for (let index = 0; index < count; index += 1) {
      const x = index * CELL_WIDTH + CELL_WIDTH * 0.5
      const y = randomFloat(-this.height, 0)
      const lastRow = Math.floor(y / CELL_HEIGHT)

      this.columns.push({
        x,
        y,
        speed: randomFloat(120, 320),
        trailLength: randomInt(8, 18),
        lastRow,
        history: [pickGlyph()],
        hueSeed: randomFloat(0, 360)
      })
    }
  }

  private drawStaticFrame(): void {
    const ctx = this.ctx
    ctx.save()
    ctx.globalCompositeOperation = 'source-over'
    ctx.fillStyle = '#020000'
    ctx.fillRect(0, 0, this.width, this.height)
    ctx.restore()
  }

  private resetColumn(column: RainColumn): void {
    column.y = randomFloat(-this.height * 0.75, 0)
    column.speed = randomFloat(120, 320)
    column.trailLength = randomInt(8, 18)
    column.lastRow = Math.floor(column.y / CELL_HEIGHT)
    column.history = [pickGlyph()]
    column.hueSeed = randomFloat(0, 360)
  }

  private drawBackdrop(time: number): void {
    const ctx = this.ctx
    const elapsed = time / 1000
    const wash = this.mode === 'rainbow'
      ? getPalette(this.mode, time, 0, 0).wash
      : 'rgba(12, 0, 0, 0.18)'
    const glowHue = this.mode === 'rainbow' ? (elapsed * 18) % 360 : 0
    const glow = ctx.createRadialGradient(
      this.width * 0.5,
      this.height * 0.22,
      0,
      this.width * 0.5,
      this.height * 0.22,
      Math.max(this.width, this.height) * 0.8
    )

    glow.addColorStop(0, this.mode === 'rainbow'
      ? `hsla(${glowHue}, 96%, 58%, 0.12)`
      : 'rgba(255, 70, 70, 0.12)')
    glow.addColorStop(1, 'rgba(0, 0, 0, 0)')

    ctx.save()
    ctx.globalCompositeOperation = 'source-over'
    ctx.fillStyle = `rgba(0, 0, 0, ${FADE_ALPHA})`
    ctx.fillRect(0, 0, this.width, this.height)
    ctx.fillStyle = wash
    ctx.fillRect(0, 0, this.width, this.height)
    ctx.fillStyle = glow
    ctx.fillRect(0, 0, this.width, this.height)
    ctx.restore()
  }

  private drawColumn(column: RainColumn, time: number): void {
    const ctx = this.ctx
    const rowTop = Math.floor(column.y / CELL_HEIGHT)
    const trailLimit = Math.max(column.trailLength, column.history.length)

    for (let age = 0; age < column.history.length; age += 1) {
      const row = rowTop - age

      if (row < -2) {
        continue
      }

      const glyph = column.history[age] ?? pickGlyph()
      const palette = getPalette(this.mode, time, column.hueSeed, age)
      const alpha = age === 0 ? 1 : Math.max(0.12, 1 - age / trailLimit)
      const y = row * CELL_HEIGHT + CELL_HEIGHT * 0.52

      ctx.save()
      ctx.globalAlpha = alpha
      ctx.shadowBlur = age === 0 ? 28 : 14
      ctx.shadowColor = age === 0 ? palette.glow : palette.trail
      ctx.fillStyle = age === 0 ? palette.head : palette.trail
      ctx.fillText(glyph, column.x, y)
      ctx.restore()
    }
  }

  private tick = (time: number): void => {
    if (!this.running) {
      return
    }

    if (document.hidden || !this.windowVisible) {
      this.stop()
      return
    }

    const dt = this.lastFrame === 0 ? 0 : Math.min((time - this.lastFrame) / 1000, 0.05)
    this.lastFrame = time

    this.drawBackdrop(time)

    for (const column of this.columns) {
      column.y += column.speed * dt

      const row = Math.floor(column.y / CELL_HEIGHT)
      if (row > column.lastRow) {
        for (let nextRow = column.lastRow + 1; nextRow <= row; nextRow += 1) {
          column.history.unshift(pickGlyph())

          if (column.history.length > column.trailLength) {
            column.history.length = column.trailLength
          }
        }

        column.lastRow = row
      }

      if (column.y - column.trailLength * CELL_HEIGHT > this.height + CELL_HEIGHT * 2) {
        this.resetColumn(column)
      }

      this.drawColumn(column, time)
    }

    this.animationFrame = window.requestAnimationFrame(this.tick)
  }
}

const scene = new MatrixRainScene(canvas)
let currentState: AppState | null = null
let settingsOpen = false
let hotkeyCaptureActive = false
let settingsNotice = 'Ready.'
let settingsNoticeTone: SettingsNoticeTone = 'neutral'
let settingsSaving = false

function setHudTheme(mode: ColorMode): void {
  const accent = mode === 'rainbow'
    ? 'hsl(330 96% 66%)'
    : 'hsl(0 100% 67%)'

  appRoot.dataset.mode = mode
  document.documentElement.style.setProperty('--accent', accent)
  document.documentElement.style.setProperty('--accent-soft',
    mode === 'rainbow' ? 'rgba(255, 110, 110, 0.22)' : 'rgba(255, 77, 77, 0.22)')
}

function renderMessages(messages: string[]): void {
  const container = fields.messages

  if (!container) {
    return
  }

  if (messages.length === 0) {
    container.hidden = true
    container.innerHTML = ''
    return
  }

  container.hidden = false
  container.replaceChildren()

  const heading = document.createElement('h2')
  heading.textContent = 'Recovery notes'

  const list = document.createElement('ul')
  for (const message of messages) {
    const item = document.createElement('li')
    item.textContent = message
    list.append(item)
  }

  container.append(heading, list)
}

function renderSettingsPanel(): void {
  if (settingsPanel) {
    settingsPanel.hidden = !settingsOpen
  }

  appRoot.dataset.settingsOpen = settingsOpen ? 'true' : 'false'
  appRoot.dataset.hotkeyCapture = hotkeyCaptureActive ? 'true' : 'false'
  appRoot.dataset.settingsTone = settingsNoticeTone

  if (actionButtons.settings) {
    actionButtons.settings.textContent = settingsOpen ? 'Hide settings' : 'Settings'
  }

  if (actionButtons.closeSettings) {
    actionButtons.closeSettings.disabled = settingsSaving
  }

  if (actionButtons.recordHotkey) {
    actionButtons.recordHotkey.disabled = settingsSaving || hotkeyCaptureActive
    actionButtons.recordHotkey.textContent = hotkeyCaptureActive ? 'Recording...' : 'Record hotkey'
  }

  if (actionButtons.resetHotkey) {
    actionButtons.resetHotkey.disabled = settingsSaving
  }

  for (const button of colorModeButtons) {
    const mode = button.dataset.colorMode as ColorMode | undefined
    const isActive = Boolean(currentState && mode === currentState.settings.colorMode)

    button.setAttribute('aria-pressed', String(isActive))
    button.disabled = settingsSaving
  }

  const hotkeyValue =
    hotkeyCaptureActive
      ? 'Recording...'
      : currentState?.settings.activationHotkey ?? DEFAULT_ACTIVATION_HOTKEY
  const hotkeyStatusValue = hotkeyCaptureActive
    ? 'Recording a new shortcut. Press Esc to cancel.'
    : currentState?.hotkeys.activationError ??
      (currentState?.hotkeys.activationRegistered
        ? `Active shortcut: ${currentState.settings.activationHotkey}`
        : 'The current shortcut could not be registered. Try another OS-level chord.')

  setText(fields.hotkeyPreview, hotkeyValue)
  setText(fields.hotkeyStatus, hotkeyStatusValue)
  setText(fields.settingsStatus, settingsNotice)

  if (fields.settingsStatus) {
    fields.settingsStatus.dataset.tone = settingsNoticeTone
  }
}

function setSettingsNotice(message: string, tone: SettingsNoticeTone = 'neutral'): void {
  settingsNotice = message
  settingsNoticeTone = tone
  renderSettingsPanel()
}

function setSettingsOpen(nextOpen: boolean): void {
  settingsOpen = nextOpen

  if (!nextOpen) {
    hotkeyCaptureActive = false
  }

  renderSettingsPanel()
}

function startHotkeyCapture(): void {
  settingsOpen = true
  hotkeyCaptureActive = true
  setSettingsNotice('Press a supported shortcut, or Esc to cancel.', 'neutral')
}

async function saveSettings(nextSettings: SettingsUpdateInput): Promise<void> {
  settingsSaving = true
  renderSettingsPanel()

  try {
    const result = await window.matrixShell.updateSettings(nextSettings)

    hotkeyCaptureActive = false
    await syncState()
    setSettingsNotice(
      result.message ?? (result.ok ? 'Settings saved.' : 'Could not save settings.'),
      result.ok ? 'success' : 'error'
    )
  } catch {
    hotkeyCaptureActive = false
    setSettingsNotice('Could not reach the settings service. The previous shortcut is still active.', 'error')
  } finally {
    settingsSaving = false
    renderSettingsPanel()
  }
}

async function applyColorMode(nextMode: ColorMode): Promise<void> {
  if (!currentState) {
    return
  }

  await saveSettings({
    activationHotkey: currentState.settings.activationHotkey,
    colorMode: nextMode
  })
}

async function applyHotkey(nextHotkey: string): Promise<void> {
  if (!currentState) {
    return
  }

  await saveSettings({
    activationHotkey: nextHotkey,
    colorMode: currentState.settings.colorMode
  })
}

function renderState(state: AppState): void {
  currentState = state
  setText(fields.activationHotkey, state.hotkeys.activationHotkey)
  setText(fields.quitHotkey, state.hotkeys.quitHotkey)
  setText(fields.colorMode, formatColorMode(state.settings.colorMode))
  setText(
    fields.windowVisible,
    state.windowMinimized ? 'Minimized' : state.windowVisible ? 'Fullscreen' : 'Hidden'
  )

  if (state.hotkeys.activationError) {
    setText(fields.activationHotkey, `${state.hotkeys.activationHotkey} (not registered)`)
  }

  scene.setMode(state.settings.colorMode)
  scene.setWindowVisible(state.windowVisible && !state.windowMinimized)
  setHudTheme(state.settings.colorMode)
  renderMessages(state.messages)
  renderSettingsPanel()
}

async function syncState(): Promise<void> {
  const state = await window.matrixShell.getState()
  renderState(state)
}

actionButtons.toggle?.addEventListener('click', () => {
  void window.matrixShell.toggleWindow()
})

actionButtons.show?.addEventListener('click', () => {
  void window.matrixShell.showWindow()
})

actionButtons.hide?.addEventListener('click', () => {
  void window.matrixShell.hideWindow()
})

actionButtons.settings?.addEventListener('click', () => {
  setSettingsOpen(!settingsOpen)
})

actionButtons.closeSettings?.addEventListener('click', () => {
  setSettingsOpen(false)
})

actionButtons.recordHotkey?.addEventListener('click', () => {
  startHotkeyCapture()
})

actionButtons.resetHotkey?.addEventListener('click', () => {
  void applyHotkey(DEFAULT_ACTIVATION_HOTKEY)
})

for (const button of colorModeButtons) {
  button.addEventListener('click', () => {
    const nextMode = button.dataset.colorMode as ColorMode | undefined

    if (!nextMode) {
      return
    }

    void applyColorMode(nextMode)
  })
}

actionButtons.quit?.addEventListener('click', () => {
  void window.matrixShell.quitApp()
})

document.addEventListener('keydown', event => {
  if (hotkeyCaptureActive) {
    event.preventDefault()
    event.stopPropagation()

    if (event.key === 'Escape') {
      hotkeyCaptureActive = false
      setSettingsNotice('Hotkey recording canceled.', 'neutral')
      return
    }

    const result = buildAcceleratorFromEvent(event)

    if (!result.accelerator) {
      setSettingsNotice(result.message ?? 'Choose a supported shortcut.', 'error')
      return
    }

    hotkeyCaptureActive = false
    setSettingsNotice(`Applying ${result.accelerator}...`, 'neutral')
    void applyHotkey(result.accelerator)
    return
  }

  if (event.key === 'Escape') {
    if (settingsOpen) {
      setSettingsOpen(false)
      return
    }

    void window.matrixShell.hideWindow()
  }
})

window.addEventListener('resize', () => {
  scene.requestResize()
})

document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    scene.setWindowVisible(false)
    return
  }

  void syncState()
})

window.matrixShell.onStateChange(renderState)

void syncState()
