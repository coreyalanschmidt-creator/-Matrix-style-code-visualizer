@echo off
setlocal

set "installDir=%LOCALAPPDATA%\Raining Code"
set "legacyInstallDir=%LOCALAPPDATA%\Matrix Visualizer"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and ($_.CommandLine -match 'Raining Code Hotkeys\.ps1' -or $_.CommandLine -match 'Matrix Visualizer Hotkeys\.ps1') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

for /f "tokens=2 delims==;" %%P in ('wmic process where "name='mshta.exe' and commandline like '%%Matrix Visualizer.hta%%'" get processid /value 2^>nul ^| find "="') do (
  taskkill /PID %%P /F >nul 2>nul
)

del /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Raining Code.lnk" >nul 2>nul
del /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Matrix Visualizer.lnk" >nul 2>nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Raining Code' -ErrorAction SilentlyContinue; Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Matrix Visualizer' -ErrorAction SilentlyContinue"
for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath('Desktop')"`) do (
  del /Q "%%D\Raining Code.lnk" >nul 2>nul
  del /Q "%%D\Raining Code Settings.lnk" >nul 2>nul
  del /Q "%%D\Matrix Visualizer.lnk" >nul 2>nul
  del /Q "%%D\Matrix Settings.lnk" >nul 2>nul
  del /Q "%%D\Matrix Visualizer Settings.lnk" >nul 2>nul
  del /Q "%%D\Change Matrix Hotkeys.lnk" >nul 2>nul
)
rmdir /S /Q "%installDir%" >nul 2>nul
rmdir /S /Q "%legacyInstallDir%" >nul 2>nul
