import fs from 'node:fs/promises'
import path from 'node:path'
import type { AppSettings } from '../shared/types'

const SETTINGS_FILE = 'settings.json'
const SETTINGS_VERSION = 1

export const DEFAULT_SETTINGS: AppSettings = {
  version: SETTINGS_VERSION,
  activationHotkey: 'Ctrl+Alt+M',
  colorMode: 'red'
}

export interface LoadSettingsResult {
  settings: AppSettings
  message: string | null
}

function settingsFilePath(userDataPath: string): string {
  return path.join(userDataPath, SETTINGS_FILE)
}

function isColorMode(value: unknown): value is AppSettings['colorMode'] {
  return value === 'red' || value === 'rainbow'
}

function coerceSettings(value: unknown): AppSettings | null {
  if (!value || typeof value !== 'object') {
    return null
  }

  const record = value as Record<string, unknown>
  const activationHotkey =
    typeof record.activationHotkey === 'string' ? record.activationHotkey.trim() : ''
  const colorMode = record.colorMode
  const version = record.version

  if (version !== SETTINGS_VERSION || activationHotkey.length === 0 || !isColorMode(colorMode)) {
    return null
  }

  return {
    version: SETTINGS_VERSION,
    activationHotkey,
    colorMode
  }
}

function isMissingFileError(error: unknown): boolean {
  return Boolean(error && typeof error === 'object' && 'code' in error && (error as { code?: string }).code === 'ENOENT')
}

export async function loadSettings(userDataPath: string): Promise<LoadSettingsResult> {
  const filePath = settingsFilePath(userDataPath)

  try {
    const raw = await fs.readFile(filePath, 'utf8')
    const parsed = JSON.parse(raw) as unknown
    const settings = coerceSettings(parsed)

    if (settings) {
      return { settings, message: null }
    }

    return {
      settings: DEFAULT_SETTINGS,
      message: 'Recovered default settings because the saved configuration was invalid.'
    }
  } catch (error) {
    if (!isMissingFileError(error)) {
      return {
        settings: DEFAULT_SETTINGS,
        message: 'Recovered default settings because the saved configuration could not be read.'
      }
    }

    return {
      settings: DEFAULT_SETTINGS,
      message: 'Created default settings because no saved configuration was found.'
    }
  }
}

export async function saveSettings(userDataPath: string, settings: AppSettings): Promise<void> {
  await fs.mkdir(userDataPath, { recursive: true })

  const filePath = settingsFilePath(userDataPath)
  const tempPath = `${filePath}.tmp`
  const payload = `${JSON.stringify(settings, null, 2)}\n`

  try {
    await fs.writeFile(tempPath, payload, 'utf8')

    try {
      await fs.rename(tempPath, filePath)
    } catch {
      await fs.rm(filePath, { force: true })
      await fs.rename(tempPath, filePath)
    }
  } finally {
    await fs.rm(tempPath, { force: true }).catch(() => undefined)
  }
}
