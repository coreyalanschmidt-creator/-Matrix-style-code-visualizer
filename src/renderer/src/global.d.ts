import type { AppState, SettingsUpdateInput, SettingsUpdateResult } from '../../shared/types'

declare global {
  interface Window {
    matrixShell: {
      getState: () => Promise<AppState>
      updateSettings: (settings: SettingsUpdateInput) => Promise<SettingsUpdateResult>
      showWindow: () => Promise<void>
      hideWindow: () => Promise<void>
      toggleWindow: () => Promise<void>
      quitApp: () => Promise<void>
      onStateChange: (listener: (state: AppState) => void) => () => void
    }
  }
}

export {}
