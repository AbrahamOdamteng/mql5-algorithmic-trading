param(
  [string]$CsvPath = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\manifold_trades_OANDA_SameManifold_Pass2012_FullPortfolio.csv'),
  [string]$OutputDir = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\reports\oanda_eurusd_xauusd_same_manifold_20260619',
  [double]$StartingBalance = 100000.0,
  [double[]]$RiskPct = @(0.55, 1.00),
  [string[]]$WindowStart = @('2000-01-01', '2018-01-01'),
  [int]$Iterations = 1000,
  [int]$Seed = 2012,
  [double]$BenchmarkBalance = 800000.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Percentile {
  param(
    [double[]]$Values,
    [double]$Percentile
  )

  $clean = @($Values | Where-Object { -not [double]::IsNaN($_) } | Sort-Object)
  if ($clean.Count -eq 0) {
    return $null
  }

  if ($clean.Count -eq 1) {
    return [double]$clean[0]
  }

  $position = ($clean.Count - 1) * $Percentile
  $lowerIndex = [int][math]::Floor($position)
  $upperIndex = [int][math]::Ceiling($position)

  if ($lowerIndex -eq $upperIndex) {
    return [double]$clean[$lowerIndex]
  }

  $weight = $position - $lowerIndex
  return ([double]$clean[$lowerIndex] * (1.0 - $weight)) + ([double]$clean[$upperIndex] * $weight)
}

function Get-NoiseR {
  param(
    [System.Random]$Random,
    [object[]]$Distribution
  )

  $roll = $Random.NextDouble()
  $cumulative = 0.0

  foreach ($bucket in $Distribution) {
    $cumulative += [double]$bucket.Probability
    if ($roll -le $cumulative) {
      return [double]$bucket.NoiseR
    }
  }

  return [double]$Distribution[-1].NoiseR
}

if (-not (Test-Path -LiteralPath $CsvPath)) {
  throw "Trade CSV not found: $CsvPath"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$rows = Import-Csv -LiteralPath $CsvPath
if ($rows.Count -eq 0) {
  throw "Trade CSV has no rows: $CsvPath"
}

$manifoldId = ($rows | Select-Object -First 1).manifold_id
$pass = if ($manifoldId -match 'Pass(?<p>\d+)') { $Matches.p } else { $manifoldId }

$closedAll = @($rows |
  Where-Object { $_.entry_type -eq 'OUT' } |
  ForEach-Object {
    [pscustomobject]@{
      manifold_id = $_.manifold_id
      test_id = $_.test_id
      symbol = $_.symbol
      trade_id = $_.trade_id
      deal_time = [datetime]::ParseExact($_.deal_time, 'yyyy.MM.dd HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
      net = [double]$_.profit + [double]$_.swap + [double]$_.commission
      original_risk_pct = [double]$_.risk_percentage
    }
  } |
  Sort-Object test_id, deal_time, trade_id)

if ($closedAll.Count -eq 0) {
  throw "Trade CSV has no closed OUT rows: $CsvPath"
}

$isolatedBalances = @{}
$withR = @($closedAll | ForEach-Object {
  if (-not $isolatedBalances.ContainsKey($_.test_id)) {
    $isolatedBalances[$_.test_id] = $StartingBalance
  }

  $before = [double]$isolatedBalances[$_.test_id]
  $riskAmount = $before * ($_.original_risk_pct / 100.0)
  $rMultiple = if ($riskAmount -ne 0) { $_.net / $riskAmount } else { 0.0 }
  $isolatedBalances[$_.test_id] = $before + $_.net

  [pscustomobject]@{
    pass = $pass
    manifold_id = $_.manifold_id
    test_id = $_.test_id
    symbol = $_.symbol
    trade_id = $_.trade_id
    deal_time = $_.deal_time
    net = $_.net
    r_multiple = $rMultiple
  }
})

$scenarios = @(
  [pscustomobject]@{
    Name = 'BalancedNoise'
    Description = '70% unchanged, 14% +0.02R, 14% -0.02R, 2% -0.10R news-like adverse'
    Distribution = @(
      [pscustomobject]@{ Probability = 0.70; NoiseR = 0.00 },
      [pscustomobject]@{ Probability = 0.14; NoiseR = 0.02 },
      [pscustomobject]@{ Probability = 0.14; NoiseR = -0.02 },
      [pscustomobject]@{ Probability = 0.02; NoiseR = -0.10 }
    )
  },
  [pscustomobject]@{
    Name = 'ConservativeNoise'
    Description = '60% unchanged, 15% +0.02R, 20% -0.02R, 5% -0.10R news-like adverse'
    Distribution = @(
      [pscustomobject]@{ Probability = 0.60; NoiseR = 0.00 },
      [pscustomobject]@{ Probability = 0.15; NoiseR = 0.02 },
      [pscustomobject]@{ Probability = 0.20; NoiseR = -0.02 },
      [pscustomobject]@{ Probability = 0.05; NoiseR = -0.10 }
    )
  },
  [pscustomobject]@{
    Name = 'NewsHeavyNoise'
    Description = '50% unchanged, 15% +0.02R, 25% -0.03R, 10% -0.10R news-like adverse'
    Distribution = @(
      [pscustomobject]@{ Probability = 0.50; NoiseR = 0.00 },
      [pscustomobject]@{ Probability = 0.15; NoiseR = 0.02 },
      [pscustomobject]@{ Probability = 0.25; NoiseR = -0.03 },
      [pscustomobject]@{ Probability = 0.10; NoiseR = -0.10 }
    )
  }
)

$scenarioPath = Join-Path $OutputDir "pass${pass}_execution_noise_mc_scenarios.csv"
$scenarios | ForEach-Object {
  [pscustomobject]@{
    Scenario = $_.Name
    Description = $_.Description
    Distribution = (($_.Distribution | ForEach-Object { "$($_.Probability):$($_.NoiseR)R" }) -join '; ')
  }
} | Export-Csv -LiteralPath $scenarioPath -NoTypeInformation -Encoding ASCII

$random = [System.Random]::new($Seed)
$iterationRows = New-Object System.Collections.Generic.List[object]

foreach ($window in $WindowStart) {
  $windowStartDate = [datetime]$window
  $windowLabel = if ($windowStartDate.Year -eq 2000) { '2000_2026' } else { '{0}_2026' -f $windowStartDate.Year }
  $ordered = @($withR | Where-Object { $_.deal_time -ge $windowStartDate } | Sort-Object deal_time, symbol, trade_id)

  if ($ordered.Count -eq 0) {
    continue
  }

  $firstDate = ($ordered | Select-Object -First 1).deal_time
  $lastDate = ($ordered | Select-Object -Last 1).deal_time
  $years = (($lastDate - $firstDate).TotalDays / 365.25)

  foreach ($scenario in $scenarios) {
    foreach ($risk in $RiskPct) {
      for ($i = 1; $i -le $Iterations; $i++) {
        $balance = $StartingBalance
        $peak = $StartingBalance
        $maxDdPct = 0.0
        $noiseSum = 0.0
        $positiveNoise = 0
        $negativeNoise = 0
        $newsNoise = 0

        foreach ($trade in $ordered) {
          $noise = Get-NoiseR -Random $random -Distribution $scenario.Distribution
          $adjustedR = $trade.r_multiple + $noise
          $pnl = $balance * ($risk / 100.0) * $adjustedR
          $balance += $pnl

          $noiseSum += $noise
          if ($noise -gt 0) { $positiveNoise++ }
          if ($noise -lt 0) { $negativeNoise++ }
          if ($noise -le -0.10) { $newsNoise++ }

          if ($balance -gt $peak) {
            $peak = $balance
          }

          $ddPct = if ($peak -ne 0) { 100.0 * ($peak - $balance) / $peak } else { 0.0 }
          if ($ddPct -gt $maxDdPct) {
            $maxDdPct = $ddPct
          }
        }

        $cagr = if ($years -gt 0 -and $balance -gt 0) {
          ([math]::Pow($balance / $StartingBalance, 1.0 / $years) - 1.0) * 100.0
        } else {
          [double]::NaN
        }

        $iterationRows.Add([pscustomobject]@{
          Pass = $pass
          Window = $windowLabel
          Scenario = $scenario.Name
          RiskPct = $risk
          Iteration = $i
          StartingBalance = $StartingBalance
          EndingBalance = [math]::Round($balance, 2)
          TotalReturnPct = [math]::Round(100.0 * ($balance - $StartingBalance) / $StartingBalance, 2)
          CAGRPct = if (-not [double]::IsNaN($cagr)) { [math]::Round($cagr, 2) } else { $null }
          MaxClosedDDPct = [math]::Round($maxDdPct, 2)
          ClosedTrades = $ordered.Count
          AvgNoiseR = [math]::Round($noiseSum / [math]::Max(1, $ordered.Count), 6)
          PositiveNoiseTrades = $positiveNoise
          NegativeNoiseTrades = $negativeNoise
          NewsLikeAdverseTrades = $newsNoise
          BeatsBenchmark = ($balance -gt $BenchmarkBalance)
          Profitable = ($balance -gt $StartingBalance)
        })
      }
    }
  }
}

$iterationsPath = Join-Path $OutputDir "pass${pass}_execution_noise_mc_iterations.csv"
$iterationRows | Export-Csv -LiteralPath $iterationsPath -NoTypeInformation -Encoding ASCII

$summaryRows = New-Object System.Collections.Generic.List[object]
$groups = $iterationRows | Group-Object Window, Scenario, RiskPct
foreach ($group in $groups) {
  $items = @($group.Group)
  $ending = [double[]]@($items | ForEach-Object { [double]$_.EndingBalance })
  $cagr = [double[]]@($items | ForEach-Object { [double]$_.CAGRPct })
  $dd = [double[]]@($items | ForEach-Object { [double]$_.MaxClosedDDPct })
  $returns = [double[]]@($items | ForEach-Object { [double]$_.TotalReturnPct })
  $first = $items[0]

  $summaryRows.Add([pscustomobject]@{
    Pass = $first.Pass
    Window = $first.Window
    Scenario = $first.Scenario
    RiskPct = [double]$first.RiskPct
    Iterations = $items.Count
    EndingP05 = [math]::Round((Get-Percentile -Values $ending -Percentile 0.05), 2)
    EndingP25 = [math]::Round((Get-Percentile -Values $ending -Percentile 0.25), 2)
    EndingMedian = [math]::Round((Get-Percentile -Values $ending -Percentile 0.50), 2)
    EndingP75 = [math]::Round((Get-Percentile -Values $ending -Percentile 0.75), 2)
    EndingP95 = [math]::Round((Get-Percentile -Values $ending -Percentile 0.95), 2)
    ReturnMedianPct = [math]::Round((Get-Percentile -Values $returns -Percentile 0.50), 2)
    CagrMedianPct = [math]::Round((Get-Percentile -Values $cagr -Percentile 0.50), 2)
    MaxDdMedianPct = [math]::Round((Get-Percentile -Values $dd -Percentile 0.50), 2)
    MaxDdP95Pct = [math]::Round((Get-Percentile -Values $dd -Percentile 0.95), 2)
    BeatBenchmarkPct = [math]::Round(100.0 * @($items | Where-Object { $_.BeatsBenchmark }).Count / [math]::Max(1, $items.Count), 2)
    ProfitablePct = [math]::Round(100.0 * @($items | Where-Object { $_.Profitable }).Count / [math]::Max(1, $items.Count), 2)
  })
}

$summaryPath = Join-Path $OutputDir "pass${pass}_execution_noise_mc_summary.csv"
$summaryRows |
  Sort-Object Window, RiskPct, Scenario |
  Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding ASCII

"Wrote scenarios: $scenarioPath"
"Wrote iterations: $iterationsPath"
"Wrote summary: $summaryPath"
""
"Full-period 2000 -> 2026:"
$summaryRows |
  Where-Object { $_.Window -eq '2000_2026' } |
  Sort-Object RiskPct, Scenario |
  Format-Table Window, Scenario, RiskPct, EndingP05, EndingMedian, EndingP95, CagrMedianPct, MaxDdP95Pct, BeatBenchmarkPct -AutoSize

"OOS-only 2018 -> 2026:"
$summaryRows |
  Where-Object { $_.Window -eq '2018_2026' } |
  Sort-Object RiskPct, Scenario |
  Format-Table Window, Scenario, RiskPct, EndingP05, EndingMedian, EndingP95, CagrMedianPct, MaxDdP95Pct, ProfitablePct -AutoSize
