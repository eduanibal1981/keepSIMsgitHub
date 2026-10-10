Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$sourceDirectory = Join-Path $projectRoot 'android/app/src/main/res/drawable-xxxhdpi'
$before = [System.Drawing.Bitmap]::new((Join-Path $PSScriptRoot 'before-foreground.png'))
$after = [System.Drawing.Bitmap]::new((Join-Path $sourceDirectory 'ic_launcher_foreground.png'))
$config = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'pubspec.yaml'))
$inset = [double]([regex]::Match($config, 'adaptive_icon_foreground_inset:\s*(\d+)').Groups[1].Value) / 100
$navy = [System.Drawing.ColorTranslator]::FromHtml('#0A295A')

function Icon-Shape([string]$kind, [single]$size) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    if ($kind -eq 'Circle') { $path.AddEllipse(0, 0, $size, $size) }
    elseif ($kind -eq 'Squircle') {
        $points = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        for ($step = 0; $step -lt 180; $step++) {
            $angle = 2 * [Math]::PI * $step / 180
            $cosine = [Math]::Cos($angle)
            $sine = [Math]::Sin($angle)
            $xPoint = $size / 2 + $size / 2 * [Math]::Sign($cosine) * [Math]::Sqrt([Math]::Abs($cosine))
            $yPoint = $size / 2 + $size / 2 * [Math]::Sign($sine) * [Math]::Sqrt([Math]::Abs($sine))
            $points.Add([System.Drawing.PointF]::new($xPoint, $yPoint))
        }
        $path.AddPolygon($points.ToArray())
    } else {
        $diameter = $size * 0.42
        $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
        $path.AddArc($size - $diameter, 0, $diameter, $diameter, 270, 90)
        $path.AddArc($size - $diameter, $size - $diameter, $diameter, $diameter, 0, 90)
        $path.AddArc(0, $size - $diameter, $diameter, $diameter, 90, 90)
        $path.CloseFigure()
    }
    return $path
}

function Draw-Icon($graphics, $source, [double]$padding, [string]$shape, [single]$x, [single]$y, [single]$size, $background) {
    $state = $graphics.Save()
    $graphics.TranslateTransform($x, $y)
    $mask = Icon-Shape $shape $size
    $graphics.SetClip($mask)
    $brush = [System.Drawing.SolidBrush]::new($background)
    $graphics.FillRectangle($brush, 0, 0, $size, $size)
    # AdaptiveIconDrawable expands 108dp layers around its central 72dp viewport.
    $fullLayer = $size * 1.5
    $foregroundSize = $fullLayer * (1 - 2 * $padding)
    $offset = ($size - $foregroundSize) / 2
    $graphics.DrawImage($source, [System.Drawing.RectangleF]::new($offset, $offset, $foregroundSize, $foregroundSize))
    $graphics.Restore($state)
    $mask.Dispose()
    $brush.Dispose()
}

$sheet = [System.Drawing.Bitmap]::new(680, 480)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F3F6FA'))
$dark = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#142D4C'))
$muted = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#566A80'))
$heading = [System.Drawing.Font]::new('Segoe UI', 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$label = [System.Drawing.Font]::new('Segoe UI', 17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$small = [System.Drawing.Font]::new('Segoe UI', 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$centered = [System.Drawing.StringFormat]::new()
$centered.Alignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString('KeepSIMs', $heading, $dark, 30, 23)
$graphics.DrawString('Full logo. Clear checkmark. Better fit.', $label, $muted, 30, 62)
Draw-Icon $graphics $before 0 'Squircle' 118 106 136 ([System.Drawing.ColorTranslator]::FromHtml('#0D0E12'))
Draw-Icon $graphics $after $inset 'Squircle' 426 106 136 $navy
$graphics.DrawString('Before', $label, $muted, [System.Drawing.RectangleF]::new(90, 258, 192, 28), $centered)
$graphics.DrawString('Updated', $label, $dark, [System.Drawing.RectangleF]::new(398, 258, 192, 28), $centered)
$graphics.DrawLine([System.Drawing.Pens]::LightGray, 30, 307, 650, 307)
$shapes = @('Circle', 'Squircle', 'Rounded square')
for ($shapeIndex = 0; $shapeIndex -lt $shapes.Length; $shapeIndex++) {
    $shapeX = 128 + 176 * $shapeIndex
    Draw-Icon $graphics $after $inset $shapes[$shapeIndex] $shapeX 334 72 $navy
    $graphics.DrawString($shapes[$shapeIndex], $small, $muted, [System.Drawing.RectangleF]::new($shapeX - 40, 420, 152, 23), $centered)
}
$sheet.Save((Join-Path $PSScriptRoot 'preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$before.Dispose()
$after.Dispose()
$graphics.Dispose()
$sheet.Dispose()
$heading.Dispose()
$label.Dispose()
$small.Dispose()
$dark.Dispose()
$muted.Dispose()
$centered.Dispose()
Write-Output 'Saved launcher comparison and shape previews.'
