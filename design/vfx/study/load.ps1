# Compiles ImgLab.cs and Sketch.cs once per change (cached by hash in %TEMP%) and loads them.
# Use from a job script:  . "$PSScriptRoot\load.ps1"   then  [Lab]::Stats(...), [Img]::Load(...), [Sk]::Stroke(...)
$labSrc = @((Join-Path $PSScriptRoot 'ImgLab.cs'), (Join-Path $PSScriptRoot 'Sketch.cs'), (Join-Path $PSScriptRoot 'Pencil.cs'), (Join-Path $PSScriptRoot '..\impact\Plunge.cs'))
$labHash = (($labSrc | ForEach-Object { (Get-FileHash $_ -Algorithm SHA1).Hash.Substring(0, 8) }) -join '')
$labCache = Join-Path $env:TEMP 'imglab'
New-Item -ItemType Directory -Force $labCache | Out-Null
$labDll = Join-Path $labCache "ImgLab_$labHash.dll"
if (-not (Test-Path $labDll)) {
    Add-Type -Path $labSrc -ReferencedAssemblies System.Drawing -OutputAssembly $labDll -OutputType Library
}
Add-Type -Path $labDll
Add-Type -AssemblyName System.Drawing
