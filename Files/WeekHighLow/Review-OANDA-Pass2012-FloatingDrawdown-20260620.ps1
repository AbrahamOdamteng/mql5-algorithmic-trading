param(
  [string]$ReportsDir = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\reports\oanda_eurusd_xauusd_same_manifold_20260619',
  [string]$Pattern = '*Pass2012*.xml.htm',
  [double]$StartingDeposit = 100000.0,
  [double]$WarningEquityDdPct = 30.0,
  [switch]$IncludeExecutionStress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Decode-Report {
  param([Parameter(Mandatory = $true)][string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
    return [System.Text.Encoding]::Unicode.GetString($bytes)
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) {
    return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes)
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
    return [System.Text.Encoding]::UTF8.GetString($bytes)
  }

  return [System.Text.Encoding]::Default.GetString($bytes)
}

function Clean-HtmlText {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) {
    return $null
  }

  $value = [System.Net.WebUtility]::HtmlDecode($Text)
  $value = $value -replace '<[^>]+>', ' '
  $value = $value -replace '\s+', ' '
  return $value.Trim()
}

function Convert-Mt5Number {
  param([AllowNull()][string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $null
  }

  $match = [regex]::Match($Text, '-?[0-9][0-9\s]*([.,][0-9]+)?')
  if (-not $match.Success) {
    return $null
  }

  $number = $match.Value -replace '\s', ''
  $number = $number -replace ',', '.'
  return [double]::Parse($number, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-ReportMetric {
  param(
    [Parameter(Mandatory = $true)][string]$Html,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $pattern = [regex]::Escape($Label) + ':</td>\s*<td[^>]*>\s*<b>(.*?)</b>'
  $match = [regex]::Match($Html, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($match.Success) {
    return Clean-HtmlText $match.Groups[1].Value
  }

  return $null
}

function Get-AmountAndPercent {
  param([AllowNull()][string]$Text)

  $amount = Convert-Mt5Number $Text
  $pct = $null

  if ($Text -match '\(([-0-9.,\s]+)%\)') {
    $pct = Convert-Mt5Number $Matches[1]
  } elseif ($Text -match '([-0-9.,\s]+)%') {
    $pct = Convert-Mt5Number $Matches[1]
  }

  [pscustomobject]@{
    Amount = $amount
    Percent = $pct
    Raw = $Text
  }
}

function Get-ReportIdentity {
  param([Parameter(Mandatory = $true)][string]$FileName)

  $symbol = $null
  $window = $null
  $scope = 'Other'

  if ($FileName -match '^(?<symbol>[A-Z]+)_D1StopLossSplit_OANDA_Pass2012_(?<segment>IS|VAL|OOS)_') {
    $symbol = $Matches.symbol
    $window = $Matches.segment
    $scope = 'FixedSegment'
  } elseif ($FileName -match '^(?<symbol>[A-Z]+)_Pass2012_Shifted_(?<window>W\d{4}_\d{4})_') {
    $symbol = $Matches.symbol
    $window = $Matches.window
    $scope = 'ShiftedWindow'
  } elseif ($FileName -match '^OANDA_SameManifold_Pass2012_FullPortfolio_(?<symbol>[A-Z]+)_Pass2012_FULL') {
    $symbol = $Matches.symbol
    $window = 'FULL_2000_2026'
    $scope = 'FullPortfolio'
  } elseif ($FileName -match '^OANDA_Pass2012_ExecStress_(?<scenario>[^_]+)_(?<symbol>[A-Z]+)_') {
    $symbol = $Matches.symbol
    $window = $Matches.scenario
    $scope = 'ExecutionStress'
  }

  [pscustomobject]@{
    Scope = $scope
    Symbol = $symbol
    Window = $window
  }
}

if (-not (Test-Path -LiteralPath $ReportsDir)) {
  throw "Reports directory not found: $ReportsDir"
}

$files = @(Get-ChildItem -LiteralPath $ReportsDir -Filter $Pattern -File)
if (-not $IncludeExecutionStress) {
  $files = @($files | Where-Object { $_.Name -notmatch 'ExecStress' })
}

if ($files.Count -eq 0) {
  throw "No reports matched pattern $Pattern in $ReportsDir"
}

$rows = foreach ($file in $files) {
  $html = Decode-Report -Path $file.FullName
  $identity = Get-ReportIdentity -FileName $file.Name

  $profit = Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Net Profit')
  $balanceDdAbs = Get-AmountAndPercent (Get-ReportMetric -Html $html -Label 'Balance Drawdown Absolute')
  $balanceDdMax = Get-AmountAndPercent (Get-ReportMetric -Html $html -Label 'Balance Drawdown Maximal')
  $balanceDdRel = Get-AmountAndPercent (Get-ReportMetric -Html $html -Label 'Balance Drawdown Relative')
  $equityDdAbs = Get-AmountAndPercent (Get-ReportMetric -Html $html -Label 'Equity Drawdown Absolute')
  $equityDdMax = Get-AmountAndPercent (Get-ReportMetric -Html $html -Label 'Equity Drawdown Maximal')
  $equityDdRel = Get-AmountAndPercent (Get-ReportMetric -Html $html -Label 'Equity Drawdown Relative')

  $equityDdPct = if ($null -ne $equityDdMax.Percent) { $equityDdMax.Percent } else { $equityDdRel.Percent }
  $balanceDdPct = if ($null -ne $balanceDdMax.Percent) { $balanceDdMax.Percent } else { $balanceDdRel.Percent }
  $equityDdAmount = if ($null -ne $equityDdMax.Amount) { $equityDdMax.Amount } else { $equityDdRel.Amount }
  $balanceDdAmount = if ($null -ne $balanceDdMax.Amount) { $balanceDdMax.Amount } else { $balanceDdRel.Amount }
  $floatingPremiumPct = if ($null -ne $equityDdPct -and $null -ne $balanceDdPct) { $equityDdPct - $balanceDdPct } else { $null }

  [pscustomobject]@{
    Scope = $identity.Scope
    Symbol = $identity.Symbol
    Window = $identity.Window
    Profit = [math]::Round($profit, 2)
    Trades = [int](Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Trades'))
    ProfitFactor = [math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Profit Factor')), 2)
    Recovery = [math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Recovery Factor')), 2)
    Sharpe = [math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Sharpe Ratio')), 2)
    BalanceDDAbsAmount = [math]::Round($balanceDdAbs.Amount, 2)
    BalanceDDMaxAmount = [math]::Round($balanceDdAmount, 2)
    BalanceDDPct = [math]::Round($balanceDdPct, 2)
    EquityDDAbsAmount = [math]::Round($equityDdAbs.Amount, 2)
    EquityDDMaxAmount = [math]::Round($equityDdAmount, 2)
    EquityDDPct = [math]::Round($equityDdPct, 2)
    FloatingPremiumPct = if ($null -ne $floatingPremiumPct) { [math]::Round($floatingPremiumPct, 2) } else { $null }
    ProfitToEquityDD = if ($null -ne $equityDdPct -and $equityDdPct -ne 0) { [math]::Round(($profit / ($StartingDeposit / 100.0)) / $equityDdPct, 3) } else { $null }
    WarnEquityDD = ($equityDdPct -gt $WarningEquityDdPct)
    File = $file.Name
    BalanceDDAbsRaw = $balanceDdAbs.Raw
    BalanceDDMaxRaw = $balanceDdMax.Raw
    BalanceDDRelRaw = $balanceDdRel.Raw
    EquityDDAbsRaw = $equityDdAbs.Raw
    EquityDDMaxRaw = $equityDdMax.Raw
    EquityDDRelRaw = $equityDdRel.Raw
  }
}

$detailPath = Join-Path $ReportsDir 'pass2012_floating_equity_drawdown_review.csv'
$rows |
  Sort-Object @{Expression='EquityDDPct';Descending=$true}, Scope, Symbol, Window |
  Export-Csv -LiteralPath $detailPath -NoTypeInformation -Encoding ASCII

$summaryRows = $rows | Group-Object Scope | ForEach-Object {
  $g = @($_.Group)
  [pscustomobject]@{
    Scope = $_.Name
    Reports = $g.Count
    MaxEquityDDPct = [math]::Round(($g | Measure-Object EquityDDPct -Maximum).Maximum, 2)
    MaxBalanceDDPct = [math]::Round(($g | Measure-Object BalanceDDPct -Maximum).Maximum, 2)
    MaxFloatingPremiumPct = [math]::Round(($g | Measure-Object FloatingPremiumPct -Maximum).Maximum, 2)
    TotalProfit = [math]::Round(($g | Measure-Object Profit -Sum).Sum, 2)
    TotalTrades = ($g | Measure-Object Trades -Sum).Sum
    WarningReports = @($g | Where-Object WarnEquityDD).Count
  }
}

$summaryPath = Join-Path $ReportsDir 'pass2012_floating_equity_drawdown_summary.csv'
$summaryRows |
  Sort-Object MaxEquityDDPct -Descending |
  Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding ASCII

"Wrote detail: $detailPath"
"Wrote summary: $summaryPath"
""
"Worst reports by equity drawdown:"
$rows |
  Sort-Object EquityDDPct -Descending |
  Select-Object -First 12 Scope, Symbol, Window, Profit, Trades, BalanceDDPct, EquityDDPct, FloatingPremiumPct, ProfitToEquityDD, WarnEquityDD |
  Format-Table -AutoSize

"Summary by scope:"
$summaryRows |
  Sort-Object MaxEquityDDPct -Descending |
  Format-Table -AutoSize
