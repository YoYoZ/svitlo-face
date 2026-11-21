param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\resources\drawables\launcher_icon.png")
)

Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap(40, 40)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::Black)
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$font = New-Object System.Drawing.Font("Arial", 17, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString("IF", $font, $brush, (New-Object System.Drawing.RectangleF(0, 0, 40, 40)), $format)
$bitmap.Save([System.IO.Path]::GetFullPath($OutputPath), [System.Drawing.Imaging.ImageFormat]::Png)
$format.Dispose()
$brush.Dispose()
$font.Dispose()
$graphics.Dispose()
$bitmap.Dispose()
