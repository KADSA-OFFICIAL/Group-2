param(
 [string]$Unit,
 [ValidateSet('characters','enemies')][string]$Side='characters',
 [string]$OutputDirectory
)
Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path -Parent $PSScriptRoot
if (!$OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'art/battle-animation/review' }
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$sheet = [System.Drawing.Bitmap]::new(1120,1560)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$font = [System.Drawing.Font]::new('Segoe UI',13)
try {
 $graphics.Clear([System.Drawing.Color]::FromArgb(25,32,47))
 $row=0
 foreach ($animation in @('idle','attack','hit','death')) {
  $count=if($animation -eq 'hit'){2}else{4}
  for($n=0;$n -lt $count;$n++) {
   $path=Join-Path $repoRoot ("assets/sprites/$Side/battle/frames/$Unit/"+$animation+"_"+$n+".png")
   $graphics.DrawString(($animation+'_'+$n),$font,[System.Drawing.Brushes]::White,($n*280+12),($row*390+10))
   if(Test-Path -LiteralPath $path) {
    $picture=[System.Drawing.Image]::FromFile($path)
    try { $graphics.DrawImageUnscaled($picture,($n*280+12),($row*390+42)) } finally { $picture.Dispose() }
   } else { $graphics.DrawString('PENDING',$font,[System.Drawing.Brushes]::Orange,($n*280+12),($row*390+180)) }
  }
  $row++
 }
 $sheet.Save((Join-Path $OutputDirectory ($Unit+'-frames.png')))
} finally { $graphics.Dispose();$sheet.Dispose();$font.Dispose() }
