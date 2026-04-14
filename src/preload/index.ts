import { contextBridge, ipcRenderer } from 'electron'
import type { AppState, SettingsUpdateInput, SettingsUpdateResult } from '../shared/types'

const api = {
  getState: async (): Promise<AppState> => {
    return await ipcRenderer.invoke('matrix:get-state')
  },
  updateSettings: async (settings: SettingsUpdateInput): Promise<SettingsUpdateResult> => {
    return await ipcRenderer.invoke('matrix:update-settings', settings)
  },
  showWindow: async (): Promise<void> => {
    await ipcRenderer.invoke('matrix:show-window')
  },
  hideWindow: async (): Promise<void> => {
    await ipcRenderer.invoke('matrix:hide-window')
  },
  toggleWindow: async (): Promise<void> => {
    await ipcRenderer.invoke('matrix:toggle-window')
  },
  quitApp: async (): Promise<void> => {
    await ipcRenderer.invoke('matrix:quit')
  },
  onStateChange: (listener: (state: AppState) => void): (() => void) => {
    const channel = (_event: Electron.IpcRendererEvent, state: AppState) => {
      listener(state)
    }

    ipcRenderer.on('matrix:state-changed', channel)

    return () => {
      ipcRenderer.removeListener('matrix:state-changed', channel)
    }
  }
}

contextBridge.exposeInMainWorld('matrixShell', api)
