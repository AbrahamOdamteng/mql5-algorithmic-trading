param(
  [string]$CsvPath = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\manifold_trades_OANDA_SameManifold_Pass2012_FullPortfolio.csv'),
  [string]$OutputDir = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\reports\oanda_eurusd_xauusd_same_manifold_20260619',
  [double]$StartingBalance = 100000.0,
  [double[]]$RiskPct = @(0.50, 0.55, 0.75, 1.00),
  [double[]]$HaircutR = @(0.00, 0.05, 0.10, 0.20, 0.30),
  [string[]]$WindowStart = @('2000-01-01', '2018-01-01')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

# Reconstruct each isolated symbol test's dynamic balance so every trade can be
# converted into an approximate R-multiple from the original 1% tester risk.
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

$rRowsPath = Join-Path $OutputDir "pass${pass}_trade_r_multiples.csv"
$withR |
  Sort-Object deal_time, symbol, trade_id |
  Select-Object pass, manifold_id, test_id, symbol, trade_id,
    @{Name='deal_time';Expression={$_.deal_time.ToString('yyyy-MM-dd HH:mm')}},
    net,
    @{Name='r_multiple';Expression={[math]::Round($_.r_multiple, 6)}} |
  Export-Csv -LiteralPath $rRowsPath -NoTypeInformation -Encoding ASCII

$summaries = New-Object System.Collections.Generic.List[object]

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

  foreach ($risk in $RiskPct) {
    foreach ($haircut in $HaircutR) {
      $balance = $StartingBalance
      $peak = $StartingBalance
      $maxDd = 0.0
      $maxDdPct = 0.0
      $wins = 0
      $losses = 0
      $grossProfit = 0.0
      $grossLoss = 0.0
      $equityRows = New-Object System.Collections.Generic.List[object]

      foreach ($trade in $ordered) {
        $adjustedR = $trade.r_multiple - $haircut
        $pnl = $balance * ($risk / 100.0) * $adjustedR
        $balance += $pnl

        if ($pnl -gt 0) {
          $wins++
          $grossProfit += $pnl
        } elseif ($pnl -lt 0) {
          $losses++
          $grossLoss += $pnl
        }

        if ($balance -gt $peak) {
          $peak = $balance
        }

        $dd = $peak - $balance
        $ddPct = if ($peak -ne 0) { 100.0 * $dd / $peak } else { 0.0 }

        if ($dd -gt $maxDd) {
          $maxDd = $dd
        }

        if ($ddPct -gt $maxDdPct) {
          $maxDdPct = $ddPct
        }

        $equityRows.Add([pscustomobject]@{
          pass = $pass
          window = $windowLabel
          risk_pct = $risk
          haircut_r = $haircut
          deal_time = $trade.deal_time.ToString('yyyy-MM-dd HH:mm')
          symbol = $trade.symbol
          test_id = $trade.test_id
          trade_id = $trade.trade_id
          original_r = [math]::Round($trade.r_multiple, 6)
          adjusted_r = [math]::Round($adjustedR, 6)
          pnl = [math]::Round($pnl, 2)
          balance = [math]::Round($balance, 2)
          peak = [math]::Round($peak, 2)
          drawdown = [math]::Round($dd, 2)
          drawdown_pct = [math]::Round($ddPct, 3)
        })
      }

      $cagr = if ($years -gt 0 -and $balance -gt 0) {
        ([math]::Pow($balance / $StartingBalance, 1.0 / $years) - 1.0) * 100.0
      } else {
        $null
      }

      $totalReturnPct = 100.0 * ($balance - $StartingBalance) / $StartingBalance
      $profitFactor = if ($grossLoss -ne 0) { $grossProfit / [math]::Abs($grossLoss) } else { $null }
      $equityCurveName = 'pass{0}_r_haircut_equity_{1}_risk{2}_haircut{3}.csv' -f `
        $pass,
        $windowLabel,
        ($risk.ToString('0.##') -replace '\.', 'p'),
        ($haircut.ToString('0.##') -replace '\.', 'p')
      $equityCurvePath = Join-Path $OutputDir $equityCurveName

      $equityRows | Export-Csv -LiteralPath $equityCurvePath -NoTypeInformation -Encoding ASCII

      $summaries.Add([pscustomobject]@{
        Pass = $pass
        Window = $windowLabel
        RiskPct = $risk
        HaircutR = $haircut
        StartingBalance = $StartingBalance
        EndingBalance = [math]::Round($balance, 2)
        TotalProfit = [math]::Round($balance - $StartingBalance, 2)
        TotalReturnPct = [math]::Round($totalReturnPct, 2)
        CAGRPct = if ($null -ne $cagr) { [math]::Round($cagr, 2) } else { $null }
        MaxClosedDD = [math]::Round($maxDd, 2)
        MaxClosedDDPct = [math]::Round($maxDdPct, 2)
        ReturnToDD = if ($maxDdPct -gt 0) { [math]::Round($totalReturnPct / $maxDdPct, 2) } else { $null }
        ClosedTrades = $ordered.Count
        WinRatePct = [math]::Round(100.0 * $wins / [math]::Max(1, $ordered.Count), 2)
        ProfitFactor = if ($null -ne $profitFactor) { [math]::Round($profitFactor, 2) } else { $null }
        FirstTrade = $firstDate.ToString('yyyy-MM-dd')
        LastTrade = $lastDate.ToString('yyyy-MM-dd')
        Beats800K = ($balance -gt 800000)
        Beats700K = ($balance -gt 700000)
        EquityCurve = $equityCurvePath
      })
    }
  }
}

$summaryPath = Join-Path $OutputDir "pass${pass}_r_haircut_stress_summary.csv"
$summaries |
  Sort-Object Window, RiskPct, HaircutR |
  Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding ASCII

"Wrote trade R-multiples: $rRowsPath"
"Wrote summary: $summaryPath"
""
"Full-period 2000 -> 2026:"
$summaries |
  Where-Object { $_.Window -eq '2000_2026' -and ($_.RiskPct -eq 0.55 -or $_.RiskPct -eq 1.0) } |
  Sort-Object RiskPct, HaircutR |
  Format-Table Window, RiskPct, HaircutR, EndingBalance, TotalReturnPct, CAGRPct, MaxClosedDDPct, Beats800K -AutoSize

"OOS-only 2018 -> 2026:"
$summaries |
  Where-Object { $_.Window -eq '2018_2026' -and ($_.RiskPct -eq 0.55 -or $_.RiskPct -eq 1.0) } |
  Sort-Object RiskPct, HaircutR |
  Format-Table Window, RiskPct, HaircutR, EndingBalance, TotalReturnPct, CAGRPct, MaxClosedDDPct, Beats800K -AutoSize
