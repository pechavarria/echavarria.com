# Generates assets/pattern.svg: a dense doodle tile in the style of a
# messaging-app chat wallpaper.
#
# Placement rules that matter for the look:
#   1. NO OVERLAP. Every item reserves a circle of radius size*0.55 and must
#      clear every other item by a 4% margin. (An earlier version used a
#      "crowd" factor below 1.0, which mathematically guaranteed collisions.)
#   2. WIDE SIZE SPREAD. Three icon classes from 26 to 96 units - a ~3.7x
#      range - instead of one narrow band, so the eye reads variety.
#   3. LARGEST FIRST. Big shapes claim space before small ones, then smaller
#      items pack into the leftovers. Small-first would fragment the tile and
#      leave no room for anything large.
#   4. STRATIFIED CANDIDATES. Each class draws from its own grid of cells, one
#      candidate per cell at a random position inside it, so coverage stays
#      even without the positions reading as a grid.
#   5. SEAMLESS. Spacing uses a toroidal metric and anything overlapping an
#      edge is emitted again one tile over; the viewBox clips it.

param(
  [int]$Seed = 91127,
  [int]$Tile = 900
)

$outPath  = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\pattern.svg'
$defsPath = Join-Path $PSScriptRoot 'icons-defs.svg'

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

# kind, target count, min size, max size, candidate grid, tries per cell
$classes = @(
  @{ Kind = 'icon';   Count = 15;  Min = 74; Max = 96; Grid = 4;  Tries = 90 },
  @{ Kind = 'icon';   Count = 52;  Min = 50; Max = 70; Grid = 8;  Tries = 70 },
  @{ Kind = 'icon';   Count = 104; Min = 26; Max = 46; Grid = 11; Tries = 50 },
  @{ Kind = 'filler'; Count = 250; Min = 9;  Max = 26; Grid = 18; Tries = 40 }
)

# --- deterministic RNG ---
$script:state = [uint32]$Seed
function Rnd {
  $script:state = [uint32](($script:state * 1103515245 + 12345) -band 0x7FFFFFFF)
  return $script:state / 2147483648.0
}
function RndRange([double]$a, [double]$b) { $a + (Rnd) * ($b - $a) }

# --- flat parallel arrays: fast enough for the O(n^2) proximity test ---
$cap = 700
$px = New-Object 'double[]' $cap
$py = New-Object 'double[]' $cap
$pr = New-Object 'double[]' $cap
$pn = New-Object 'string[]' $cap
$ps = New-Object 'double[]' $cap
$pt = New-Object 'double[]' $cap
$n  = 0

$half = $Tile / 2.0
$margin = 1.04

$bag = New-Object System.Collections.ArrayList
$iconTotal = 0
$fillTotal = 0

foreach ($cls in $classes) {
  $grid = $cls.Grid
  $cw = $Tile / $grid

  # shuffled cell order, so size draws don't sweep across the tile
  $cells = @()
  for ($r = 0; $r -lt $grid; $r++) { for ($c = 0; $c -lt $grid; $c++) { $cells += ,@($c, $r) } }
  $cells = $cells | Sort-Object { Rnd }

  $want = $cls.Count
  $got = 0

  foreach ($cell in $cells) {
    if ($got -ge $want) { break }

    $size = RndRange $cls.Min $cls.Max
    $r = $size * 0.55
    $ox = $cell[0] * $cw
    $oy = $cell[1] * $cw

    for ($t = 0; $t -lt $cls.Tries; $t++) {
      $x = $ox + (Rnd) * $cw
      $y = $oy + (Rnd) * $cw
      $ok = $true
      for ($i = 0; $i -lt $n; $i++) {
        $sum = $r + $pr[$i]
        $dx = [Math]::Abs($x - $px[$i]); if ($dx -gt $half) { $dx = $Tile - $dx }
        if ($dx -gt $sum * $margin) { continue }
        $dy = [Math]::Abs($y - $py[$i]); if ($dy -gt $half) { $dy = $Tile - $dy }
        if ($dy -gt $sum * $margin) { continue }
        $need = $sum * $margin
        if (($dx * $dx + $dy * $dy) -lt ($need * $need)) { $ok = $false; break }
      }
      if (-not $ok) { continue }

      if ($cls.Kind -eq 'icon') {
        if ($bag.Count -eq 0) { foreach ($ic in ($icons | Sort-Object { Rnd })) { [void]$bag.Add($ic) } }
        $name = $bag[0]; $bag.RemoveAt(0)
        $iconTotal++
      } else {
        $name = $fillers[[int][Math]::Floor((Rnd) * $fillers.Count) % $fillers.Count]
        $fillTotal++
      }

      $px[$n] = $x; $py[$n] = $y; $pr[$n] = $r
      $pn[$n] = $name; $ps[$n] = $size; $pt[$n] = RndRange -22 22
      $n++
      $got++
      break
    }
  }
  "  {0,-6} {1,2}-{2,2}px  placed {3}/{4}" -f $cls.Kind, $cls.Min, $cls.Max, $got, $want
}

# --- emit with wrap copies ---
$lines = New-Object System.Collections.ArrayList
$copies = 0
for ($i = 0; $i -lt $n; $i++) {
  $s = [Math]::Round($ps[$i] / 100.0, 3)
  $reach = $ps[$i] * 0.75
  foreach ($dx in -$Tile, 0, $Tile) {
    foreach ($dy in -$Tile, 0, $Tile) {
      $x = $px[$i] + $dx; $y = $py[$i] + $dy
      if ($x -lt -$reach -or $x -gt $Tile + $reach) { continue }
      if ($y -lt -$reach -or $y -gt $Tile + $reach) { continue }
      $xs = [Math]::Round($x, 1); $ys = [Math]::Round($y, 1); $rs = [Math]::Round($pt[$i], 1)
      [void]$lines.Add("    <use href=""#$($pn[$i])"" transform=""translate($xs $ys) rotate($rs) scale($s) translate(-50 -50)""/>")
      if ($dx -ne 0 -or $dy -ne 0) { $copies++ }
    }
  }
}

$defs = Get-Content $defsPath -Raw

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$Tile" height="$Tile" viewBox="0 0 $Tile $Tile">
  <!--
    GENERATED FILE - do not hand-edit.
    Rebuild with tools/gen-pattern.ps1 (seed $Seed).

    Doodle tile for the login background: $iconTotal icons + $fillTotal filler marks,
    packed largest-first with a strict no-overlap constraint across size classes
    spanning 26-96 units. Toroidal spacing plus edge wrapping makes the tile
    repeat seamlessly. Icons cover the family's travels (Texas, Oregon,
    California, Colorado, France, Japan, China, Italy, Croatia, Spain),
    soccer, basketball, and a lot of food.
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
"icons:    $iconTotal"
"fillers:  $fillTotal"
"wrapped:  $copies"
"elements: $($lines.Count)"
"size:     $([Math]::Round((Get-Item $outPath).Length/1KB,1)) KB"
