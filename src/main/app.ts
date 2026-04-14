import { app, BrowserWindow, globalShortcut, ipcMain, Menu, nativeImage, Tray } from 'electron'
import { join } from 'node:path'
import { DEFAULT_SETTINGS, loadSettings, saveSettings } from './settings'
import type {
  AppSettings,
  AppState,
  HotkeyStatus,
  SettingsUpdateInput,
  SettingsUpdateResult
} from '../shared/types'

const DEFAULT_QUIT_HOTKEY = 'Ctrl+Alt+Q'
const APP_USER_MODEL_ID = 'com.codex.matrixvisualizer'

export class MatrixVisualizerApp {
  private mainWindow: BrowserWindow | null = null
  private tray: Tray | null = null
  private isQuitting = false
  private readonly messages: string[] = []
  private readonly toggleActivationHotkey = (): void => {
    this.toggleWindow()
  }
  private settings: AppSettings = DEFAULT_SETTINGS
  private hotkeys: HotkeyStatus = {
    activationHotkey: DEFAULT_SETTINGS.activationHotkey,
    activationRegistered: false,
    activationError: null,
    quitHotkey: DEFAULT_QUIT_HOTKEY,
    quitRegistered: false,
    quitError: null
  }

  async start(): Promise<void> {
    app.setAppUserModelId(APP_USER_MODEL_ID)
    this.registerIpc()

    await app.whenReady()

    const userDataPath = app.getPath('userData')
    const { settings, message } = await loadSettings(userDataPath)
    this.settings = settings

    if (message) {
      this.messages.push(message)
      try {
        await saveSettings(userDataPath, settings)
      } catch {
        this.messages.push('Could not persist the recovered settings, but the app stayed open.')
      }
    }

    this.createWindow()
    this.registerShortcuts()
    this.createTray()
    this.showWindow()
    this.publishState()

    app.on('second-instance', () => {
      this.showWindow()
    })

    app.on('activate', () => {
      this.showWindow()
    })

    app.on('window-all-closed', () => {
      if (!this.isQuitting) {
        return
      }
    })

    app.on('will-quit', () => {
      globalShortcut.unregisterAll()
    })
  }

  private registerIpc(): void {
    ipcMain.handle('matrix:get-state', async () => this.getState())
    ipcMain.handle('matrix:update-settings', async (_event, nextSettings: SettingsUpdateInput) => {
      return await this.updateSettings(nextSettings)
    })
    ipcMain.handle('matrix:show-window', async () => {
      this.showWindow()
    })
    ipcMain.handle('matrix:hide-window', async () => {
      this.hideWindow()
    })
    ipcMain.handle('matrix:toggle-window', async () => {
      this.toggleWindow()
    })
    ipcMain.handle('matrix:quit', async () => {
      this.quitApp()
    })
  }

  private createWindow(): void {
    if (this.mainWindow) {
      return
    }

    this.mainWindow = new BrowserWindow({
      width: 960,
      height: 640,
      minWidth: 720,
      minHeight: 480,
      show: false,
      autoHideMenuBar: true,
      fullscreenable: true,
      backgroundColor: '#020000',
      title: 'Matrix Visualizer',
      webPreferences: {
        preload: join(__dirname, '../preload/index.js'),
        contextIsolation: true,
        nodeIntegration: false
      }
    })

    this.mainWindow.on('close', event => {
      if (!this.isQuitting) {
        event.preventDefault()
        this.hideWindow()
      }
    })

    this.mainWindow.on('show', () => {
      this.publishState()
    })

    this.mainWindow.on('hide', () => {
      this.publishState()
    })

    this.mainWindow.on('minimize', () => {
      this.publishState()
    })

    this.mainWindow.on('restore', () => {
      this.publishState()
    })

    void this.loadWindowContent()
  }

  private async loadWindowContent(): Promise<void> {
    if (!this.mainWindow) {
      return
    }

    const devServerUrl = process.env['VITE_DEV_SERVER_URL']

    if (devServerUrl) {
      await this.mainWindow.loadURL(devServerUrl)
      return
    }

    await this.mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }

  private createTray(): void {
    if (this.tray) {
      return
    }

    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
        <rect width="64" height="64" rx="14" fill="#090909"/>
        <path d="M16 20h12l6 10 6-10h12L38 38l10 18H36l-6-10-6 10H12l10-18L16 20Z" fill="#ff3d3d"/>
      </svg>
    `.trim()

    const icon = nativeImage.createFromDataURL(
      `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`
    )

    this.tray = new Tray(icon)
    this.tray.setToolTip(this.getTrayTooltip())
    this.tray.setContextMenu(this.buildTrayMenu())
    this.tray.on('click', () => {
      this.toggleWindow()
    })
    this.tray.on('double-click', () => {
      this.showWindow()
    })
  }

  private buildTrayMenu(): Menu {
    return Menu.buildFromTemplate([
      {
        label: 'Show visualizer',
        click: () => {
          this.showWindow()
        }
      },
      {
        label: 'Hide visualizer',
        click: () => {
          this.hideWindow()
        }
      },
      { type: 'separator' },
      {
        label: `Toggle (${this.hotkeys.activationHotkey})`,
        click: () => {
          this.toggleWindow()
        }
      },
      {
        label: `Quit (${DEFAULT_QUIT_HOTKEY})`,
        click: () => {
          this.quitApp()
        }
      }
    ])
  }

  private getTrayTooltip(): string {
    const shortcutStatus = this.hotkeys.activationRegistered
      ? this.hotkeys.activationHotkey
      : `${this.hotkeys.activationHotkey} unavailable`

    return `Matrix Visualizer - ${shortcutStatus}`
  }

  private registerShortcuts(): void {
    globalShortcut.unregisterAll()

    this.hotkeys = {
      ...this.hotkeys,
      activationHotkey: this.settings.activationHotkey,
      activationRegistered: false,
      activationError: null,
      quitHotkey: DEFAULT_QUIT_HOTKEY,
      quitRegistered: false,
      quitError: null
    }

    const activationRegistered = globalShortcut.register(this.settings.activationHotkey, () => {
      this.toggleActivationHotkey()
    })

    if (!activationRegistered) {
      this.hotkeys.activationError = `Could not register ${this.settings.activationHotkey}. Use the tray menu or Escape to recover.`
      this.messages.push(this.hotkeys.activationError)
    } else {
      this.hotkeys.activationRegistered = true
    }

    const quitRegistered = globalShortcut.register(DEFAULT_QUIT_HOTKEY, () => {
      this.quitApp()
    })

    if (!quitRegistered) {
      this.hotkeys.quitError = `Could not register ${DEFAULT_QUIT_HOTKEY}. Use the tray menu to quit.`
      this.messages.push(this.hotkeys.quitError)
    } else {
      this.hotkeys.quitRegistered = true
    }
  }

  private getState(): AppState {
    return {
      appReady: app.isReady(),
      windowVisible: this.mainWindow?.isVisible() ?? false,
      windowMinimized: this.mainWindow?.isMinimized() ?? false,
      settings: this.settings,
      hotkeys: this.hotkeys,
      messages: [...this.messages]
    }
  }

  private publishState(): void {
    const state = this.getState()

    this.mainWindow?.webContents.send('matrix:state-changed', state)
    if (this.tray) {
      this.tray.setToolTip(this.getTrayTooltip())
      this.tray.setContextMenu(this.buildTrayMenu())
    }
  }

  private showWindow(): void {
    if (!this.mainWindow) {
      this.createWindow()
    }

    if (!this.mainWindow) {
      return
    }

    if (this.mainWindow.isMinimized()) {
      this.mainWindow.restore()
    }

    this.mainWindow.setFullScreen(true)
    this.mainWindow.setMenuBarVisibility(false)
    this.mainWindow.setAlwaysOnTop(true, 'screen-saver')
    this.mainWindow.show()
    this.mainWindow.focus()
    this.publishState()
  }

  private hideWindow(): void {
    this.mainWindow?.hide()
    this.publishState()
  }

  private toggleWindow(): void {
    if (this.mainWindow?.isVisible()) {
      this.hideWindow()
      return
    }

    this.showWindow()
  }

  private quitApp(): void {
    this.isQuitting = true
    globalShortcut.unregisterAll()
    app.quit()
  }

  async updateSettings(nextSettings: SettingsUpdateInput): Promise<SettingsUpdateResult> {
    const nextActivationHotkey = nextSettings.activationHotkey.trim()

    if (nextActivationHotkey.length === 0) {
      return {
        ok: false,
        settings: this.settings,
        message: 'Choose a supported shortcut before saving.'
      }
    }

    const nextAppSettings: AppSettings = {
      version: DEFAULT_SETTINGS.version,
      activationHotkey: nextActivationHotkey,
      colorMode: nextSettings.colorMode
    }

    const currentSettings = this.settings
    const activationWasPreviouslyRegistered = this.hotkeys.activationRegistered
    const hotkeyChanged = nextAppSettings.activationHotkey !== currentSettings.activationHotkey
    const shouldRegisterActivation = hotkeyChanged || !activationWasPreviouslyRegistered
    let activationRegisteredByUpdate = false

    if (shouldRegisterActivation) {
      const registered = globalShortcut.register(nextAppSettings.activationHotkey, () => {
        this.toggleActivationHotkey()
      })

      if (!registered) {
        const message = `Could not register ${nextAppSettings.activationHotkey}. Try another supported chord.`
        this.messages.push(message)
        this.publishState()
        return {
          ok: false,
          settings: currentSettings,
          message
        }
      }

      activationRegisteredByUpdate = true
    }

    try {
      await saveSettings(app.getPath('userData'), nextAppSettings)
    } catch {
      if (activationRegisteredByUpdate) {
        globalShortcut.unregister(nextAppSettings.activationHotkey)
      }

      const message = 'Could not save the new settings. The previous shortcut is still active.'
      this.messages.push(message)
      this.publishState()
      return {
        ok: false,
        settings: currentSettings,
        message
      }
    }

    if (hotkeyChanged) {
      globalShortcut.unregister(currentSettings.activationHotkey)
    }

    this.settings = nextAppSettings
    const activationRegistered = shouldRegisterActivation ? true : this.hotkeys.activationRegistered
    this.hotkeys = {
      ...this.hotkeys,
      activationHotkey: nextAppSettings.activationHotkey,
      activationRegistered,
      activationError: activationRegistered ? null : this.hotkeys.activationError
    }
    this.publishState()

    return {
      ok: true,
      settings: this.settings,
      message: 'Settings saved.'
    }
  }
}
