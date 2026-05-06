$path = 'c:\7 semester\flutter 2\lib\screens\homescreen.dart'
$content = Get-Content $path -Raw
$content = $content.Replace("letterSpacing: -0.5, ", "")
$content = $content.Replace("letterSpacing: -1.5, ", "")
Set-Content -Path $path -Value $content -Encoding utf8
