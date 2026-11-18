# Fits a dented globe + camera to reference 3's traced target lines: every spoke must follow the
# globe's meridian direction and every ring its latitude direction, wherever they lie on screen.
param([string]$Start = '-2.2,0.5,-1.2,0.5,0,450,14,2,1.0', [string]$Steps = '0.4,0.3,0.3,0.4,6,60,3,0.6,0.25',
      [int]$Rounds = 40, [string]$Skip = '')
. "$PSScriptRoot\load.ps1"
. "$PSScriptRoot\ref3_lines.ps1"
$gf = New-Object 'Lab+GlobeFit'
$gf.P = [double[]]($Start.Split(','))
$id = 0
foreach ($k in $RefLines.Keys) {
    if ($Skip -and ($Skip.Split(',') -contains $k)) { $id++; $gf.RefNames.Add($k); continue }
    $gf.RefNames.Add($k)
    $p = $RefLines[$k].pts; $fam = if ($RefLines[$k].fam -eq 'spoke') { 0 } else { 1 }
    $P2 = for ($i = 0; $i -lt $p.Length; $i += 2) { ,@([double]$p[$i], [double]($p[$i + 1] * 720 / 712)) }
    # resample every ~14 px along the polyline, tangent from the segment
    for ($s = 0; $s -lt $P2.Count - 1; $s++) {
        $a = $P2[$s]; $b = $P2[$s + 1]; $dx = $b[0] - $a[0]; $dy = $b[1] - $a[1]; $l = [Math]::Sqrt($dx * $dx + $dy * $dy)
        $m = [Math]::Max(1, [int]($l / 14))
        for ($t = 0; $t -lt $m; $t++) { $gf.RefPts.Add([double[]]@(($a[0] + $dx * $t / $m), ($a[1] + $dy * $t / $m), ($dx / $l), ($dy / $l), $fam, $id)) }
    }
    $id++
}
"{0} reference samples" -f $gf.RefPts.Count
$gf.Fit([double[]]($Steps.Split(",")), $Rounds)
"--- where each traced line lies on the globe ---"
$gf.Places()
