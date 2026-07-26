# Generates assets/pattern.svg: a dense doodle tile in the style of a
# messaging-app chat wallpaper.
#
# Placement rules that matter for the look:
#   1. NO OVERLAP. Every item reserves a circle and must clear every neighbour.
#      The radius factor is 0.46 of the nominal size, not 0.5+: the icons are
#      drawn to span roughly 80 of their 100-unit box, so reserving half the box
#      wasted ~35% of the packable area and capped density.
#   2. WIDE SIZE SPREAD. Five classes from 22 to 128 units - a ~5.8x range - so
#      big anchors and fine detail coexist.
#   3. LARGEST FIRST. Big shapes claim space before small ones, then smaller
#      items pack into the leftovers. Small-first fragments the tile and leaves
#      no room for anything large.
#   4. STRATIFIED CANDIDATES. Each class draws from its own grid of cells, one
#      candidate per cell at a random position inside it, so coverage stays even
#      without the positions reading as a grid.
#   5. SPATIAL HASH. Proximity tests consult a 3x3 bucket neighbourhood instead
#      of every placed item, which is what makes hundreds of attempts per slot
#      affordable and therefore makes tight packing reachable.
#   6. SEAMLESS. Spacing uses a toroidal metric and anything overlapping an edge
#      is emitted again one tile over; the viewBox clips it.

param(
  [int]$Seed = 4471,
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
  @{ Kind = 'icon';   Count = 7;   Min = 102; Max = 128; Grid = 3;  Tries = 400 },
  @{ Kind = 'icon';   Count = 24;  Min = 72;  Max = 100; Grid = 6;  Tries = 300 },
  @{ Kind = 'icon';   Count = 84;  Min = 46;  Max = 70;  Grid = 10; Tries = 220 },
  @{ Kind = 'icon';   Count = 170; Min = 24;  Max = 44;  Grid = 15; Tries = 160 },
  @{ Kind = 'filler'; Count = 340; Min = 8;   Max = 22;  Grid = 21; Tries = 120 }
)

$RadiusFactor = 0.46
$Margin = 1.02

# --- deterministic RNG ---
$script:state = [uint32]$Seed
function Rnd {
  $script:state = [uint32](($script:state * 1103515245 + 12345) -band 0x7FFFFFFF)
  return $script:state / 2147483648.0
}
function RndRange([double]$a, [double]$b) { $a + (Rnd) * ($b - $a) }

# --- storage ---
$cap = 1200
$px = New-Object 'double[]' $cap
$py = New-Object 'double[]' $cap
$pr = New-Object 'double[]' $cap
$pn = New-Object 'string[]' $cap
$ps = New-Object 'double[]' $cap
$pt = New-Object 'double[]' $cap
$n  = 0

# --- spatial hash. Cell must exceed the largest possible radius sum. ---
$maxR = 128 * $RadiusFactor
$gridN = [int][Math]::Floor($Tile / (2 * $maxR * $Margin))
$cellW = $Tile / $gridN
$buckets = New-Object 'System.Collections.ArrayList[]' ($gridN * $gridN)
for ($i = 0; $i -lt $buckets.Length; $i++) { $buckets[$i] = New-Object System.Collections.ArrayList }

$half = $Tile / 2.0
$bag = New-Object System.Collections.ArrayList
$iconTotal = 0
$fillTotal = 0
$sizeMin = 9999.0
$sizeMax = 0.0

foreach ($cls in $classes) {
  $grid = $cls.Grid
  $cw = $Tile / $grid

  $cells = @()
  for ($r = 0; $r -lt $grid; $r++) { for ($c = 0; $c -lt $grid; $c++) { $cells += ,@($c, $r) } }
  $cells = $cells | Sort-Object { Rnd }

  $want = $cls.Count
  $got = 0
  $pass = 0

  # Multiple passes over the shuffled cells: a cell that failed while the tile
  # was filling may succeed later against a different neighbourhood.
  while ($got -lt $want -and $pass -lt 3) {
    $pass++
    foreach ($cell in $cells) {
      if ($got -ge $want) { break }

      $size = RndRange $cls.Min $cls.Max
      $r = $size * $RadiusFactor
      $ox = $cell[0] * $cw
      $oy = $cell[1] * $cw

      for ($t = 0; $t -lt $cls.Tries; $t++) {
        $x = $ox + (Rnd) * $cw
        $y = $oy + (Rnd) * $cw

        $cx = [int][Math]::Floor($x / $cellW)
        $cy = [int][Math]::Floor($y / $cellW)
        $ok = $true

        for ($gx = -1; $gx -le 1 -and $ok; $gx++) {
          for ($gy = -1; $gy -le 1 -and $ok; $gy++) {
            $bi = ((($cy + $gy) % $gridN + $gridN) % $gridN) * $gridN + ((($cx + $gx) % $gridN + $gridN) % $gridN)
            foreach ($k in $buckets[$bi]) {
              $need = ($r + $pr[$k]) * $Margin
              $dx = [Math]::Abs($x - $px[$k]); if ($dx -gt $half) { $dx = $Tile - $dx }
              if ($dx -gt $need) { continue }
              $dy = [Math]::Abs($y - $py[$k]); if ($dy -gt $half) { $dy = $Tile - $dy }
              if ($dy -gt $need) { continue }
              if (($dx * $dx + $dy * $dy) -lt ($need * $need)) { $ok = $false; break }
            }
          }
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
        $pn[$n] = $name; $ps[$n] = $size; $pt[$n] = RndRange -24 24
        if ($size -lt $sizeMin) { $sizeMin = $size }
        if ($size -gt $sizeMax) { $sizeMax = $size }
        [void]$buckets[$cy * $gridN + $cx].Add($n)
        $n++
        $got++
        break
      }
    }
  }
  "  {0,-6} {1,3}-{2,3}px  placed {3}/{4}  (passes {5})" -f $cls.Kind, $cls.Min, $cls.Max, $got, $want, $pass
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

# reserved-circle coverage, as a density readout
$cov = 0.0
for ($i = 0; $i -lt $n; $i++) { $cov += [Math]::PI * $pr[$i] * $pr[$i] }
$covPct = [Math]::Round(100 * $cov / ($Tile * $Tile), 1)

$defs = Get-Content $defsPath -Raw

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$Tile" height="$Tile" viewBox="0 0 $Tile $Tile">
  <!--
    GENERATED FILE - do not hand-edit.
    Rebuild with tools/gen-pattern.ps1 (seed $Seed).

    Doodle tile for the login background: $iconTotal icons + $fillTotal filler marks,
    packed largest-first with a strict no-overlap constraint across five size
    classes spanning $([int]$sizeMin)-$([int]$sizeMax) units ($covPct% reserved-area coverage).
    Toroidal spacing plus edge wrapping makes the tile repeat seamlessly.
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
"icons:    $iconTotal"
"fillers:  $fillTotal"
"sizes:    $([int]$sizeMin)-$([int]$sizeMax)px  ($([Math]::Round($sizeMax/$sizeMin,1))x range)"
"coverage: $covPct%"
"wrapped:  $copies"
"elements: $($lines.Count)"
"size:     $([Math]::Round((Get-Item $outPath).Length/1KB,1)) KB"
