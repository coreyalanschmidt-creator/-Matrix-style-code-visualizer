export type ColorMode = 'red' | 'rainbow'

export interface AppSettings {
  version: 1
  activationHotkey: string
  colorMode: ColorMode
}

export interface SettingsUpdateInput {
  activationHotkey: string
  colorMode: ColorMode
}

export interface SettingsUpdateResult {
  ok: boolean
  settings: AppSettings
  message: string | null
}

export interface HotkeyStatus {
  activationHotkey: string
  activationRegistered: boolean
  activationError: string | null
  quitHotkey: string
  quitRegistered: boolean
  quitError: string | null
}

export interface AppState {
  appReady: boolean
  windowVisible: boolean
  windowMinimized: boolean
  settings: AppSettings
  hotkeys: HotkeyStatus
  messages: string[]
}
