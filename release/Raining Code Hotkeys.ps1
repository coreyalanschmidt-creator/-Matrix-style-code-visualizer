Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsPath = Join-Path $scriptDir 'hotkey-settings.json'
$logPath = Join-Path $scriptDir 'raining-code-launcher.log'
$settingsLauncherPath = Join-Path $scriptDir 'Raining Code Settings.cmd'
$visualizerIconPath = Join-Path $scriptDir 'Raining Code Icon.ico'
$mutexName = 'Local\RainingCodeHotkeyHost'

function Write-LauncherLog {
  param([string]$Message)

  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -LiteralPath $logPath -Value "$timestamp $Message" -ErrorAction SilentlyContinue
}

function Get-DefaultSettings {
  return [ordered]@{
    toggleHotkey = 'Ctrl+Alt+M'
    quitHotkey = 'Ctrl+Alt+Q'
    startupEnabled = $true
    defaultColorMode = 'Red'
    defaultSizeMode = 'Small'
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

function Get-HotkeySettings {
  $defaults = Get-DefaultSettings

  if (-not (Test-Path -LiteralPath $settingsPath)) {
    return [pscustomobject]$defaults
  }

  try {
    $raw = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Write-LauncherLog 'Could not read hotkey-settings.json. Using defaults.'
    return [pscustomobject]$defaults
  }

  $toggleHotkey = [string]$parsed.toggleHotkey
  $quitHotkey = [string]$parsed.quitHotkey

  if ([string]::IsNullOrWhiteSpace($toggleHotkey)) {
    $toggleHotkey = [string]$defaults.toggleHotkey
  }

  if ([string]::IsNullOrWhiteSpace($quitHotkey)) {
    $quitHotkey = [string]$defaults.quitHotkey
  }

  $defaultColorMode = Normalize-ColorModeName -Value ([string]$parsed.defaultColorMode) -Fallback ([string]$defaults.defaultColorMode)
  $defaultSizeMode = Normalize-SizeModeName -Value ([string]$parsed.defaultSizeMode) -Fallback ([string]$defaults.defaultSizeMode)

  $startupEnabled = $defaults.startupEnabled
  if ($null -ne $parsed.startupEnabled) {
    $startupEnabled = [bool]$parsed.startupEnabled
  }

  return [pscustomobject]@{
    toggleHotkey = $toggleHotkey
    quitHotkey = $quitHotkey
    startupEnabled = $startupEnabled
    defaultColorMode = $defaultColorMode
    defaultSizeMode = $defaultSizeMode
    showTrayIcon = $false
  }
}

function Convert-ColorModeName {
  param([string]$Value)

  switch (Normalize-ColorModeName -Value $Value) {
    'Orange' { return [MatrixColorMode]::Orange }
    'Gold' { return [MatrixColorMode]::Gold }
    'Green' { return [MatrixColorMode]::Green }
    'Cyan' { return [MatrixColorMode]::Cyan }
    'Blue' { return [MatrixColorMode]::Blue }
    'Violet' { return [MatrixColorMode]::Violet }
    'Pink' { return [MatrixColorMode]::Pink }
    'White' { return [MatrixColorMode]::White }
    'Rainbow' { return [MatrixColorMode]::Rainbow }
    default { return [MatrixColorMode]::Red }
  }
}

function Convert-SizeModeName {
  param([string]$Value)

  switch (Normalize-SizeModeName -Value $Value) {
    'Medium' { return [RainSizeMode]::Medium }
    'Large' { return [RainSizeMode]::Large }
    'Jumbo' { return [RainSizeMode]::Jumbo }
    default { return [RainSizeMode]::Small }
  }
}

function Convert-KeyTokenToCode {
  param([string]$Token)

  $upper = $Token.Trim().ToUpperInvariant()

  if ($upper.Length -eq 1) {
    $char = $upper[0]
    if (($char -ge 'A' -and $char -le 'Z') -or ($char -ge '0' -and $char -le '9')) {
      return [int][char]$char
    }
  }

  if ($upper -match '^F([1-9]|1[0-9]|2[0-4])$') {
    $number = [int]$Matches[1]
    return 0x70 + ($number - 1)
  }

  switch ($upper) {
    'ESC' { return 0x1B }
    'SPACE' { return 0x20 }
    default { throw "Unsupported hotkey key '$Token'." }
  }
}

function Convert-HotkeyString {
  param([string]$Value)

  $parts = $Value -split '\+'
  $modifiers = 0
  $keyCode = $null

  foreach ($rawPart in $parts) {
    $part = $rawPart.Trim()
    if ([string]::IsNullOrWhiteSpace($part)) {
      continue
    }

    switch -Regex ($part.ToUpperInvariant()) {
      '^CTRL$|^CONTROL$' {
        $modifiers = $modifiers -bor 0x0002
        continue
      }
      '^ALT$' {
        $modifiers = $modifiers -bor 0x0001
        continue
      }
      '^SHIFT$' {
        $modifiers = $modifiers -bor 0x0004
        continue
      }
      '^WIN$|^WINDOWS$|^SUPER$' {
        $modifiers = $modifiers -bor 0x0008
        continue
      }
      default {
        if ($null -ne $keyCode) {
          throw "Only one non-modifier key is allowed in '$Value'."
        }

        $keyCode = Convert-KeyTokenToCode -Token $part
      }
    }
  }

  if ($modifiers -eq 0 -or $null -eq $keyCode) {
    throw "Hotkey '$Value' must contain modifiers plus one supported key."
  }

  return [pscustomobject]@{
    Display = $Value
    Modifiers = [uint32]$modifiers
    KeyCode = [uint32]$keyCode
  }
}

Write-LauncherLog 'Hotkey helper script started.'

Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public enum MatrixColorMode
{
    Red = 0,
    Orange = 1,
    Gold = 2,
    Green = 3,
    Cyan = 4,
    Blue = 5,
    Violet = 6,
    Pink = 7,
    White = 8,
    Rainbow = 9
}

public enum RainSizeMode
{
    Small = 0,
    Medium = 1,
    Large = 2,
    Jumbo = 3
}

public sealed class MatrixColumn
{
    public float X;
    public float Y;
    public float Speed;
    public int TrailLength;
    public int LastRow;
    public float HueSeed;
    public readonly List<char> History = new List<char>();
}

public sealed class MatrixVisualizerForm : Form
{
    private readonly string logPath;
    private readonly Timer timer;
    private readonly Random random = new Random();
    private readonly List<MatrixColumn> columns = new List<MatrixColumn>();
    private readonly string glyphs = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$%&*+-=/\\\\<>[]{}";
    private Font matrixFont;
    private Bitmap frameBuffer;
    private Graphics frameGraphics;
    private DateTime lastFrameUtc = DateTime.UtcNow;
    private bool paused;
    private MatrixColorMode colorMode = MatrixColorMode.Red;
    private RainSizeMode sizeMode = RainSizeMode.Small;
    private float cellWidth = 20f;
    private float cellHeight = 26f;
    private float minSpeed = 120f;
    private float maxSpeed = 300f;
    private int minTrailLength = 8;
    private int maxTrailLength = 18;

    private const float FadeAlpha = 0.14f;

    public MatrixVisualizerForm(string logPath, MatrixColorMode defaultColorMode, RainSizeMode defaultSizeMode)
    {
        this.logPath = logPath;
        this.colorMode = defaultColorMode;
        ApplySizeMode(defaultSizeMode, false);
        this.Text = "Raining Code";
        this.FormBorderStyle = FormBorderStyle.None;
        this.ShowInTaskbar = false;
        this.StartPosition = FormStartPosition.Manual;
        this.TopMost = true;
        this.BackColor = Color.Black;
        this.KeyPreview = true;
        this.DoubleBuffered = true;
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);

        this.timer = new Timer();
        this.timer.Interval = 33;
        this.timer.Tick += delegate(object sender, EventArgs args) { AdvanceFrame(); };

        this.KeyDown += HandleKeyDown;
        this.FormClosing += HandleFormClosing;
    }

    public bool IsVisualizerVisible
    {
        get
        {
            return this.Visible;
        }
    }

    public void ShowVisualizer()
    {
        var targetScreen = Screen.FromPoint(Cursor.Position);
        this.Bounds = targetScreen.Bounds;
        this.WindowState = FormWindowState.Normal;
        this.Bounds = targetScreen.Bounds;
        this.RebuildScene();
        this.paused = false;
        this.lastFrameUtc = DateTime.UtcNow;

        if (!this.Visible)
        {
            this.Show();
        }

        this.TopMost = true;
        this.BringToFront();
        this.Activate();
        this.Focus();
        this.timer.Start();

        try
        {
            Cursor.Hide();
        }
        catch
        {
        }

        AppendLog(this.logPath, "Visualizer shown.");
    }

    public void HideVisualizer()
    {
        if (this.Visible)
        {
            AppendLog(this.logPath, "Visualizer hidden.");
        }

        this.timer.Stop();
        this.Hide();

        try
        {
            Cursor.Show();
        }
        catch
        {
        }
    }

    public void ToggleVisualizer()
    {
        if (this.IsVisualizerVisible)
        {
            this.HideVisualizer();
        }
        else
        {
            this.ShowVisualizer();
        }
    }

    public void SetColorMode(MatrixColorMode colorMode)
    {
        this.colorMode = colorMode;
    }

    public void SetSizeMode(RainSizeMode sizeMode)
    {
        if (this.sizeMode == sizeMode)
        {
            return;
        }

        ApplySizeMode(sizeMode, this.Visible);
    }

    private void HandleFormClosing(object sender, FormClosingEventArgs e)
    {
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            this.HideVisualizer();
        }
    }

    private void HandleKeyDown(object sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Escape)
        {
            this.HideVisualizer();
            e.Handled = true;
            return;
        }

        if (e.KeyCode == Keys.Space)
        {
            this.paused = !this.paused;
            AppendLog(this.logPath, this.paused ? "Visualizer paused." : "Visualizer resumed.");
            e.Handled = true;
            return;
        }

        if (e.KeyCode == Keys.C)
        {
            this.colorMode = (MatrixColorMode)(((int)this.colorMode + 1) % 10);
            AppendLog(this.logPath, "Color mode changed to " + this.colorMode + ".");
            e.Handled = true;
            return;
        }

        if (e.KeyCode == Keys.S)
        {
            this.SetSizeMode((RainSizeMode)(((int)this.sizeMode + 1) % 4));
            AppendLog(this.logPath, "Size changed to " + this.sizeMode + ".");
            e.Handled = true;
            return;
        }
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (this.frameBuffer != null)
        {
            e.Graphics.DrawImageUnscaled(this.frameBuffer, 0, 0);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (this.timer != null)
            {
                this.timer.Dispose();
            }

            if (this.frameGraphics != null)
            {
                this.frameGraphics.Dispose();
            }

            if (this.frameBuffer != null)
            {
                this.frameBuffer.Dispose();
            }

            if (this.matrixFont != null)
            {
                this.matrixFont.Dispose();
            }
        }

        base.Dispose(disposing);
    }

    private void ApplySizeMode(RainSizeMode sizeMode, bool rebuildScene)
    {
        this.sizeMode = sizeMode;

        var fontSize = 18f;
        switch (sizeMode)
        {
            case RainSizeMode.Medium:
                fontSize = 28f;
                this.cellWidth = 30f;
                this.cellHeight = 38f;
                this.minSpeed = 150f;
                this.maxSpeed = 340f;
                this.minTrailLength = 9;
                this.maxTrailLength = 18;
                break;
            case RainSizeMode.Large:
                fontSize = 40f;
                this.cellWidth = 42f;
                this.cellHeight = 54f;
                this.minSpeed = 180f;
                this.maxSpeed = 390f;
                this.minTrailLength = 10;
                this.maxTrailLength = 18;
                break;
            case RainSizeMode.Jumbo:
                fontSize = 56f;
                this.cellWidth = 58f;
                this.cellHeight = 74f;
                this.minSpeed = 210f;
                this.maxSpeed = 430f;
                this.minTrailLength = 10;
                this.maxTrailLength = 16;
                break;
            default:
                fontSize = 18f;
                this.cellWidth = 20f;
                this.cellHeight = 26f;
                this.minSpeed = 120f;
                this.maxSpeed = 300f;
                this.minTrailLength = 8;
                this.maxTrailLength = 18;
                break;
        }

        if (this.matrixFont != null)
        {
            this.matrixFont.Dispose();
        }

        this.matrixFont = new Font("Consolas", fontSize, FontStyle.Regular, GraphicsUnit.Pixel);

        if (rebuildScene)
        {
            RebuildScene();
        }
    }

    private MatrixColumn CreateColumn(int index, int height)
    {
        var column = new MatrixColumn
        {
            X = index * this.cellWidth + this.cellWidth * 0.5f,
            Y = RandomBetween(-height, 0),
            Speed = RandomBetween(this.minSpeed, this.maxSpeed),
            TrailLength = RandomInteger(this.minTrailLength, this.maxTrailLength),
            HueSeed = RandomBetween(0, 360)
        };

        column.LastRow = (int)Math.Floor(column.Y / this.cellHeight);
        column.History.Add(RandomGlyph());
        return column;
    }

    private void RebuildScene()
    {
        var width = Math.Max(1, this.ClientSize.Width);
        var height = Math.Max(1, this.ClientSize.Height);

        if (this.frameGraphics != null)
        {
            this.frameGraphics.Dispose();
            this.frameGraphics = null;
        }

        if (this.frameBuffer != null)
        {
            this.frameBuffer.Dispose();
            this.frameBuffer = null;
        }

        this.frameBuffer = new Bitmap(width, height, PixelFormat.Format32bppPArgb);
        this.frameGraphics = Graphics.FromImage(this.frameBuffer);
        this.frameGraphics.SmoothingMode = SmoothingMode.HighSpeed;
        this.frameGraphics.PixelOffsetMode = PixelOffsetMode.HighSpeed;
        this.frameGraphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        this.frameGraphics.CompositingMode = CompositingMode.SourceOver;
        this.frameGraphics.Clear(Color.FromArgb(2, 0, 0));

        this.columns.Clear();

        var columnCount = Math.Max(12, (int)Math.Ceiling(width / this.cellWidth));
        for (var index = 0; index < columnCount; index += 1)
        {
            this.columns.Add(CreateColumn(index, height));
        }
    }

    private void AdvanceFrame()
    {
        if (!this.Visible || this.frameGraphics == null || this.frameBuffer == null)
        {
            return;
        }

        if (this.paused)
        {
            return;
        }

        var now = DateTime.UtcNow;
        var deltaSeconds = Math.Min((now - this.lastFrameUtc).TotalSeconds, 0.05);
        if (deltaSeconds < 0)
        {
            deltaSeconds = 0;
        }

        this.lastFrameUtc = now;
        var elapsedSeconds = now.TimeOfDay.TotalSeconds;

        DrawBackdrop(elapsedSeconds);

        foreach (var column in this.columns)
        {
            column.Y += column.Speed * (float)deltaSeconds;

            var row = (int)Math.Floor(column.Y / this.cellHeight);
            if (row > column.LastRow)
            {
                for (var nextRow = column.LastRow + 1; nextRow <= row; nextRow += 1)
                {
                    column.History.Insert(0, RandomGlyph());
                    if (column.History.Count > column.TrailLength)
                    {
                        column.History.RemoveAt(column.History.Count - 1);
                    }
                }

                column.LastRow = row;
            }

            if (column.Y - column.TrailLength * this.cellHeight > this.frameBuffer.Height + this.cellHeight * 2)
            {
                ResetColumn(column);
            }

            DrawColumn(column, elapsedSeconds);
        }

        this.Invalidate();
    }

    private void DrawBackdrop(double elapsedSeconds)
    {
        using (var fadeBrush = new SolidBrush(Color.FromArgb((int)(FadeAlpha * 255), 0, 0, 0)))
        {
            this.frameGraphics.FillRectangle(fadeBrush, 0, 0, this.frameBuffer.Width, this.frameBuffer.Height);
        }

        using (var washBrush = new SolidBrush(GetWashColor(elapsedSeconds)))
        {
            this.frameGraphics.FillRectangle(washBrush, 0, 0, this.frameBuffer.Width, this.frameBuffer.Height);
        }
    }

    private void DrawColumn(MatrixColumn column, double elapsedSeconds)
    {
        var rowTop = (int)Math.Floor(column.Y / this.cellHeight);

        for (var age = 0; age < column.History.Count; age += 1)
        {
            var row = rowTop - age;
            if (row < -2)
            {
                continue;
            }

            var glyph = column.History[age].ToString();
            var alpha = age == 0 ? 240 : Math.Max(48, 220 - age * 11);
            var y = row * this.cellHeight + this.cellHeight * 0.52f;
            var bounds = new Rectangle(
                (int)Math.Round(column.X - this.cellWidth),
                (int)Math.Round(y - this.cellHeight),
                (int)Math.Ceiling(this.cellWidth * 2),
                (int)Math.Ceiling(this.cellHeight * 2));

            var trailColor = GetTrailColor(elapsedSeconds, column.HueSeed, age, alpha);
            TextRenderer.DrawText(
                this.frameGraphics,
                glyph,
                this.matrixFont,
                bounds,
                trailColor,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);

            if (age == 0)
            {
                var headColor = GetHeadColor(elapsedSeconds, column.HueSeed);
                var glowBounds = new Rectangle(bounds.X - 1, bounds.Y - 1, bounds.Width + 2, bounds.Height + 2);
                TextRenderer.DrawText(
                    this.frameGraphics,
                    glyph,
                    this.matrixFont,
                    glowBounds,
                    Color.FromArgb(170, headColor),
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                TextRenderer.DrawText(
                    this.frameGraphics,
                    glyph,
                    this.matrixFont,
                    bounds,
                    headColor,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
            }
        }
    }

    private void ResetColumn(MatrixColumn column)
    {
        column.Y = RandomBetween(-this.frameBuffer.Height * 0.8f, 0);
        column.Speed = RandomBetween(this.minSpeed, this.maxSpeed);
        column.TrailLength = RandomInteger(this.minTrailLength, this.maxTrailLength);
        column.LastRow = (int)Math.Floor(column.Y / this.cellHeight);
        column.History.Clear();
        column.History.Add(RandomGlyph());
        column.HueSeed = RandomBetween(0, 360);
    }

    private char RandomGlyph()
    {
        return this.glyphs[this.random.Next(this.glyphs.Length)];
    }

    private int RandomInteger(int min, int max)
    {
        return this.random.Next(min, max + 1);
    }

    private float RandomBetween(float min, float max)
    {
        return min + (float)this.random.NextDouble() * (max - min);
    }

    private Color GetHeadColor(double elapsedSeconds, float hueSeed)
    {
        switch (this.colorMode)
        {
            case MatrixColorMode.Rainbow:
                return ColorFromHsv((hueSeed + elapsedSeconds * 25) % 360, 0.2, 1.0, 245);
            case MatrixColorMode.Orange:
                return Color.FromArgb(245, 255, 244, 232);
            case MatrixColorMode.Gold:
                return Color.FromArgb(245, 255, 251, 234);
            case MatrixColorMode.Green:
                return Color.FromArgb(245, 240, 255, 241);
            case MatrixColorMode.Cyan:
                return Color.FromArgb(245, 240, 255, 255);
            case MatrixColorMode.Blue:
                return Color.FromArgb(245, 242, 247, 255);
            case MatrixColorMode.Violet:
                return Color.FromArgb(245, 252, 244, 255);
            case MatrixColorMode.Pink:
                return Color.FromArgb(245, 255, 241, 248);
            case MatrixColorMode.White:
                return Color.FromArgb(245, 255, 255, 255);
            default:
                return Color.FromArgb(245, 255, 246, 246);
        }
    }

    private Color GetTrailColor(double elapsedSeconds, float hueSeed, int age, int alpha)
    {
        switch (this.colorMode)
        {
            case MatrixColorMode.Rainbow:
                return ColorFromHsv((hueSeed + elapsedSeconds * 25 + age * 10) % 360, 0.75, Math.Max(0.35, 0.92 - age * 0.05), alpha);
            case MatrixColorMode.Orange:
                return age == 0
                    ? Color.FromArgb(alpha, 255, 148, 74)
                    : Color.FromArgb(alpha, 186, 74, 0);
            case MatrixColorMode.Gold:
                return age == 0
                    ? Color.FromArgb(alpha, 255, 198, 92)
                    : Color.FromArgb(alpha, 184, 116, 12);
            case MatrixColorMode.Green:
                return age == 0
                    ? Color.FromArgb(alpha, 92, 255, 132)
                    : Color.FromArgb(alpha, 18, 150, 48);
            case MatrixColorMode.Cyan:
                return age == 0
                    ? Color.FromArgb(alpha, 116, 230, 255)
                    : Color.FromArgb(alpha, 20, 112, 166);
            case MatrixColorMode.Blue:
                return age == 0
                    ? Color.FromArgb(alpha, 120, 166, 255)
                    : Color.FromArgb(alpha, 28, 62, 188);
            case MatrixColorMode.Violet:
                return age == 0
                    ? Color.FromArgb(alpha, 220, 128, 255)
                    : Color.FromArgb(alpha, 118, 24, 158);
            case MatrixColorMode.Pink:
                return age == 0
                    ? Color.FromArgb(alpha, 255, 120, 198)
                    : Color.FromArgb(alpha, 176, 28, 112);
            case MatrixColorMode.White:
                return age == 0
                    ? Color.FromArgb(alpha, 235, 235, 235)
                    : Color.FromArgb(alpha, 132, 132, 132);
            default:
                return age == 0
                    ? Color.FromArgb(alpha, 255, 84, 84)
                    : Color.FromArgb(alpha, 186, 24, 24);
        }
    }

    private Color GetWashColor(double elapsedSeconds)
    {
        switch (this.colorMode)
        {
            case MatrixColorMode.Rainbow:
                return ColorFromHsv((elapsedSeconds * 16) % 360, 0.9, 0.18, 28);
            case MatrixColorMode.Orange:
                return Color.FromArgb(24, 30, 10, 0);
            case MatrixColorMode.Gold:
                return Color.FromArgb(24, 26, 10, 0);
            case MatrixColorMode.Green:
                return Color.FromArgb(24, 0, 18, 4);
            case MatrixColorMode.Cyan:
                return Color.FromArgb(24, 0, 12, 24);
            case MatrixColorMode.Blue:
                return Color.FromArgb(24, 2, 6, 28);
            case MatrixColorMode.Violet:
                return Color.FromArgb(24, 20, 0, 28);
            case MatrixColorMode.Pink:
                return Color.FromArgb(24, 24, 0, 14);
            case MatrixColorMode.White:
                return Color.FromArgb(18, 18, 18, 18);
            default:
                return Color.FromArgb(24, 24, 0, 0);
        }
    }

    private static Color ColorFromHsv(double hue, double saturation, double value, int alpha)
    {
        var chroma = value * saturation;
        var segment = hue / 60.0;
        var x = chroma * (1 - Math.Abs(segment % 2 - 1));

        double r1;
        double g1;
        double b1;

        if (segment < 1)
        {
            r1 = chroma; g1 = x; b1 = 0;
        }
        else if (segment < 2)
        {
            r1 = x; g1 = chroma; b1 = 0;
        }
        else if (segment < 3)
        {
            r1 = 0; g1 = chroma; b1 = x;
        }
        else if (segment < 4)
        {
            r1 = 0; g1 = x; b1 = chroma;
        }
        else if (segment < 5)
        {
            r1 = x; g1 = 0; b1 = chroma;
        }
        else
        {
            r1 = chroma; g1 = 0; b1 = x;
        }

        var match = value - chroma;
        var r = (int)Math.Round((r1 + match) * 255);
        var g = (int)Math.Round((g1 + match) * 255);
        var b = (int)Math.Round((b1 + match) * 255);

        return Color.FromArgb(alpha, Math.Max(0, Math.Min(255, r)), Math.Max(0, Math.Min(255, g)), Math.Max(0, Math.Min(255, b)));
    }

    private static void AppendLog(string logPath, string message)
    {
        try
        {
            File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ") + message + Environment.NewLine);
        }
        catch
        {
        }
    }
}

public sealed class MatrixHotkeyHost : Form
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private readonly string logPath;
    private readonly string settingsLauncherPath;
    private readonly MatrixVisualizerForm visualizer;
    private readonly NotifyIcon trayIcon;
    private readonly ToolStripMenuItem toggleMenuItem;
    private readonly ToolStripMenuItem settingsMenuItem;
    private readonly ToolStripMenuItem exitMenuItem;

    public MatrixHotkeyHost(string logPath, MatrixColorMode defaultColorMode, RainSizeMode defaultSizeMode, bool showTrayIcon, string settingsLauncherPath, string visualizerIconPath)
    {
        this.logPath = logPath;
        this.settingsLauncherPath = settingsLauncherPath;
        this.visualizer = new MatrixVisualizerForm(logPath, defaultColorMode, defaultSizeMode);
        this.FormBorderStyle = FormBorderStyle.None;
        this.ShowInTaskbar = false;
        this.StartPosition = FormStartPosition.Manual;
        this.Location = new Point(-32000, -32000);
        this.Size = new Size(1, 1);
        this.WindowState = FormWindowState.Minimized;
        this.Opacity = 0;

        if (showTrayIcon)
        {
            var trayMenu = new ContextMenuStrip();

            this.toggleMenuItem = new ToolStripMenuItem("Show Effect");
            this.toggleMenuItem.Click += delegate(object sender, EventArgs args)
            {
                this.ToggleVisualizer();
            };

            this.settingsMenuItem = new ToolStripMenuItem("Open Settings");
            this.settingsMenuItem.Click += delegate(object sender, EventArgs args)
            {
                this.OpenSettings();
            };

            this.exitMenuItem = new ToolStripMenuItem("Exit");
            this.exitMenuItem.Click += delegate(object sender, EventArgs args)
            {
                this.ExitHost();
            };

            trayMenu.Items.Add(this.toggleMenuItem);
            trayMenu.Items.Add(this.settingsMenuItem);
            trayMenu.Items.Add(new ToolStripSeparator());
            trayMenu.Items.Add(this.exitMenuItem);

            this.trayIcon = new NotifyIcon();
            if (!string.IsNullOrWhiteSpace(visualizerIconPath) && File.Exists(visualizerIconPath))
            {
                this.trayIcon.Icon = new Icon(visualizerIconPath);
            }
            else
            {
                this.trayIcon.Icon = SystemIcons.Application;
            }
            this.trayIcon.Text = "Raining Code";
            this.trayIcon.Visible = true;
            this.trayIcon.ContextMenuStrip = trayMenu;
            this.trayIcon.DoubleClick += delegate(object sender, EventArgs args)
            {
                this.ToggleVisualizer();
            };

            UpdateTrayState();
        }
    }

    public bool TryRegisterHotKey(int id, uint modifiers, uint keyCode)
    {
        return RegisterHotKey(this.Handle, id, modifiers, keyCode);
    }

    public void ToggleVisualizer()
    {
        this.visualizer.ToggleVisualizer();
        UpdateTrayState();
    }

    public void ExitHost()
    {
        AppendLog(this.logPath, "Hotkey helper exiting.");
        this.visualizer.HideVisualizer();
        if (this.trayIcon != null)
        {
            this.trayIcon.Visible = false;
        }
        this.visualizer.Dispose();
        this.Close();
        Application.ExitThread();
    }

    private void OpenSettings()
    {
        try
        {
            var startInfo = new ProcessStartInfo();
            startInfo.FileName = this.settingsLauncherPath;
            startInfo.UseShellExecute = true;
            Process.Start(startInfo);
        }
        catch
        {
        }
    }

    private void UpdateTrayState()
    {
        if (this.trayIcon == null)
        {
            return;
        }

        this.trayIcon.Text = this.visualizer.IsVisualizerVisible ? "Raining Code - Active" : "Raining Code - Ready";
        if (this.toggleMenuItem != null)
        {
            this.toggleMenuItem.Text = this.visualizer.IsVisualizerVisible ? "Hide Effect" : "Show Effect";
        }
    }

    protected override void SetVisibleCore(bool value)
    {
        base.SetVisibleCore(false);
    }

    protected override void WndProc(ref Message m)
    {
        const int WM_HOTKEY = 0x0312;

        if (m.Msg == WM_HOTKEY)
        {
            int id = m.WParam.ToInt32();
            if (id == 1)
            {
                this.ToggleVisualizer();
            }
            else if (id == 2)
            {
                this.ExitHost();
                return;
            }
        }

        base.WndProc(ref m);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        UnregisterHotKey(this.Handle, 1);
        UnregisterHotKey(this.Handle, 2);
        if (this.trayIcon != null)
        {
            this.trayIcon.Visible = false;
            if (this.trayIcon.ContextMenuStrip != null)
            {
                this.trayIcon.ContextMenuStrip.Dispose();
            }

            this.trayIcon.Dispose();
        }
        this.visualizer.Dispose();
        base.OnFormClosed(e);
    }

    private static void AppendLog(string logPath, string message)
    {
        try
        {
            File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ") + message + Environment.NewLine);
        }
        catch
        {
        }
    }
}
"@

Write-LauncherLog 'Hotkey helper types compiled.'

$createdNew = $false
$mutex = $null

try {
  $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
  Write-LauncherLog "Mutex created. CreatedNew=$createdNew"

  if (-not $createdNew) {
    Write-LauncherLog 'Another helper instance is already running. Exiting duplicate launch.'
    exit 0
  }

  Write-LauncherLog 'Loading hotkey settings.'
  $settings = Get-HotkeySettings
  Write-LauncherLog "Settings loaded. Toggle=$($settings.toggleHotkey) Quit=$($settings.quitHotkey) Color=$($settings.defaultColorMode) Size=$($settings.defaultSizeMode)"
  $toggleHotkey = Convert-HotkeyString -Value $settings.toggleHotkey
  $quitHotkey = Convert-HotkeyString -Value $settings.quitHotkey
  $defaultColorMode = Convert-ColorModeName -Value $settings.defaultColorMode
  $defaultSizeMode = Convert-SizeModeName -Value $settings.defaultSizeMode

  Write-LauncherLog 'Creating hotkey host.'
  $hotkeyHost = New-Object MatrixHotkeyHost($logPath, $defaultColorMode, $defaultSizeMode, $false, $settingsLauncherPath, $visualizerIconPath)
  Write-LauncherLog 'Creating hidden host handle.'
  $null = $hotkeyHost.Handle
  Write-LauncherLog 'Registering hotkeys.'

  $toggleRegistered = $hotkeyHost.TryRegisterHotKey(1, $toggleHotkey.Modifiers, $toggleHotkey.KeyCode)
  $quitRegistered = $hotkeyHost.TryRegisterHotKey(2, $quitHotkey.Modifiers, $quitHotkey.KeyCode)

  if (-not $toggleRegistered -or -not $quitRegistered) {
    $message = "Could not register one or more hotkeys.`n`nToggle: $($toggleHotkey.Display)`nQuit: $($quitHotkey.Display)"
    Write-LauncherLog $message
    exit 1
  } else {
    Write-LauncherLog "Hotkey helper ready. Toggle=$($toggleHotkey.Display) Quit=$($quitHotkey.Display)"
  }

  Write-LauncherLog 'Entering Windows Forms message loop.'
  [System.Windows.Forms.Application]::Run($hotkeyHost)
} catch {
  Write-LauncherLog $_.Exception.ToString()
  exit 1
} finally {
  if ($null -ne $mutex) {
    try {
      if ($createdNew) {
        $mutex.ReleaseMutex() | Out-Null
      }
    } catch {}

    $mutex.Dispose()
  }
}
