# Store hero image (1440x720): title + two watch screenshots from store\ (run storeshots.ps1 first)
$root = (Resolve-Path "$PSScriptRoot\..").Path
$st = "$root\store"
Add-Type -AssemblyName System.Drawing
$W = 1440; $H = 720
$b = New-Object Drawing.Bitmap($W, $H)
$g = [Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$g.Clear([Drawing.Color]::FromArgb(14, 14, 14))

# a watch screenshot, cut round with a soft edge (the crops have square simulator corners)
# round = circle of width w (Crossover); else a rounded rectangle w x h (Instinct's octagon-ish screen)
function Watch($file, $cx, $cy, $w, $h, $r) {
    $im = [Drawing.Image]::FromFile($file)
    $tb = New-Object Drawing.TextureBrush($im)
    $tb.TranslateTransform($cx - $im.Width / 2, $cy - $im.Height / 2)
    $x0 = [single]($cx - $w / 2); $y0 = [single]($cy - $h / 2)
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    if ($r -ge $w / 2) { $p.AddEllipse($x0, $y0, [single]$w, [single]$h) }
    else {
        $d = 2 * $r
        $p.AddArc($x0, $y0, $d, $d, 180, 90); $p.AddArc($x0 + $w - $d, $y0, $d, $d, 270, 90)
        $p.AddArc($x0 + $w - $d, $y0 + $h - $d, $d, $d, 0, 90); $p.AddArc($x0, $y0 + $h - $d, $d, $d, 90, 90)
        $p.CloseFigure()
    }
    $g.FillPath($tb, $p)
    $p.Dispose(); $tb.Dispose(); $im.Dispose()
}
Watch "$st\instinct2-normal.png" 760 372 420 450 70
Watch "$st\instinctcrossover-yellow.png" 1205 372 410 410 205

$white = [Drawing.Brushes]::White
$grey = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(170, 170, 170))
$accent = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 213, 0))   # Ukrainian yellow
$f1 = New-Object Drawing.Font("Segoe UI Semibold", 64, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$f2 = New-Object Drawing.Font("Segoe UI", 28, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$f3 = New-Object Drawing.Font("Segoe UI", 20, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$x = 64
$g.FillRectangle($accent, $x, 214, 56, 6)
$g.DrawString("Svitlo Face", $f1, $white, $x - 4, 232)
$g.DrawString("Світло, графіки і тривоги", $f2, $white, $x, 324)
$g.DrawString("на вашому Instinct", $f2, $white, $x, 362)
$g.DrawString("Power outages, schedules and", $f3, $grey, $x, 428)
$g.DrawString("air-raid alerts on your wrist", $f3, $grey, $x, 456)
$g.DrawString("Instinct 2 · 2X · 3 · E · Crossover", $f3, $grey, $x, 520)

$g.Dispose()
$b.Save("$st\hero.png", [Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
"$st\hero.png  $([math]::Round((Get-Item "$st\hero.png").Length / 1KB)) KB"
