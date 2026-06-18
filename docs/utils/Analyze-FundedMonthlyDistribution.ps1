param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [double]$StartingDeposit = 100000.0,

    [double]$TargetRiskPct = [double]::NaN,

    [string]$FromMonth = $null,

    [string]$ToMonth = $null,

    [switch]$Csv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-Number {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 0.0
    }

    return [double]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Convert-DealTime {
    param([Parameter(Mandatory = $true)][string]$Value)

    $formats = @('yyyy.MM.dd HH:mm', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm')
    $parsed = [datetime]::MinValue

    foreach ($format in $formats) {
        if ([datetime]::TryParseExact($Value, $format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed
        }
    }

    return [datetime]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Convert-MonthStart {
    param([Parameter(Mandatory = $true)][string]$Value)

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParseExact($Value, 'yyyy-MM', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return $parsed
    }

    if ([datetime]::TryParseExact($Value, 'yyyy.MM', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return $parsed
    }

    throw "Invalid month '$Value'. Use yyyy-MM, for example 2018-01."
}

function Get-Median {
    param([double[]]$Values)

    if ($Values.Count -eq 0) {
        return 0.0
    }

    $sorted = @($Values | Sort-Object)
    $middle = [int][math]::Floor($sorted.Count / 2)

    if (($sorted.Count % 2) -eq 1) {
        return [double]$sorted[$middle]
    }

    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Get-SumProperty {
    param(
        [object[]]$Items,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $sum = 0.0
    foreach ($item in @($Items)) {
        if ($null -ne $item) {
            $sum += [double]$item.$PropertyName
        }
    }

    return $sum
}

$rows = @(Import-Csv -LiteralPath (Resolve-Path -LiteralPath $CsvPath))
$closedRows = @($rows | Where-Object { $_.entry_type -eq 'OUT' })

$trades = foreach ($row in $closedRows) {
    $riskPct = Convert-Number $row.risk_percentage
    $scale = 1.0

    if (-not [double]::IsNaN($TargetRiskPct)) {
        if ($riskPct -le 0) {
            throw "Row has non-positive risk_percentage and cannot be scaled: trade_id=$($row.trade_id)"
        }

        $scale = $TargetRiskPct / $riskPct
    }

    $dealTime = Convert-DealTime $row.deal_time
    $netPnl = ((Convert-Number $row.profit) + (Convert-Number $row.swap) + (Convert-Number $row.commission)) * $scale

    [pscustomobject]@{
        Month     = $dealTime.ToString('yyyy-MM')
        Symbol    = $row.symbol
        DealTime  = $dealTime
        TradeId   = $row.trade_id
        NetPnl    = $netPnl
        RiskPct   = $riskPct
        RiskScale = $scale
    }
}

if ($trades.Count -eq 0 -and ([string]::IsNullOrWhiteSpace($FromMonth) -or [string]::IsNullOrWhiteSpace($ToMonth))) {
    throw 'No closed trades found. Provide both -FromMonth and -ToMonth to emit zero-trade months.'
}

$firstMonth = if ([string]::IsNullOrWhiteSpace($FromMonth)) {
    $minDate = ($trades | Sort-Object DealTime | Select-Object -First 1).DealTime
    [datetime]::new($minDate.Year, $minDate.Month, 1)
}
else {
    Convert-MonthStart $FromMonth
}

$lastMonth = if ([string]::IsNullOrWhiteSpace($ToMonth)) {
    $maxDate = ($trades | Sort-Object DealTime -Descending | Select-Object -First 1).DealTime
    [datetime]::new($maxDate.Year, $maxDate.Month, 1)
}
else {
    Convert-MonthStart $ToMonth
}

if ($lastMonth -lt $firstMonth) {
    throw "ToMonth '$($lastMonth.ToString('yyyy-MM'))' is before FromMonth '$($firstMonth.ToString('yyyy-MM'))'."
}

$monthKeys = @()
$cursor = $firstMonth
while ($cursor -le $lastMonth) {
    $monthKeys += $cursor.ToString('yyyy-MM')
    $cursor = $cursor.AddMonths(1)
}

$monthly = @(
    foreach ($month in $monthKeys) {
        $monthTrades = @($trades | Where-Object { $_.Month -eq $month })
        $profit = Get-SumProperty -Items $monthTrades -PropertyName 'NetPnl'
        $symbols = if ($monthTrades.Count) { @($monthTrades | ForEach-Object { $_.Symbol } | Sort-Object -Unique) } else { @() }
        $eurusdTrades = @($monthTrades | Where-Object { $_.Symbol -eq 'EURUSD' })
        $usdjpyTrades = @($monthTrades | Where-Object { $_.Symbol -eq 'USDJPY' })

        [pscustomobject]@{
            Month       = $month
            Profit      = [math]::Round($profit, 2)
            ReturnPct   = [math]::Round(($profit / $StartingDeposit) * 100.0, 3)
            Trades      = $monthTrades.Count
            Symbols     = ($symbols -join ',')
            EURUSD      = [math]::Round((Get-SumProperty -Items $eurusdTrades -PropertyName 'NetPnl'), 2)
            USDJPY      = [math]::Round((Get-SumProperty -Items $usdjpyTrades -PropertyName 'NetPnl'), 2)
        }
    }
)

if ($Csv) {
    $monthly | ConvertTo-Csv -NoTypeInformation
    exit 0
}

$returns = @($monthly | ForEach-Object { [double]$_.ReturnPct })
$positiveMonths = @($monthly | Where-Object { [double]$_.Profit -gt 0 })
$targetMonths = @($monthly | Where-Object { [double]$_.ReturnPct -ge 1.0 -and [double]$_.ReturnPct -le 3.0 })
$aboveTargetMonths = @($monthly | Where-Object { [double]$_.ReturnPct -gt 3.0 })
$losingMonths = @($monthly | Where-Object { [double]$_.Profit -lt 0 })
$flatMonths = @($monthly | Where-Object { [double]$_.Profit -eq 0 })
$activeMonths = @($monthly | Where-Object { [int]$_.Trades -gt 0 })
$zeroTradeMonths = @($monthly | Where-Object { [int]$_.Trades -eq 0 })

'SUMMARY'
[pscustomobject]@{
    CsvPath             = (Resolve-Path -LiteralPath $CsvPath).Path
    StartingDeposit     = $StartingDeposit
    TargetRiskPct       = if ([double]::IsNaN($TargetRiskPct)) { $null } else { $TargetRiskPct }
    ClosedTrades        = $trades.Count
    Months              = $monthly.Count
    ActiveMonths        = $activeMonths.Count
    ZeroTradeMonths     = $zeroTradeMonths.Count
    PositiveMonths      = $positiveMonths.Count
    LosingMonths        = $losingMonths.Count
    FlatMonths          = $flatMonths.Count
    TargetMonths1To3Pct = $targetMonths.Count
    Above3PctMonths     = $aboveTargetMonths.Count
    TotalProfit         = [math]::Round((Get-SumProperty -Items $trades -PropertyName 'NetPnl'), 2)
    AverageMonthlyPct   = if ($returns.Count) { [math]::Round((($returns | Measure-Object -Average).Average), 3) } else { 0 }
    MedianMonthlyPct    = [math]::Round((Get-Median $returns), 3)
    BestMonthPct        = if ($returns.Count) { [math]::Round((($returns | Measure-Object -Maximum).Maximum), 3) } else { 0 }
    WorstMonthPct       = if ($returns.Count) { [math]::Round((($returns | Measure-Object -Minimum).Minimum), 3) } else { 0 }
} | Format-List

'MONTHLY'
$monthly | Format-Table -AutoSize Month, Profit, ReturnPct, Trades, EURUSD, USDJPY, Symbols
