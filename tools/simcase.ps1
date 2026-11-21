# Test helper: build a throwaway variant with preset settings, run it in the simulator with
# the background fetch fired right away, screenshot, restore the sources.
# Usage: tools\simcase.ps1 -Name empty -Provider 0 -Queue "" -Sb "" -Place 0 [-Wait 25]
param([string]$Name, [int]$Provider = 0, [string]$Queue = "", [string]$Sb = "", [int]$Place = 0, [int]$Wait = 25)
$root = (Resolve-Path "$PSScriptRoot\..").Path
$bin = "$root\bin"
$env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim().TrimEnd('\')
$env:PATH = "$sdk\bin;$env:JAVA_HOME\bin;$env:PATH"

$props = "$root\resources\settings\properties.xml"; $app = "$root\source\InstinctFaceApp.mc"
$p0 = [IO.File]::ReadAllText($props); $a0 = [IO.File]::ReadAllText($app)
try {
    $p = $p0.Replace('<property id="Provider" type="number">0<', "<property id=`"Provider`" type=`"number`">$Provider<").
             Replace('<property id="Queue" type="string"><', "<property id=`"Queue`" type=`"string`">$Queue<").
             Replace('<property id="SvitloBot" type="string"><', "<property id=`"SvitloBot`" type=`"string`">$Sb<").
             Replace('<property id="AlertPlace" type="number">0<', "<property id=`"AlertPlace`" type=`"number`">$Place<")
    [IO.File]::WriteAllText($props, $p)
    [IO.File]::WriteAllText($app, $a0.Replace("Background.registerForTemporalEvent(new Time.Duration(5 * 60));", "var l = Background.getLastTemporalEventTime(); var w = l == null ? Time.now() : l.add(new Time.Duration(5 * 60 + 2)); if (w.lessThan(Time.now())) { w = Time.now(); } Background.registerForTemporalEvent(w);"))
    & cmd /c "monkeyc.bat -f `"$root\monkey.jungle`" -d instinct2 -o `"$bin\test.prg`" -y `"$env:USERPROFILE\ConnectIQ\developer_key.der`" 2>&1" | Select-Object -Last 1
} finally {
    [IO.File]::WriteAllText($props, $p0); [IO.File]::WriteAllText($app, $a0)
}
# fresh simulator (it remembers the last background run: < 5 min ago -> registration throws)
Get-Process simulator -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Start-Process "$sdk\bin\simulator.exe"; Start-Sleep 6
# fresh simulator state for this app (settings + storage)
Get-ChildItem "$env:TEMP\com.garmin.connectiq\GARMIN\APPS" -Recurse -Filter "TEST.*" -ErrorAction SilentlyContinue | Remove-Item -Force
$log = "$bin\sim_$Name.log"
Start-Process cmd -ArgumentList "/c monkeydo.bat `"$bin\test.prg`" instinct2 > `"$log`" 2>&1" -WindowStyle Hidden -WorkingDirectory $root
Start-Sleep $Wait
powershell -NoProfile -File "$PSScriptRoot\shot.ps1" -Out "$bin\case_$Name.png" | Out-Null
Add-Type -AssemblyName System.Drawing
$im = [Drawing.Bitmap]::FromFile("$bin\case_$Name.png")
$c = $im.Clone((New-Object Drawing.Rectangle(100, 200, 200, 215)), $im.PixelFormat)
$z = New-Object Drawing.Bitmap(400, 430); $g = [Drawing.Graphics]::FromImage($z)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'; $g.DrawImage($c, 0, 0, 400, 430); $g.Dispose()
$z.Save("$bin\case_${Name}_z.png"); $im.Dispose()
Get-Content $log -ErrorAction SilentlyContinue | Select-String "alerts:|Error|error" | Select-Object -Last 5
"$bin\case_${Name}_z.png"
