param(
  [string]$CsvPath = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\manifold_trades_OANDA_SameManifold_Pass2012_FullPortfolio.csv'),
  [string]$OutputDir = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\reports\oanda_eurusd_xauusd_same_manifold_20260619',
  [double]$StartingBalance = 10000.0,
  [double[]]$RiskPct = @(0.25, 0.50, 0.75, 1.00),
  [string[]]$WindowStart = @('2000-01-01', '2018-01-01'),
  [double]$BenchmarkBalance = 80000.0,
  [int]$Iterations = 1000,
  [int]$Seed = 2012
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Percentile {
  param(
    [double[]]$Values,
    [double]$Percentile
  )

  $clean = @($Values | Where-Object { -not [double]::IsNaN($_) } | Sort-Object)
  if ($clean.Count -eq 0) { return $null }
  if ($clean.Count -eq 1) { return [double]$clean[0] }

  $position = ($clean.Count - 1) * $Percentile
  $lowerIndex = [int][math]::Floor($position)
  $upperIndex = [int][math]::Ceiling($position)
  if ($lowerIndex -eq $upperIndex) { return [double]$clean[$lowerIndex] }

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
    if ($roll -le $cumulative) { return [double]$bucket.NoiseR }
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

# Rebuild R-multiples from the original 100K / 1% isolated-symbol tester runs.
$sourceStartingBalance = 100000.0
$isolatedBalances = @{}
$withR = @($closedAll | ForEach-Object {
  if (-not $isolatedBalances.ContainsKey($_.test_id)) {
    $isolatedBalances[$_.test_id] = $sourceStartingBalance
  }

  $before = [double]$isolatedBalances[$_.test_id]
  $riskAmount = $before * ($_.original_risk_pct / 100.0)
  $rMultiple = if ($riskAmount -ne 0) { $_.net / $riskAmount } else { 0.0 }
  $isolatedBalances[$_.test_id] = $before + $_.net

  [pscustomobject]@{
    pass = $pass
    test_id = $_.test_id
    symbol = $_.symbol
    trade_id = $_.trade_id
    deal_time = $_.deal_time
    r_multiple = $rMultiple
  }
})

$scenarios = @(
  [pscustomobject]@{
    Name = 'BalancedNoise'
    Distribution = @(
      [pscustomobject]@{ Probability = 0.70; NoiseR = 0.00 },
      [pscustomobject]@{ Probability = 0.14; NoiseR = 0.02 },
      [pscustomobject]@{ Probability = 0.14; NoiseR = -0.02 },
      [pscustomobject]@{ Probability = 0.02; NoiseR = -0.10 }
    )
  },
  [pscustomobject]@{
    Name = 'ConservativeNoise'
    Distribution = @(
      [pscustomobject]@{ Probability = 0.60; NoiseR = 0.00 },
      [pscustomobject]@{ Probability = 0.15; NoiseR = 0.02 },
      [pscustomobject]@{ Probability = 0.20; NoiseR = -0.02 },
      [pscustomobject]@{ Probability = 0.05; NoiseR = -0.10 }
    )
  },
  [pscustomobject]@{
    Name = 'NewsHeavyNoise'
    Distribution = @(
      [pscustomobject]@{ Probability = 0.50; NoiseR = 0.00 },
      [pscustomobject]@{ Probability = 0.15; NoiseR = 0.02 },
      [pscustomobject]@{ Probability = 0.25; NoiseR = -0.03 },
      [pscustomobject]@{ Probability = 0.10; NoiseR = -0.10 }
    )
  }
)

$baselineRows = New-Object System.Collections.Generic.List[object]
$mcIterationRows = New-Object System.Collections.Generic.List[object]
$random = [System.Random]::new($Seed)

foreach ($window in $WindowStart) {
  $windowStartDate = [datetime]$window
  $windowLabel = if ($windowStartDate.Year -eq 2000) { '2000_2026' } else { '{0}_2026' -f $windowStartDate.Year }
  $ordered = @($withR | Where-Object { $_.deal_time -ge $windowStartDate } | Sort-Object deal_time, symbol, trade_id)
  if ($ordered.Count -eq 0) { continue }

  $firstDate = ($ordered | Select-Object -First 1).deal_time
  $lastDate = ($ordered | Select-Object -Last 1).deal_time
  $years = (($lastDate - $firstDate).TotalDays / 365.25)

  foreach ($risk in $RiskPct) {
    $balance = $StartingBalance
    $peak = $StartingBalance
    $maxDd = 0.0
    $maxDdPct = 0.0
    $maxOneTradeLoss = 0.0
    $maxOneTradeWin = 0.0

    foreach ($trade in $ordered) {
      $pnl = $balance * ($risk / 100.0) * $trade.r_multiple
      $balance += $pnl
      if ($pnl -lt $maxOneTradeLoss) { $maxOneTradeLoss = $pnl }
      if ($pnl -gt $maxOneTradeWin) { $maxOneTradeWin = $pnl }
      if ($balance -gt $peak) { $peak = $balance }
      $dd = $peak - $balance
      $ddPct = if ($peak -ne 0) { 100.0 * $dd / $peak } else { 0.0 }
      if ($dd -gt $maxDd) { $maxDd = $dd }
      if ($ddPct -gt $maxDdPct) { $maxDdPct = $ddPct }
    }

    $cagr = if ($years -gt 0 -and $balance -gt 0) { ([math]::Pow($balance / $StartingBalance, 1.0 / $years) - 1.0) * 100.0 } else { $null }
    $totalReturnPct = 100.0 * ($balance - $StartingBalance) / $StartingBalance

    $baselineRows.Add([pscustomobject]@{
      Pass = $pass
      Window = $windowLabel
      RiskPct = $risk
      InitialRiskDollars = [math]::Round($StartingBalance * ($risk / 100.0), 2)
      StartingBalance = $StartingBalance
      EndingBalance = [math]::Round($balance, 2)
      TotalProfit = [math]::Round($balance - $StartingBalance, 2)
      TotalReturnPct = [math]::Round($totalReturnPct, 2)
      CAGRPct = if ($null -ne $cagr) { [math]::Round($cagr, 2) } else { $null }
      MaxClosedDD = [math]::Round($maxDd, 2)
      MaxClosedDDPct = [math]::Round($maxDdPct, 2)
      MaxOneTradeLoss = [math]::Round($maxOneTradeLoss, 2)
      MaxOneTradeWin = [math]::Round($maxOneTradeWin, 2)
      ClosedTrades = $ordered.Count
      BeatsBenchmark = ($balance -gt $BenchmarkBalance)
      Profitable = ($balance -gt $StartingBalance)
      FirstTrade = $firstDate.ToString('yyyy-MM-dd')
      LastTrade = $lastDate.ToString('yyyy-MM-dd')
    })

    foreach ($scenario in $scenarios) {
      for ($i = 1; $i -le $Iterations; $i++) {
        $mcBalance = $StartingBalance
        $mcPeak = $StartingBalance
        $mcMaxDdPct = 0.0

        foreach ($trade in $ordered) {
          $noise = Get-NoiseR -Random $random -Distribution $scenario.Distribution
          $adjustedR = $trade.r_multiple + $noise
          $pnl = $mcBalance * ($risk / 100.0) * $adjustedR
          $mcBalance += $pnl
          if ($mcBalance -gt $mcPeak) { $mcPeak = $mcBalance }
          $ddPct = if ($mcPeak -ne 0) { 100.0 * ($mcPeak - $mcBalance) / $mcPeak } else { 0.0 }
          if ($ddPct -gt $mcMaxDdPct) { $mcMaxDdPct = $ddPct }
        }

        $mcCagr = if ($years -gt 0 -and $mcBalance -gt 0) { ([math]::Pow($mcBalance / $StartingBalance, 1.0 / $years) - 1.0) * 100.0 } else { [double]::NaN }
        $mcIterationRows.Add([pscustomobject]@{
          Pass = $pass
          Window = $windowLabel
          Scenario = $scenario.Name
          RiskPct = $risk
          Iteration = $i
          EndingBalance = [math]::Round($mcBalance, 2)
          CAGRPct = if (-not [double]::IsNaN($mcCagr)) { [math]::Round($mcCagr, 2) } else { $null }
          MaxClosedDDPct = [math]::Round($mcMaxDdPct, 2)
          BeatsBenchmark = ($mcBalance -gt $BenchmarkBalance)
          Profitable = ($mcBalance -gt $StartingBalance)
        })
      }
    }
  }
}

$mcSummaryRows = New-Object System.Collections.Generic.List[object]
foreach ($group in ($mcIterationRows | Group-Object Window, Scenario, RiskPct)) {
  $items = @($group.Group)
  $ending = [double[]]@($items | ForEach-Object { [double]$_.EndingBalance })
  $cagr = [double[]]@($items | ForEach-Object { [double]$_.CAGRPct })
  $dd = [double[]]@($items | ForEach-Object { [double]$_.MaxClosedDDPct })
  $first = $items[0]

  $mcSummaryRows.Add([pscustomobject]@{
    Pass = $first.Pass
    Window = $first.Window
    Scenario = $first.Scenario
    RiskPct = [double]$first.RiskPct
    Iterations = $items.Count
    EndingP05 = [math]::Round((Get-Percentile -Values $ending -Percentile 0.05), 2)
    EndingMedian = [math]::Round((Get-Percentile -Values $ending -Percentile 0.50), 2)
    EndingP95 = [math]::Round((Get-Percentile -Values $ending -Percentile 0.95), 2)
    CagrMedianPct = [math]::Round((Get-Percentile -Values $cagr -Percentile 0.50), 2)
    MaxDdMedianPct = [math]::Round((Get-Percentile -Values $dd -Percentile 0.50), 2)
    MaxDdP95Pct = [math]::Round((Get-Percentile -Values $dd -Percentile 0.95), 2)
    BeatBenchmarkPct = [math]::Round(100.0 * @($items | Where-Object { $_.BeatsBenchmark }).Count / [math]::Max(1, $items.Count), 2)
    ProfitablePct = [math]::Round(100.0 * @($items | Where-Object { $_.Profitable }).Count / [math]::Max(1, $items.Count), 2)
  })
}

$baselinePath = Join-Path $OutputDir "pass${pass}_live_risk_sizing_baseline_10k.csv"
$mcIterationsPath = Join-Path $OutputDir "pass${pass}_live_risk_sizing_noise_mc_iterations_10k.csv"
$mcSummaryPath = Join-Path $OutputDir "pass${pass}_live_risk_sizing_noise_mc_summary_10k.csv"

$baselineRows | Sort-Object Window, RiskPct | Export-Csv -LiteralPath $baselinePath -NoTypeInformation -Encoding ASCII
$mcIterationRows | Export-Csv -LiteralPath $mcIterationsPath -NoTypeInformation -Encoding ASCII
$mcSummaryRows | Sort-Object Window, RiskPct, Scenario | Export-Csv -LiteralPath $mcSummaryPath -NoTypeInformation -Encoding ASCII

"Wrote baseline: $baselinePath"
"Wrote Monte Carlo iterations: $mcIterationsPath"
"Wrote Monte Carlo summary: $mcSummaryPath"
""
"Baseline risk sizing:"
$baselineRows |
  Sort-Object Window, RiskPct |
  Format-Table Window, RiskPct, InitialRiskDollars, EndingBalance, CAGRPct, MaxClosedDD, MaxClosedDDPct, MaxOneTradeLoss, BeatsBenchmark -AutoSize

"Monte Carlo summary, full period:"
$mcSummaryRows |
  Where-Object { $_.Window -eq '2000_2026' } |
  Sort-Object RiskPct, Scenario |
  Format-Table Scenario, RiskPct, EndingP05, EndingMedian, CagrMedianPct, MaxDdP95Pct, BeatBenchmarkPct -AutoSize
