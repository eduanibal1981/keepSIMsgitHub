Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$resourceRoot = Join-Path $projectRoot 'android/app/src/main/res'
$logoDirectory = Join-Path $resourceRoot 'drawable-nodpi'
New-Item -ItemType Directory -Force -Path $logoDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/images/Logo.png') -Destination (Join-Path $logoDirectory 'splash_logo.png')

# Outlined letters render identically without depending on Android fonts.
$fontFamily = [System.Drawing.FontFamily]::new('Segoe UI')
$keepPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$simsPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$fontStyle = [int][System.Drawing.FontStyle]::Bold
$textFormat = [System.Drawing.StringFormat]::GenericTypographic
$keepPath.AddString('Keep', $fontFamily, $fontStyle, 32, [System.Drawing.PointF]::new(0, 0), $textFormat)
$keepBounds = $keepPath.GetBounds()
$simsPath.AddString('SIMs', $fontFamily, $fontStyle, 32, [System.Drawing.PointF]::new($keepBounds.Right + 1, 0), $textFormat)
$combinedBounds = [System.Drawing.RectangleF]::Union($keepBounds, $simsPath.GetBounds())
$translation = [System.Drawing.Drawing2D.Matrix]::new()
$translation.Translate((200 - $combinedBounds.Width) / 2 - $combinedBounds.X, 32 - $combinedBounds.Y)
$keepPath.Transform($translation)
$simsPath.Transform($translation)

function ConvertTo-PathData([System.Drawing.Drawing2D.GraphicsPath]$graphicPath) {
    $points = $graphicPath.PathPoints
    $types = $graphicPath.PathTypes
    $data = [System.Text.StringBuilder]::new()
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    function Point-String($point) { return $point.X.ToString('0.###', $culture) + ',' + $point.Y.ToString('0.###', $culture) }
    for ($pointIndex = 0; $pointIndex -lt $points.Length; $pointIndex++) {
        $pointType = $types[$pointIndex] -band 7
        if ($pointType -eq 0) { [void]$data.Append('M' + (Point-String $points[$pointIndex])) }
        elseif ($pointType -eq 1) { [void]$data.Append('L' + (Point-String $points[$pointIndex])) }
        elseif ($pointType -eq 3) {
            [void]$data.Append('C' + (Point-String $points[$pointIndex]) + ' ' + (Point-String $points[$pointIndex + 1]) + ' ' + (Point-String $points[$pointIndex + 2]))
            $pointIndex += 2
        }
        if (($types[$pointIndex] -band 128) -ne 0) { [void]$data.Append('Z') }
    }
    return $data.ToString()
}
$keepData = ConvertTo-PathData $keepPath
$simsData = ConvertTo-PathData $simsPath
$brandingXml = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- Brand name converted to vector outlines for consistent native rendering. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="200dp" android:height="80dp"
    android:viewportWidth="200" android:viewportHeight="80">
    <path android:fillColor="#FFFFFF" android:pathData="$keepData" />
    <path android:fillColor="#4EDEA3" android:pathData="$simsData" />
</vector>
"@
[System.IO.File]::WriteAllText((Join-Path $resourceRoot 'drawable/splash_branding.xml'), $brandingXml, [System.Text.UTF8Encoding]::new($false))
$brandingSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="80" viewBox="0 0 200 80">
  <path fill="#FFFFFF" d="$keepData"/>
  <path fill="#4EDEA3" d="$simsData"/>
</svg>
"@
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'wordmark.svg'), $brandingSvg, [System.Text.UTF8Encoding]::new($false))

# Illustrative preview using the same dp sizes, color, and outlined wordmark.
$screen = [System.Drawing.Bitmap]::new(1170, 2532)
$graphics = [System.Drawing.Graphics]::FromImage($screen)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.ScaleTransform(3, 3)
$navy = [System.Drawing.ColorTranslator]::FromHtml('#0A295A')
$green = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#4EDEA3'))
$graphics.Clear($navy)
$logo = [System.Drawing.Image]::FromFile((Join-Path $logoDirectory 'splash_logo.png'))
$graphics.DrawImage($logo, [System.Drawing.RectangleF]::new(131, 353, 128, 138))
$graphics.TranslateTransform(95, 716)
$graphics.FillPath([System.Drawing.Brushes]::White, $keepPath)
$graphics.FillPath($green, $simsPath)
$graphics.ResetTransform()
$graphics.ScaleTransform(3, 3)
$statusFont = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.DrawString('9:41', $statusFont, [System.Drawing.Brushes]::White, 20, 12)
$signalPen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 1.7)
$graphics.DrawLine($signalPen, 326, 23, 326, 20)
$graphics.DrawLine($signalPen, 330, 23, 330, 17)
$graphics.DrawLine($signalPen, 334, 23, 334, 14)
$graphics.DrawRectangle($signalPen, 350, 14, 19, 9)
$graphics.FillRectangle([System.Drawing.Brushes]::White, 353, 17, 13, 3)
$graphics.FillRectangle([System.Drawing.Brushes]::White, 371, 17, 2, 3)
$homePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(210, 255, 255, 255), 4)
$homePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$homePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($homePen, 145, 829, 245, 829)
$screen.Save((Join-Path $PSScriptRoot 'preview@3x.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$smallPreview = [System.Drawing.Bitmap]::new(390, 844)
$smallGraphics = [System.Drawing.Graphics]::FromImage($smallPreview)
$smallGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$smallGraphics.DrawImage($screen, 0, 0, 390, 844)
$smallPreview.Save((Join-Path $PSScriptRoot 'preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$smallGraphics.Dispose()
$smallPreview.Dispose()

$logo.Dispose()
$graphics.Dispose()
$screen.Dispose()
$statusFont.Dispose()
$signalPen.Dispose()
$homePen.Dispose()
$green.Dispose()
$translation.Dispose()
$keepPath.Dispose()
$simsPath.Dispose()
$fontFamily.Dispose()
Write-Output 'Saved Android splash assets and output/splash/preview.png.'
