Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsPath = Join-Path $scriptDir 'hotkey-settings.json'
$helperScriptPath = Join-Path $scriptDir 'Raining Code Hotkeys.ps1'
$startupShortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'Raining Code.lnk'
$settingsIconPath = Join-Path $scriptDir 'Raining Code Settings Icon.ico'
$settingsMutexName = 'Local\RainingCodeSettingsWindow'

function Get-DefaultSettings {
  return [ordered]@{
    toggleHotkey = 'Ctrl+Alt+M'
    quitHotkey = 'Ctrl+Alt+Q'
    startupEnabled = $true
    defaultColorMode = 'Red'
    defaultSizeMode = 'Small'
    showTrayIcon = $false
  }
}

function Normalize-ColorModeName {
  param(
    [string]$Value,
    [string]$Fallback = 'Red'
  )

  switch ($Value) {
    'Orange' { return 'Orange' }
    'Gold' { return 'Gold' }
    'Green' { return 'Green' }
    'Cyan' { return 'Cyan' }
    'Blue' { return 'Blue' }
    'Violet' { return 'Violet' }
    'Pink' { return 'Pink' }
    'White' { return 'White' }
    'Rainbow' { return 'Rainbow' }
    'Amber' { return 'Gold' }
    'Ice' { return 'Cyan' }
    default { return $Fallback }
  }
}

function Normalize-SizeModeName {
  param(
    [string]$Value,
    [string]$Fallback = 'Small'
  )

  switch ($Value) {
    'Small' { return 'Small' }
    'Medium' { return 'Medium' }
    'Large' { return 'Large' }
    'Jumbo' { return 'Jumbo' }
    'Extra Large' { return 'Jumbo' }
    default { return $Fallback }
  }
}

function Get-SavedSettings {
  $defaults = Get-DefaultSettings

  if (-not (Test-Path -LiteralPath $settingsPath)) {
    return [pscustomobject]$defaults
  }

  try {
    $raw = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return [pscustomobject]$defaults
  }

  $toggleHotkey = [string]$parsed.toggleHotkey
  if ([string]::IsNullOrWhiteSpace($toggleHotkey)) {
    $toggleHotkey = [string]$defaults.toggleHotkey
  }

  $quitHotkey = [string]$parsed.quitHotkey
  if ([string]::IsNullOrWhiteSpace($quitHotkey)) {
    $quitHotkey = [string]$defaults.quitHotkey
  }

  $defaultColorMode = Normalize-ColorModeName -Value ([string]$parsed.defaultColorMode) -Fallback ([string]$defaults.defaultColorMode)
  $defaultSizeMode = Normalize-SizeModeName -Value ([string]$parsed.defaultSizeMode) -Fallback ([string]$defaults.defaultSizeMode)

  $startupEnabled = $defaults.startupEnabled
  if ($null -ne $parsed.startupEnabled) {
    $startupEnabled = [bool]$parsed.startupEnabled
  }

  $showTrayIcon = $defaults.showTrayIcon
  if ($null -ne $parsed.showTrayIcon) {
    $showTrayIcon = [bool]$parsed.showTrayIcon
  }

  return [pscustomobject]@{
    toggleHotkey = $toggleHotkey
    quitHotkey = $quitHotkey
    startupEnabled = $startupEnabled
    defaultColorMode = $defaultColorMode
    defaultSizeMode = $defaultSizeMode
    showTrayIcon = $showTrayIcon
  }
}

function Save-Settings {
  param([hashtable]$Settings)

  $Settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

function Test-StartupEnabled {
  return Test-Path -LiteralPath $startupShortcutPath
}

function Set-StartupEnabled {
  param([bool]$Enabled)

  if ($Enabled) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupShortcutPath)
    $shortcut.TargetPath = Join-Path $scriptDir 'Launch Raining Code.cmd'
    $shortcut.WorkingDirectory = $scriptDir
    $shortcut.Save()
    return
  }

  if (Test-Path -LiteralPath $startupShortcutPath) {
    Remove-Item -LiteralPath $startupShortcutPath -Force
  }
}

function Restart-HotkeyHelper {
  Get-CimInstance Win32_Process |
    Where-Object { $_.Name -eq 'powershell.exe' -and ($_.CommandLine -match 'Raining Code Hotkeys\.ps1' -or $_.CommandLine -match 'Matrix Visualizer Hotkeys\.ps1') } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

  Start-Sleep -Milliseconds 400

  Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $helperScriptPath `
    -WindowStyle Hidden
}

function Convert-HotkeyToParts {
  param([string]$Value)

  $state = [ordered]@{
    Ctrl = $false
    Alt = $false
    Shift = $false
    Win = $false
    Key = ''
  }

  foreach ($part in ($Value -split '\+')) {
    $token = $part.Trim()
    switch ($token.ToUpperInvariant()) {
      'CTRL' { $state.Ctrl = $true; continue }
      'CONTROL' { $state.Ctrl = $true; continue }
      'ALT' { $state.Alt = $true; continue }
      'SHIFT' { $state.Shift = $true; continue }
      'WIN' { $state.Win = $true; continue }
      'WINDOWS' { $state.Win = $true; continue }
      'SUPER' { $state.Win = $true; continue }
      'ESC' { $state.Key = 'Esc'; continue }
      'SPACE' { $state.Key = 'Space'; continue }
      default { $state.Key = $token.ToUpperInvariant() }
    }
  }

  return [pscustomobject]$state
}

function Get-HotkeyDisplayText {
  param([hashtable]$Editor)

  $parts = @()
  if ($Editor.Ctrl.Checked) { $parts += 'Ctrl' }
  if ($Editor.Alt.Checked) { $parts += 'Alt' }
  if ($Editor.Shift.Checked) { $parts += 'Shift' }
  if ($Editor.Win.Checked) { $parts += 'Win' }

  $key = [string]$Editor.Key.SelectedItem
  if (-not [string]::IsNullOrWhiteSpace($key)) {
    $parts += $key
  }

  if ($parts.Count -eq 0) {
    return 'Choose modifiers and one key.'
  }

  return ($parts -join ' + ')
}

function Update-HotkeyPreview {
  param([hashtable]$Editor)

  $Editor.Preview.Text = Get-HotkeyDisplayText -Editor $Editor
}

function Get-HotkeyValue {
  param(
    [hashtable]$Editor,
    [string]$Label
  )

  $parts = @()
  if ($Editor.Ctrl.Checked) { $parts += 'Ctrl' }
  if ($Editor.Alt.Checked) { $parts += 'Alt' }
  if ($Editor.Shift.Checked) { $parts += 'Shift' }
  if ($Editor.Win.Checked) { $parts += 'Win' }

  if ($parts.Count -eq 0) {
    throw "$Label needs at least one modifier."
  }

  $key = [string]$Editor.Key.SelectedItem
  if ([string]::IsNullOrWhiteSpace($key)) {
    throw "$Label needs one key."
  }

  $parts += $key
  return ($parts -join '+')
}

function New-HotkeyEditor {
  param(
    [string]$Title,
    [string]$Description,
    [int]$Left,
    [int]$Top,
    [string]$InitialValue
  )

  $surface = New-Object System.Windows.Forms.Panel
  $surface.Left = $Left
  $surface.Top = $Top
  $surface.Width = 300
  $surface.Height = 214
  $surface.BackColor = [System.Drawing.Color]::FromArgb(28, 18, 21)
  $surface.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

  $titleLabel = New-Object System.Windows.Forms.Label
  $titleLabel.Text = $Title
  $titleLabel.Left = 16
  $titleLabel.Top = 14
  $titleLabel.Width = 240
  $titleLabel.ForeColor = [System.Drawing.Color]::White
  $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5, [System.Drawing.FontStyle]::Bold)

  $descriptionLabel = New-Object System.Windows.Forms.Label
  $descriptionLabel.Text = $Description
  $descriptionLabel.Left = 16
  $descriptionLabel.Top = 42
  $descriptionLabel.Width = 260
  $descriptionLabel.Height = 32
  $descriptionLabel.ForeColor = [System.Drawing.Color]::FromArgb(210, 190, 190)
  $descriptionLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $modifierHeader = New-Object System.Windows.Forms.Label
  $modifierHeader.Text = 'Modifiers'
  $modifierHeader.Left = 16
  $modifierHeader.Top = 82
  $modifierHeader.Width = 90
  $modifierHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 140)
  $modifierHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5, [System.Drawing.FontStyle]::Bold)

  $modifierNames = @('Ctrl', 'Alt', 'Shift', 'Win')
  $modifierControls = @{}
  $modifierLeft = 16

  foreach ($modifierName in $modifierNames) {
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Text = $modifierName
    $checkBox.Left = $modifierLeft
    $checkBox.Top = 108
    $checkBox.Width = 64
    $checkBox.ForeColor = [System.Drawing.Color]::White
    $checkBox.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $checkBox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $checkBox.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(116, 64, 64)
    $checkBox.FlatAppearance.CheckedBackColor = [System.Drawing.Color]::FromArgb(86, 18, 18)
    $modifierControls[$modifierName] = $checkBox
    $modifierLeft += 68
    $surface.Controls.Add($checkBox)
  }

  $keyHeader = New-Object System.Windows.Forms.Label
  $keyHeader.Text = 'Primary key'
  $keyHeader.Left = 16
  $keyHeader.Top = 146
  $keyHeader.Width = 100
  $keyHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 140, 140)
  $keyHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5, [System.Drawing.FontStyle]::Bold)

  $keyCombo = New-Object System.Windows.Forms.ComboBox
  $keyCombo.Left = 16
  $keyCombo.Top = 168
  $keyCombo.Width = 118
  $keyCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
  $keyCombo.BackColor = [System.Drawing.Color]::FromArgb(18, 10, 13)
  $keyCombo.ForeColor = [System.Drawing.Color]::White
  $keyCombo.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
  $null = $keyCombo.Items.AddRange(@(
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
    'Esc', 'Space'
  ))

  $previewPanel = New-Object System.Windows.Forms.Panel
  $previewPanel.Left = 146
  $previewPanel.Top = 164
  $previewPanel.Width = 138
  $previewPanel.Height = 34
  $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(18, 10, 13)
  $previewPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

  $previewLabel = New-Object System.Windows.Forms.Label
  $previewLabel.Left = 10
  $previewLabel.Top = 8
  $previewLabel.Width = 118
  $previewLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
  $previewLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $previewPanel.Controls.Add($previewLabel)

  $surface.Controls.AddRange(@(
    $titleLabel,
    $descriptionLabel,
    $modifierHeader,
    $keyHeader,
    $keyCombo,
    $previewPanel
  ))

  $editor = [ordered]@{
    Surface = $surface
    Ctrl = $modifierControls['Ctrl']
    Alt = $modifierControls['Alt']
    Shift = $modifierControls['Shift']
    Win = $modifierControls['Win']
    Key = $keyCombo
    Preview = $previewLabel
  }

  $initialParts = Convert-HotkeyToParts -Value $InitialValue
  $editor.Ctrl.Checked = $initialParts.Ctrl
  $editor.Alt.Checked = $initialParts.Alt
  $editor.Shift.Checked = $initialParts.Shift
  $editor.Win.Checked = $initialParts.Win
  if (-not [string]::IsNullOrWhiteSpace($initialParts.Key)) {
    $editor.Key.SelectedItem = $initialParts.Key
  }

  $updateAction = {
    Update-HotkeyPreview -Editor $editor
  }

  $editor.Ctrl.Add_CheckedChanged($updateAction)
  $editor.Alt.Add_CheckedChanged($updateAction)
  $editor.Shift.Add_CheckedChanged($updateAction)
  $editor.Win.Add_CheckedChanged($updateAction)
  $editor.Key.Add_SelectedIndexChanged($updateAction)

  Update-HotkeyPreview -Editor $editor

  return $editor
}

function Set-ChoiceTileState {
  param([System.Windows.Forms.RadioButton]$Button)

  if ($Button.Checked) {
    $Button.FlatAppearance.BorderSize = 3
    $Button.ForeColor = [System.Drawing.Color]::White
  } else {
    $Button.FlatAppearance.BorderSize = 1
    $Button.ForeColor = [System.Drawing.Color]::FromArgb(245, 236, 236)
  }
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $settingsMutexName, [ref]$createdNew)

if (-not $createdNew) {
  exit 0
}

try {
  $settings = Get-SavedSettings
  $settings.startupEnabled = Test-StartupEnabled

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Raining Code Settings'
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $form.ClientSize = New-Object System.Drawing.Size(760, 620)
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $form.MaximizeBox = $false
  $form.MinimizeBox = $false
  $form.BackColor = [System.Drawing.Color]::FromArgb(16, 9, 12)
  $form.ForeColor = [System.Drawing.Color]::White
  $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
  if (Test-Path -LiteralPath $settingsIconPath) {
    $form.Icon = New-Object System.Drawing.Icon($settingsIconPath)
  }

  $headerPanel = New-Object System.Windows.Forms.Panel
  $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
  $headerPanel.Height = 92
  $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(28, 10, 14)

  $titleLabel = New-Object System.Windows.Forms.Label
  $titleLabel.Text = 'Raining Code'
  $titleLabel.Left = 24
  $titleLabel.Top = 18
  $titleLabel.Width = 320
  $titleLabel.ForeColor = [System.Drawing.Color]::White
  $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18, [System.Drawing.FontStyle]::Bold)

  $subtitleLabel = New-Object System.Windows.Forms.Label
  $subtitleLabel.Text = 'Pick your startup, color, size, and shortcut settings. The app stays hidden until you use your hotkey.'
  $subtitleLabel.Left = 26
  $subtitleLabel.Top = 52
  $subtitleLabel.Width = 690
  $subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(225, 185, 185)
  $subtitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

  $headerPanel.Controls.AddRange(@($titleLabel, $subtitleLabel))

  $tabControl = New-Object System.Windows.Forms.TabControl
  $tabControl.Left = 22
  $tabControl.Top = 110
  $tabControl.Width = 716
  $tabControl.Height = 430
  $tabControl.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
  $tabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
  $tabControl.ItemSize = New-Object System.Drawing.Size(160, 34)
  $tabControl.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
  $tabControl.Add_DrawItem({
    param($sender, $eventArgs)

    $tabBounds = $eventArgs.Bounds
    $tabPage = $sender.TabPages[$eventArgs.Index]
    $isSelected = $sender.SelectedIndex -eq $eventArgs.Index
    $backgroundColor = if ($isSelected) { [System.Drawing.Color]::FromArgb(86, 18, 18) } else { [System.Drawing.Color]::FromArgb(30, 18, 21) }
    $foregroundColor = if ($isSelected) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::FromArgb(214, 194, 194) }

    $backgroundBrush = New-Object System.Drawing.SolidBrush($backgroundColor)

    $eventArgs.Graphics.FillRectangle($backgroundBrush, $tabBounds)
    $backgroundBrush.Dispose()
    [System.Windows.Forms.TextRenderer]::DrawText(
      $eventArgs.Graphics,
      $tabPage.Text,
      $sender.Font,
      $tabBounds,
      $foregroundColor,
      [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter
    )
  })

  $generalTab = New-Object System.Windows.Forms.TabPage
  $generalTab.Text = 'General'
  $generalTab.BackColor = [System.Drawing.Color]::FromArgb(20, 12, 16)

  $lookTab = New-Object System.Windows.Forms.TabPage
  $lookTab.Text = 'Look'
  $lookTab.BackColor = [System.Drawing.Color]::FromArgb(20, 12, 16)

  $hotkeysTab = New-Object System.Windows.Forms.TabPage
  $hotkeysTab.Text = 'Hotkeys'
  $hotkeysTab.BackColor = [System.Drawing.Color]::FromArgb(20, 12, 16)

  $tabControl.TabPages.AddRange(@($generalTab, $lookTab, $hotkeysTab))

  $launchCard = New-Object System.Windows.Forms.Panel
  $launchCard.Left = 22
  $launchCard.Top = 22
  $launchCard.Width = 660
  $launchCard.Height = 112
  $launchCard.BackColor = [System.Drawing.Color]::FromArgb(28, 18, 21)
  $launchCard.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

  $launchTitle = New-Object System.Windows.Forms.Label
  $launchTitle.Text = 'Start up'
  $launchTitle.Left = 18
  $launchTitle.Top = 16
  $launchTitle.Width = 220
  $launchTitle.ForeColor = [System.Drawing.Color]::White
  $launchTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11, [System.Drawing.FontStyle]::Bold)

  $launchInfo = New-Object System.Windows.Forms.Label
  $launchInfo.Text = 'Raining Code can start quietly in the background and wait for your hotkey. No extra window needs to stay open.'
  $launchInfo.Left = 18
  $launchInfo.Top = 42
  $launchInfo.Width = 620
  $launchInfo.Height = 36
  $launchInfo.ForeColor = [System.Drawing.Color]::FromArgb(214, 194, 194)
  $launchInfo.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $startupCheckbox = New-Object System.Windows.Forms.CheckBox
  $startupCheckbox.Text = 'Start Raining Code when I sign in'
  $startupCheckbox.Left = 18
  $startupCheckbox.Top = 80
  $startupCheckbox.Width = 290
  $startupCheckbox.Checked = [bool]$settings.startupEnabled
  $startupCheckbox.ForeColor = [System.Drawing.Color]::White
  $startupCheckbox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $startupCheckbox.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(116, 64, 64)
  $startupCheckbox.FlatAppearance.CheckedBackColor = [System.Drawing.Color]::FromArgb(86, 18, 18)

  $launchCard.Controls.AddRange(@($launchTitle, $launchInfo, $startupCheckbox))

  $indicatorCard = New-Object System.Windows.Forms.Panel
  $indicatorCard.Left = 22
  $indicatorCard.Top = 150
  $indicatorCard.Width = 660
  $indicatorCard.Height = 126
  $indicatorCard.BackColor = [System.Drawing.Color]::FromArgb(28, 18, 21)
  $indicatorCard.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

  $indicatorTitle = New-Object System.Windows.Forms.Label
  $indicatorTitle.Text = 'Tray icon'
  $indicatorTitle.Left = 18
  $indicatorTitle.Top = 16
  $indicatorTitle.Width = 160
  $indicatorTitle.ForeColor = [System.Drawing.Color]::White
  $indicatorTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11, [System.Drawing.FontStyle]::Bold)

  $indicatorInfo = New-Object System.Windows.Forms.Label
  $indicatorInfo.Text = 'You do not need any window on screen for this app to work. Turn this on only if you want a small icon near the clock.'
  $indicatorInfo.Left = 18
  $indicatorInfo.Top = 42
  $indicatorInfo.Width = 620
  $indicatorInfo.Height = 36
  $indicatorInfo.ForeColor = [System.Drawing.Color]::FromArgb(214, 194, 194)
  $indicatorInfo.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $trayCheckbox = New-Object System.Windows.Forms.CheckBox
  $trayCheckbox.Text = 'Show a tray icon'
  $trayCheckbox.Left = 18
  $trayCheckbox.Top = 84
  $trayCheckbox.Width = 330
  $trayCheckbox.Checked = [bool]$settings.showTrayIcon
  $trayCheckbox.ForeColor = [System.Drawing.Color]::White
  $trayCheckbox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $trayCheckbox.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(116, 64, 64)
  $trayCheckbox.FlatAppearance.CheckedBackColor = [System.Drawing.Color]::FromArgb(86, 18, 18)

  $indicatorCard.Controls.AddRange(@($indicatorTitle, $indicatorInfo, $trayCheckbox))

  $generalTab.Controls.AddRange(@($launchCard, $indicatorCard))

  $lookIntro = New-Object System.Windows.Forms.Label
  $lookIntro.Text = 'Choose the look you want at startup. While the effect is open, press C to change color or S to change size.'
  $lookIntro.Left = 24
  $lookIntro.Top = 24
  $lookIntro.Width = 650
  $lookIntro.ForeColor = [System.Drawing.Color]::FromArgb(220, 196, 196)
  $lookIntro.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

  $colorLabel = New-Object System.Windows.Forms.Label
  $colorLabel.Text = 'Color'
  $colorLabel.Left = 24
  $colorLabel.Top = 58
  $colorLabel.Width = 140
  $colorLabel.ForeColor = [System.Drawing.Color]::White
  $colorLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5, [System.Drawing.FontStyle]::Bold)

  $colorFlow = New-Object System.Windows.Forms.FlowLayoutPanel
  $colorFlow.Left = 22
  $colorFlow.Top = 88
  $colorFlow.Width = 664
  $colorFlow.Height = 152
  $colorFlow.WrapContents = $true
  $colorFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight

  $colorChoices = @(
    [pscustomobject]@{ Name = 'Red'; Back = [System.Drawing.Color]::FromArgb(111, 18, 18); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Orange'; Back = [System.Drawing.Color]::FromArgb(125, 52, 14); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Gold'; Back = [System.Drawing.Color]::FromArgb(118, 82, 8); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Green'; Back = [System.Drawing.Color]::FromArgb(18, 78, 34); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Cyan'; Back = [System.Drawing.Color]::FromArgb(14, 66, 92); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Blue'; Back = [System.Drawing.Color]::FromArgb(18, 42, 102); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Violet'; Back = [System.Drawing.Color]::FromArgb(66, 28, 96); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Pink'; Back = [System.Drawing.Color]::FromArgb(110, 28, 76); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'White'; Back = [System.Drawing.Color]::FromArgb(86, 86, 86); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Rainbow'; Back = [System.Drawing.Color]::FromArgb(72, 30, 80); Fore = [System.Drawing.Color]::White }
  )

  $colorButtons = New-Object System.Collections.ArrayList
  foreach ($colorChoice in $colorChoices) {
    $button = New-Object System.Windows.Forms.RadioButton
    $button.Appearance = [System.Windows.Forms.Appearance]::Button
    $button.AutoSize = $false
    $button.Width = 122
    $button.Height = 64
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 12)
    $button.Text = $colorChoice.Name
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10, [System.Drawing.FontStyle]::Bold)
    $button.BackColor = $colorChoice.Back
    $button.ForeColor = $colorChoice.Fore
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(246, 217, 217)
    $button.FlatAppearance.CheckedBackColor = $colorChoice.Back
    $button.Tag = $colorChoice.Name

    $button.Add_CheckedChanged({
      param($sender, $eventArgs)
      Set-ChoiceTileState -Button $sender
    })

    if ($settings.defaultColorMode -eq $colorChoice.Name) {
      $button.Checked = $true
    } else {
      Set-ChoiceTileState -Button $button
    }

    $null = $colorButtons.Add($button)
    $colorFlow.Controls.Add($button)
  }

  $sizeLabel = New-Object System.Windows.Forms.Label
  $sizeLabel.Text = 'Size'
  $sizeLabel.Left = 24
  $sizeLabel.Top = 252
  $sizeLabel.Width = 140
  $sizeLabel.ForeColor = [System.Drawing.Color]::White
  $sizeLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5, [System.Drawing.FontStyle]::Bold)

  $sizeIntro = New-Object System.Windows.Forms.Label
  $sizeIntro.Text = 'Small keeps the current look. Larger sizes make the code streams bolder and wider.'
  $sizeIntro.Left = 24
  $sizeIntro.Top = 278
  $sizeIntro.Width = 650
  $sizeIntro.ForeColor = [System.Drawing.Color]::FromArgb(214, 194, 194)
  $sizeIntro.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $sizeFlow = New-Object System.Windows.Forms.FlowLayoutPanel
  $sizeFlow.Left = 22
  $sizeFlow.Top = 314
  $sizeFlow.Width = 664
  $sizeFlow.Height = 86
  $sizeFlow.WrapContents = $false
  $sizeFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight

  $sizeChoices = @(
    [pscustomobject]@{ Name = 'Small'; Back = [System.Drawing.Color]::FromArgb(44, 25, 30); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Medium'; Back = [System.Drawing.Color]::FromArgb(58, 30, 36); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Large'; Back = [System.Drawing.Color]::FromArgb(74, 34, 42); Fore = [System.Drawing.Color]::White },
    [pscustomobject]@{ Name = 'Jumbo'; Back = [System.Drawing.Color]::FromArgb(92, 36, 46); Fore = [System.Drawing.Color]::White }
  )

  $sizeButtons = New-Object System.Collections.ArrayList
  foreach ($sizeChoice in $sizeChoices) {
    $button = New-Object System.Windows.Forms.RadioButton
    $button.Appearance = [System.Windows.Forms.Appearance]::Button
    $button.AutoSize = $false
    $button.Width = 155
    $button.Height = 72
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
    $button.Text = $sizeChoice.Name
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10, [System.Drawing.FontStyle]::Bold)
    $button.BackColor = $sizeChoice.Back
    $button.ForeColor = $sizeChoice.Fore
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(246, 217, 217)
    $button.FlatAppearance.CheckedBackColor = $sizeChoice.Back
    $button.Tag = $sizeChoice.Name

    $button.Add_CheckedChanged({
      param($sender, $eventArgs)
      Set-ChoiceTileState -Button $sender
    })

    if ($settings.defaultSizeMode -eq $sizeChoice.Name) {
      $button.Checked = $true
    } else {
      Set-ChoiceTileState -Button $button
    }

    $null = $sizeButtons.Add($button)
    $sizeFlow.Controls.Add($button)
  }

  $lookNote = New-Object System.Windows.Forms.Label
  $lookNote.Text = 'Red + Small is the default starting look.'
  $lookNote.Left = 24
  $lookNote.Top = 410
  $lookNote.Width = 640
  $lookNote.ForeColor = [System.Drawing.Color]::FromArgb(198, 170, 170)
  $lookNote.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $lookTab.Controls.AddRange(@($lookIntro, $colorLabel, $colorFlow, $sizeLabel, $sizeIntro, $sizeFlow, $lookNote))

  $hotkeyIntro = New-Object System.Windows.Forms.Label
  $hotkeyIntro.Text = 'Choose one shortcut to turn the effect on or off, and another to fully close the app. Ctrl+Alt+M is the default because Fn keys usually do not work here.'
  $hotkeyIntro.Left = 24
  $hotkeyIntro.Top = 24
  $hotkeyIntro.Width = 650
  $hotkeyIntro.Height = 34
  $hotkeyIntro.ForeColor = [System.Drawing.Color]::FromArgb(220, 196, 196)
  $hotkeyIntro.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

  $toggleEditor = New-HotkeyEditor -Title 'Show or hide effect' -Description 'This shortcut turns the fullscreen effect on and off.' -Left 24 -Top 78 -InitialValue $settings.toggleHotkey
  $quitEditor = New-HotkeyEditor -Title 'Close app' -Description 'This shortcut fully closes the background app.' -Left 344 -Top 78 -InitialValue $settings.quitHotkey

  $hotkeysTab.Controls.AddRange(@($hotkeyIntro, $toggleEditor.Surface, $quitEditor.Surface))

  $statusLabel = New-Object System.Windows.Forms.Label
  $statusLabel.Left = 28
  $statusLabel.Top = 560
  $statusLabel.Width = 420
  $statusLabel.Height = 24
  $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(214, 194, 194)
  $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $cancelButton = New-Object System.Windows.Forms.Button
  $cancelButton.Text = 'Cancel'
  $cancelButton.Width = 110
  $cancelButton.Height = 38
  $cancelButton.Left = 502
  $cancelButton.Top = 552
  $cancelButton.BackColor = [System.Drawing.Color]::FromArgb(44, 25, 30)
  $cancelButton.ForeColor = [System.Drawing.Color]::White
  $cancelButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $cancelButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(116, 64, 64)
  $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

  $saveButton = New-Object System.Windows.Forms.Button
  $saveButton.Text = 'Save'
  $saveButton.Width = 126
  $saveButton.Height = 38
  $saveButton.Left = 622
  $saveButton.Top = 552
  $saveButton.BackColor = [System.Drawing.Color]::FromArgb(111, 18, 18)
  $saveButton.ForeColor = [System.Drawing.Color]::White
  $saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $saveButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255, 136, 136)

  $saveButton.Add_Click({
    try {
      $toggleHotkey = Get-HotkeyValue -Editor $toggleEditor -Label 'Show or hide shortcut'
      $quitHotkey = Get-HotkeyValue -Editor $quitEditor -Label 'Close app shortcut'

      if ($toggleHotkey -eq $quitHotkey) {
        throw 'Use different shortcuts for these two actions.'
      }

      $selectedColor = ($colorButtons | Where-Object { $_.Checked } | Select-Object -First 1)
      if ($null -eq $selectedColor) {
        throw 'Choose a starting color.'
      }

      $selectedSize = ($sizeButtons | Where-Object { $_.Checked } | Select-Object -First 1)
      if ($null -eq $selectedSize) {
        throw 'Choose a starting size.'
      }

      $newSettings = [ordered]@{
        toggleHotkey = $toggleHotkey
        quitHotkey = $quitHotkey
        startupEnabled = [bool]$startupCheckbox.Checked
        defaultColorMode = [string]$selectedColor.Tag
        defaultSizeMode = [string]$selectedSize.Tag
        showTrayIcon = [bool]$trayCheckbox.Checked
      }

      Save-Settings -Settings $newSettings
      Set-StartupEnabled -Enabled $newSettings.startupEnabled
      Restart-HotkeyHelper

      $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
      $form.Close()
    } catch {
      $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160)
      $statusLabel.Text = $_.Exception.Message
    }
  })

  $form.AcceptButton = $saveButton
  $form.CancelButton = $cancelButton
  $form.Controls.AddRange(@($headerPanel, $tabControl, $statusLabel, $cancelButton, $saveButton))

  [void]$form.ShowDialog()
} finally {
  if ($null -ne $mutex) {
    try {
      if ($createdNew) {
        $mutex.ReleaseMutex() | Out-Null
      }
    } catch {
    }

    $mutex.Dispose()
  }
}
