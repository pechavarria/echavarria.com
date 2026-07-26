# Generates assets/pattern.svg: a dense, organically scattered doodle tile.
#
# Placement is STRATIFIED: the tile is divided into cells and each cell gets one
# candidate at a random position inside it. That guarantees even coverage (plain
# dart-throwing leaves visible voids and clumps) while the intra-cell randomness,
# varied sizes and rotations keep it from reading as a grid.
#
# Spacing uses a toroidal metric, and anything overlapping an edge is emitted
# again shifted by one tile width/height. The viewBox clips the copy, so the
# repeat is seamless.

param(
  [int]$Seed = 20260726,
  [int]$Tile = 900,
  [int]$IconCols = 13,      # 13x13 = 169 icon candidates
  [int]$FillerCols = 26     # 26x26 = 676 filler candidates, thinned by $FillerKeep
)

$FillerKeep = 0.62

$defsPath = Join-Path $PSScriptRoot 'icons-defs.svg'
$outPath  = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\pattern.svg'

$icons = @(
  'soccer','basket','jersey','whistle','trophy',
  'nigiri','onigiri','maki','ramen','torii','fuji','chopsticks','sake',
  'pagoda','dumpling','lantern','panda',
  'eiffel','croissant','baguette','wine','arc',
  'pizza','colosseum','pisa','gondola','pasta','gelato',
  'paella','guitar','fan',
  'sailboat','lighthouse','waves',
  'longhorn','cowboyhat','boot','star','cactus',
  'pine','mountains','skis','balloon',
  'palm','bridge','surf',
  'plane','suitcase','camera','compass','globe','passport','map','backpack',
  'glasses','coffee','ticket','signpost','sun','cloud'
)
$fillers = @('f-dot','f-ring','f-star','f-spark','f-heart','f-tri','f-arc','f-plus','f-x','f-diamond')

# --- deterministic RNG (LCG) ---
$script:state = [uint32]$Seed
function Rnd {
  $script:state = [uint32](($script:state * 1103515245 + 12345) -band 0x7FFFFFFF)
  return $script:state / 2147483648.0
}
function RndRange([double]$a, [double]$b) { $a + (Rnd) * ($b - $a) }

function TorDist([double]$x1, [double]$y1, [double]$x2, [double]$y2) {
  $dx = [Math]::Abs($x1 - $x2); if ($dx -gt $Tile / 2) { $dx = $Tile - $dx }
  $dy = [Math]::Abs($y1 - $y2); if ($dy -gt $Tile / 2) { $dy = $Tile - $dy }
  return [Math]::Sqrt($dx * $dx + $dy * $dy)
}

$placed = New-Object System.Collections.ArrayList
$uses   = New-Object System.Collections.ArrayList

function TryCell([double]$cx0, [double]$cy0, [double]$cw, [double]$ch, [double]$size, [double]$crowd, [int]$tries) {
  $r = $size / 2
  for ($t = 0; $t -lt $tries; $t++) {
    $x = RndRange $cx0 ($cx0 + $cw)
    $y = RndRange $cy0 ($cy0 + $ch)
    $ok = $true
    foreach ($p in $placed) {
      if ((TorDist $x $y $p.X $p.Y) -lt (($r + $p.R) * $crowd)) { $ok = $false; break }
    }
    if ($ok) { return @{ X = $x; Y = $y; R = $r } }
  }
  return $null
}

# --- icons on a stratified grid, cell order shuffled so sizes don't sweep ---
$cells = @()
for ($r = 0; $r -lt $IconCols; $r++) { for ($c = 0; $c -lt $IconCols; $c++) { $cells += ,@($c, $r) } }
$cells = $cells | Sort-Object { Rnd }

# ArrayList, not array slicing: $arr[1..0] on a 1-element array yields
# ($null, item) in PowerShell, which silently jams the bag on one icon.
$bag = New-Object System.Collections.ArrayList
$iconPlaced = 0
$cw = $Tile / $IconCols

foreach ($cell in $cells) {
  if ($bag.Count -eq 0) { foreach ($i in ($icons | Sort-Object { Rnd })) { [void]$bag.Add($i) } }
  $name = $bag[0]; $bag.RemoveAt(0)

  $roll = Rnd
  if ($roll -lt 0.16)     { $size = RndRange 54 68 }
  elseif ($roll -lt 0.60) { $size = RndRange 42 54 }
  else                    { $size = RndRange 32 42 }

  $spot = TryCell ($cell[0] * $cw) ($cell[1] * $cw) $cw $cw $size 0.52 24
  if (-not $spot) { continue }
  $spot.Name = $name
  $spot.Size = $size
  $spot.Rot  = RndRange -24 24
  [void]$placed.Add($spot); [void]$uses.Add($spot)
  $iconPlaced++
}

# --- fillers on a finer stratified grid, thinned at random ---
$fcells = @()
for ($r = 0; $r -lt $FillerCols; $r++) { for ($c = 0; $c -lt $FillerCols; $c++) { $fcells += ,@($c, $r) } }
$fcells = $fcells | Sort-Object { Rnd }
$fw = $Tile / $FillerCols
$fillerPlaced = 0

foreach ($cell in $fcells) {
  if ((Rnd) -gt $FillerKeep) { continue }
  $roll = Rnd
  if ($roll -lt 0.45)     { $size = RndRange 8 13 }
  elseif ($roll -lt 0.80) { $size = RndRange 13 19 }
  else                    { $size = RndRange 19 26 }

  $spot = TryCell ($cell[0] * $fw) ($cell[1] * $fw) $fw $fw $size 0.80 16
  if (-not $spot) { continue }
  $spot.Name = $fillers[[int][Math]::Floor((Rnd) * $fillers.Count) % $fillers.Count]
  $spot.Size = $size
  $spot.Rot  = RndRange -45 45
  [void]$placed.Add($spot); [void]$uses.Add($spot)
  $fillerPlaced++
}

# --- emit, wrapping anything that overlaps an edge ---
$lines = New-Object System.Collections.ArrayList
$copies = 0
foreach ($u in $uses) {
  $s = [Math]::Round($u.Size / 100.0, 3)
  $reach = $u.Size * 0.75
  foreach ($dx in -$Tile, 0, $Tile) {
    foreach ($dy in -$Tile, 0, $Tile) {
      $x = $u.X + $dx; $y = $u.Y + $dy
      if ($x -lt -$reach -or $x -gt $Tile + $reach) { continue }
      if ($y -lt -$reach -or $y -gt $Tile + $reach) { continue }
      $xs = [Math]::Round($x, 1); $ys = [Math]::Round($y, 1); $rs = [Math]::Round($u.Rot, 1)
      [void]$lines.Add("    <use href=""#$($u.Name)"" transform=""translate($xs $ys) rotate($rs) scale($s) translate(-50 -50)""/>")
      if ($dx -ne 0 -or $dy -ne 0) { $copies++ }
    }
  }
}

$defs = Get-Content $defsPath -Raw

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$Tile" height="$Tile" viewBox="0 0 $Tile $Tile">
  <!--
    GENERATED FILE - do not hand-edit.
    Rebuild with scratchpad/gen-pattern.ps1 (seed $Seed).

    Doodle tile for the login background: $iconPlaced icons + $fillerPlaced filler marks,
    stratified-scattered with toroidal spacing so the tile repeats without a seam.
    Icons cover the family's travels (Texas, Oregon, California, Colorado,
    France, Japan, China, Italy, Croatia, Spain), soccer, basketball, and food.
  -->
  <defs>
$defs
  </defs>

  <g fill="none" stroke="#101828" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
$($lines -join "`n")
  </g>
</svg>
"@

Set-Content -Path $outPath -Value $svg -Encoding utf8
"icons:    $iconPlaced / $($IconCols * $IconCols) cells"
"fillers:  $fillerPlaced / $($FillerCols * $FillerCols) cells"
"wrapped:  $copies"
"elements: $($lines.Count)"
"size:     $([Math]::Round((Get-Item $outPath).Length/1KB,1)) KB"

