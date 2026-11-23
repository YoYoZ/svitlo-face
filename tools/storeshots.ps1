# Store / docs screenshots with demo data (no real settings, no real home or location data).
# Each case is a throwaway build: the DEMO switches it names are turned on in the source, the
# stored background data is ignored; the sources are restored afterwards.
# Flags (see DEMO in InstinctFaceView.mc): 1 outage, 4 HR, 5 RED, 7 AQI, 8 temp, 9 grid OK,
# 10 YEL, 11 OBL, T = demo outage schedule in the bar.
# Usage: tools\storeshots.ps1 [-Only name] [-Device id]   (A = always-on mode)   -> store\<device>-<name>.png (2x, with bezel)
param([string]$Only = "", [string]$Device = "")
$root = (Resolve-Path "$PSScriptRoot\..").Path
$bin = "$root\bin"; $out = "$root\store"
New-Item -ItemType Directory -Force $out | Out-Null
$env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName
$sdk = $null
$cfg = "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg"
if (Test-Path $cfg) { $sdk = (Get-Content $cfg).Trim().TrimEnd('\') }
if (-not $sdk -or -not (Test-Path "$sdk\bin\monkeyc.bat")) {
    $sdk = Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Sdks" -Directory -ErrorAction SilentlyContinue |
           Sort-Object Name | Select-Object -Last 1 | ForEach-Object { $_.FullName }
}
if (-not $sdk) { Write-Error "Connect IQ SDK not found (install it with the SDK Manager)"; exit 1 }
$env:PATH = "$sdk\bin;$env:JAVA_HOME\bin;$env:PATH"
Add-Type -AssemblyName System.Drawing

$cases = @(
    @{ n = "normal";  d = "instinct2";         f = "9,4,7,8,T" },
    @{ n = "outage";  d = "instinct2";         f = "1,4,7,8,T" },
    @{ n = "alert";   d = "instinct2";         f = "9,5,4,7,8,T" },
    @{ n = "normal";  d = "instinctcrossover"; f = "9,4,7,8,T" },
    @{ n = "yellow";  d = "instinctcrossover"; f = "9,10,4,7,8,T" },
    @{ n = "obl";     d = "instinctcrossover"; f = "9,11,4,7,8,T" },
    @{ n = "outage";  d = "instinctcrossover"; f = "1,4,7,8,T" },
    @{ n = "normal";  d = "instinctcrossoveramoled"; f = "9,4,7,8,T" },
    @{ n = "red";     d = "instinctcrossoveramoled"; f = "9,5,4,7,8,T" },
    @{ n = "outage";  d = "instinctcrossoveramoled"; f = "1,4,7,8,T" },
    @{ n = "aod";     d = "instinctcrossoveramoled"; f = "9,5,A" }      # always-on (not for the store)
)
# crop of the simulator window around the watch (screen + bezel), per device
$crop = @{ "instinct2" = @(90, 190, 220, 235); "instinctcrossover" = @(90, 215, 210, 210)
          "instinctcrossoveramoled" = @(85, 185, 540, 540) }   # AMOLED: 1x (the screen is already 390 px)

$view = "$root\source\InstinctFaceView.mc"
$v0 = [IO.File]::ReadAllText($view)
if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) { Start-Process "$sdk\bin\simulator.exe"; Start-Sleep 6 }
try {
    foreach ($c in $cases) {
        if ($Only -and $c.n -ne $Only) { continue }
        if ($Device -and $c.d -ne $Device) { continue }
        # empty stand-ins (not null: the type checker then flags the code after them)
        $v = $v0.Replace('Application.Storage.getValue("pwr")', '{}').
                 Replace('Application.Storage.getValue("al")', '[0, 0, 0, 0]').
                 Replace('Application.Storage.getValue("aq")', '[0, 0]')
        foreach ($f in $c.f.Split(",")) {
            if ($f -eq "T") { $v = $v.Replace("DEMO != 0", "true") }
            elseif ($f -eq "A") { $v = $v.Replace("if (!awake &&", "if (true &&").Replace('[0, 0, 0, 0]', '[3, 0, 200, 0]') }
            else { $v = [regex]::Replace($v, "DEMO == $f\b", "true") }
        }
        [IO.File]::WriteAllText($view, $v)
        $r = & cmd /c "monkeyc.bat -f `"$root\monkey.jungle`" -d $($c.d) -o `"$bin\shot.prg`" -y `"$env:USERPROFILE\ConnectIQ\developer_key.der`" 2>&1" | Select-Object -Last 1
        if ("$r" -notmatch "BUILD SUCCESSFUL") { "$($c.d)-$($c.n): $r"; continue }
        $stamp = Get-Date -Format "HHmmssfff"
        Start-Process cmd -ArgumentList "/c monkeydo.bat `"$bin\shot.prg`" $($c.d) > `"$bin\sim_shot_$stamp.log`" 2>&1" -WindowStyle Hidden -WorkingDirectory $root
        Start-Sleep 10
        powershell -NoProfile -File "$PSScriptRoot\shot.ps1" -Out "$bin\shot_raw.png" -MinHeight 900 | Out-Null
        $im = [Drawing.Bitmap]::FromFile("$bin\shot_raw.png")
        $k = $crop[$c.d]
        $cl = $im.Clone((New-Object Drawing.Rectangle($k[0], $k[1], $k[2], $k[3])), $im.PixelFormat)
        $zf = if ($c.d -like "*amoled") { 1 } else { 2 }
        $w = [int]$k[2] * $zf; $h = [int]$k[3] * $zf
        $z = New-Object Drawing.Bitmap($w, $h); $g = [Drawing.Graphics]::FromImage($z)
        $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'; $g.DrawImage($cl, 0, 0, $w, $h); $g.Dispose()
        $dst = if ($c.n -eq "aod") { $bin } else { $out }      # always-on test shot: not for the store
        $z.Save("$dst\$($c.d)-$($c.n).png"); $im.Dispose(); $cl.Dispose(); $z.Dispose()
        "$dst\$($c.d)-$($c.n).png"
    }
} finally {
    [IO.File]::WriteAllText($view, $v0)
}
