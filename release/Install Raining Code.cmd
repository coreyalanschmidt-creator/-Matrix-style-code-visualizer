@echo off
setlocal

set "sourceDir=%~dp0"
set "installDir=%LOCALAPPDATA%\Raining Code"
set "legacyInstallDir=%LOCALAPPDATA%\Matrix Visualizer"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and ($_.CommandLine -match 'Raining Code Hotkeys\.ps1' -or $_.CommandLine -match 'Matrix Visualizer Hotkeys\.ps1') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

if not exist "%installDir%" mkdir "%installDir%"

copy /Y "%sourceDir%Raining Code Hotkeys.ps1" "%installDir%\Raining Code Hotkeys.ps1" >nul
copy /Y "%sourceDir%Raining Code Settings.ps1" "%installDir%\Raining Code Settings.ps1" >nul
copy /Y "%sourceDir%Raining Code Settings.cmd" "%installDir%\Raining Code Settings.cmd" >nul
copy /Y "%sourceDir%Raining Code Icon.ico" "%installDir%\Raining Code Icon.ico" >nul
copy /Y "%sourceDir%Raining Code Settings Icon.ico" "%installDir%\Raining Code Settings Icon.ico" >nul
copy /Y "%sourceDir%Launch Raining Code.cmd" "%installDir%\Launch Raining Code.cmd" >nul

if exist "%installDir%\hotkey-settings.json" (
  rem keep the current installed settings
) else if exist "%legacyInstallDir%\hotkey-settings.json" (
  copy /Y "%legacyInstallDir%\hotkey-settings.json" "%installDir%\hotkey-settings.json" >nul
) else (
  copy /Y "%sourceDir%hotkey-settings.json" "%installDir%\hotkey-settings.json" >nul
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$shell = New-Object -ComObject WScript.Shell; " ^
  "$desktop = [Environment]::GetFolderPath('Desktop'); " ^
  "$startup = [Environment]::GetFolderPath('Startup'); " ^
  "$target = Join-Path $env:LOCALAPPDATA 'Raining Code\Launch Raining Code.cmd'; " ^
  "$workdir = Join-Path $env:LOCALAPPDATA 'Raining Code'; " ^
  "$desktopShortcut = $shell.CreateShortcut((Join-Path $desktop 'Raining Code.lnk')); " ^
  "$desktopShortcut.TargetPath = $target; " ^
  "$desktopShortcut.WorkingDirectory = $workdir; " ^
  "$desktopShortcut.IconLocation = (Join-Path $env:LOCALAPPDATA 'Raining Code\Raining Code Icon.ico'); " ^
  "$desktopShortcut.Save(); " ^
  "$settingsShortcut = $shell.CreateShortcut((Join-Path $desktop 'Raining Code Settings.lnk')); " ^
  "$settingsShortcut.TargetPath = (Join-Path $env:LOCALAPPDATA 'Raining Code\Raining Code Settings.cmd'); " ^
  "$settingsShortcut.WorkingDirectory = $workdir; " ^
  "$settingsShortcut.IconLocation = (Join-Path $env:LOCALAPPDATA 'Raining Code\Raining Code Settings Icon.ico'); " ^
  "$settingsShortcut.Save(); " ^
  "$legacyNames = @('Matrix Visualizer.lnk', 'Matrix Settings.lnk', 'Matrix Visualizer Settings.lnk', 'Change Matrix Hotkeys.lnk'); " ^
  "foreach ($legacyName in $legacyNames) { $legacyPath = Join-Path $desktop $legacyName; if (Test-Path $legacyPath) { Remove-Item $legacyPath -Force } }; " ^
  "$legacyStartupPath = Join-Path $startup 'Matrix Visualizer.lnk'; if (Test-Path $legacyStartupPath) { Remove-Item $legacyStartupPath -Force }; " ^
  "$startupShortcut = $shell.CreateShortcut((Join-Path $startup 'Raining Code.lnk')); " ^
  "$startupShortcut.TargetPath = $target; " ^
  "$startupShortcut.WorkingDirectory = $workdir; " ^
  "$startupShortcut.IconLocation = (Join-Path $env:LOCALAPPDATA 'Raining Code\Raining Code Icon.ico'); " ^
  "$startupShortcut.Save()"

start "" "%installDir%\Launch Raining Code.cmd"
