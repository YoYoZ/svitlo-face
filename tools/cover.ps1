# Store cover image (500x500, < 300 KB): the Instinct 2 screenshot on the hero background
$root = (Resolve-Path "$PSScriptRoot\..").Path
$st = "$root\store"
Add-Type -AssemblyName System.Drawing
$S = 500
$b = New-Object Drawing.Bitmap($S, $S)
$g = [Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
$g.Clear([Drawing.Color]::FromArgb(14, 14, 14))
# watch: the 440x470 crop scaled to 0.92, cut as a rounded rectangle
$im = [Drawing.Image]::FromFile("$st\instinct2-normal.png")
$k = 0.92; $w = 400 * $k; $h = 430 * $k; $cx = $S / 2; $cy = $S / 2 - 14
$tb = New-Object Drawing.TextureBrush($im)
$tb.ScaleTransform($k, $k, [Drawing.Drawing2D.MatrixOrder]::Append)
$tb.TranslateTransform($cx - $im.Width * $k / 2, $cy - $im.Height * $k / 2, [Drawing.Drawing2D.MatrixOrder]::Append)
$x0 = [single]($cx - $w / 2); $y0 = [single]($cy - $h / 2); $d = [single](2 * 64 * $k)
$p = New-Object Drawing.Drawing2D.GraphicsPath
$p.AddArc($x0, $y0, $d, $d, 180, 90); $p.AddArc($x0 + $w - $d, $y0, $d, $d, 270, 90)
$p.AddArc($x0 + $w - $d, $y0 + $h - $d, $d, $d, 0, 90); $p.AddArc($x0, $y0 + $h - $d, $d, $d, 90, 90)
$p.CloseFigure(); $g.FillPath($tb, $p)
# title strip
$f = New-Object Drawing.Font("Segoe UI Semibold", 30, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$t = "Svitlo Face"; $sz = $g.MeasureString($t, $f)
$g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 213, 0))), [single]($S / 2 - 24), 453, 48, 4)
$g.DrawString($t, $f, [Drawing.Brushes]::White, [single](($S - $sz.Width) / 2), 458)
$g.Dispose(); $im.Dispose()
$b.Save("$st\cover.png", [Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
"$st\cover.png  $([math]::Round((Get-Item "$st\cover.png").Length / 1KB)) KB"
