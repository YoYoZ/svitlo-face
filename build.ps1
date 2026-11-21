# Usage: .\build.ps1 [-Device instinct2] [-Run]
param([string]$Device = "instinct2", [switch]$Run)
$env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim().TrimEnd('\')
$key = "$env:USERPROFILE\ConnectIQ\developer_key.der"
New-Item -ItemType Directory -Force "$PSScriptRoot\bin" | Out-Null
$prg = "$PSScriptRoot\bin\InstinctFace.prg"
& "$sdk\bin\monkeyc.bat" -f "$PSScriptRoot\monkey.jungle" -d $Device -o $prg -y $key -w
if ($LASTEXITCODE -ne 0) { throw "build failed" }
"Built $prg"
if ($Run) {
    if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) { Start-Process "$sdk\bin\simulator.exe"; Start-Sleep 4 }
    & "$sdk\bin\monkeydo.bat" $prg $Device
}