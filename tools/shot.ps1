# Captures ONLY the Connect IQ simulator window to a PNG.
# Uses PrintWindow, so it works even when other windows cover the simulator
# and never steals focus from whatever you're doing.
# Usage: powershell -NoProfile -File tools\shot.ps1 [-Out path.png]
param([string]$Out = "$PSScriptRoot\..\bin\sim.png")
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W32 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[W32]::SetProcessDPIAware() | Out-Null
$p = Get-Process simulator -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { throw "simulator window not found" }
$h = $p.MainWindowHandle
if ([W32]::IsIconic($h)) { [W32]::ShowWindow($h, 4) | Out-Null; Start-Sleep -Milliseconds 400 }  # restore without activating
$r = New-Object W32+RECT
[W32]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L; $hgt = $r.B - $r.T
$bmp = [System.Drawing.Bitmap]::new($w, $hgt)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W32]::PrintWindow($h, $hdc, 2) | Out-Null     # 2 = PW_RENDERFULLCONTENT (GPU-drawn content too)
$g.ReleaseHdc($hdc)
$Out = [IO.Path]::GetFullPath($Out)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
$Out
