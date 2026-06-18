param(
    [string]$CommonFilesDir = "$env:APPDATA\MetaQuotes\Terminal\Common\Files",
    [string]$Pattern = 'manifold_trades_Pair_EURUSD*_USDJPY*_FundedOOS.csv',
    [double]$StartingDeposit = 100000.0,
    [double]$TargetRiskPct = [double]::NaN,
    [string]$FromMonth = '2018-01',
    [string]$ToMonth = '2026-05',
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

$firstMonth = Convert-MonthStart $FromMonth
$lastMonth = Convert-MonthStart $ToMonth
if ($lastMonth -lt $firstMonth) {
    throw "ToMonth '$ToMonth' is before FromMonth '$FromMonth'."
}

$monthKeys = @()
$cursor = $firstMonth
while ($cursor -le $lastMonth) {
    $monthKeys += $cursor.ToString('yyyy-MM')
    $cursor = $cursor.AddMonths(1)
}

$files = @(Get-ChildItem -LiteralPath $CommonFilesDir -Filter $Pattern -File)
if ($files.Count -eq 0) {
    throw "No pair matrix CSV files found in '$CommonFilesDir' matching '$Pattern'."
}

$summary = foreach ($file in $files) {
    $match = [regex]::Match($file.Name, 'Pair_EURUSD(?<EURUSD>\d+)_USDJPY(?<USDJPY>\d+)_FundedOOS')
    $eurusdPass = if ($match.Success) { [int]$match.Groups['EURUSD'].Value } else { $null }
    $usdjpyPass = if ($match.Success) { [int]$match.Groups['USDJPY'].Value } else { $null }

    $rows = @(Import-Csv -LiteralPath $file.FullName)
    $closedRows = @($rows | Where-Object { $_.entry_type -eq 'OUT' })
    $trades = foreach ($row in $closedRows) {
        $riskPct = Convert-Number $row.risk_percentage
        $scale = 1.0

        if (-not [double]::IsNaN($TargetRiskPct)) {
            if ($riskPct -le 0) {
                throw "Row has non-positive risk_percentage and cannot be scaled in $($file.Name): trade_id=$($row.trade_id)"
            }

            $scale = $TargetRiskPct / $riskPct
        }

        $dealTime = Convert-DealTime $row.deal_time
        $netPnl = ((Convert-Number $row.profit) + (Convert-Number $row.swap) + (Convert-Number $row.commission)) * $scale

        [pscustomobject]@{
            Month  = $dealTime.ToString('yyyy-MM')
            Symbol = $row.symbol
            NetPnl = $netPnl
        }
    }

    $monthly = foreach ($month in $monthKeys) {
        $monthTrades = @($trades | Where-Object { $_.Month -eq $month })
        $profit = Get-SumProperty -Items $monthTrades -PropertyName 'NetPnl'

        [pscustomobject]@{
            Month     = $month
            Profit    = $profit
            ReturnPct = ($profit / $StartingDeposit) * 100.0
            Trades    = $monthTrades.Count
        }
    }

    $returns = @($monthly | ForEach-Object { [double]$_.ReturnPct })

    [pscustomobject]@{
        EurUsdPass          = $eurusdPass
        UsdJpyPass          = $usdjpyPass
        ClosedTrades        = $trades.Count
        PositiveMonths      = @($monthly | Where-Object { [double]$_.Profit -gt 0 }).Count
        LosingMonths        = @($monthly | Where-Object { [double]$_.Profit -lt 0 }).Count
        FlatMonths          = @($monthly | Where-Object { [double]$_.Profit -eq 0 }).Count
        TargetMonths1To3Pct = @($monthly | Where-Object { [double]$_.ReturnPct -ge 1.0 -and [double]$_.ReturnPct -le 3.0 }).Count
        Above3PctMonths     = @($monthly | Where-Object { [double]$_.ReturnPct -gt 3.0 }).Count
        TotalProfit         = [math]::Round((Get-SumProperty -Items $trades -PropertyName 'NetPnl'), 2)
        AverageMonthlyPct   = [math]::Round((($returns | Measure-Object -Average).Average), 3)
        MedianMonthlyPct    = [math]::Round((Get-Median $returns), 3)
        BestMonthPct        = [math]::Round((($returns | Measure-Object -Maximum).Maximum), 3)
        WorstMonthPct       = [math]::Round((($returns | Measure-Object -Minimum).Minimum), 3)
        File                = $file.Name
    }
}

$ranked = @(
    $summary |
        Sort-Object @{ Expression = 'WorstMonthPct'; Descending = $true }, @{ Expression = 'AverageMonthlyPct'; Descending = $true }, @{ Expression = 'TargetMonths1To3Pct'; Descending = $true }
)

if ($Csv) {
    $ranked | ConvertTo-Csv -NoTypeInformation
    exit 0
}

'PAIR_MATRIX_MONTHLY_RANK'
$ranked | Format-Table -AutoSize EurUsdPass, UsdJpyPass, ClosedTrades, AverageMonthlyPct, MedianMonthlyPct, WorstMonthPct, BestMonthPct, PositiveMonths, LosingMonths, TargetMonths1To3Pct, Above3PctMonths, TotalProfit
