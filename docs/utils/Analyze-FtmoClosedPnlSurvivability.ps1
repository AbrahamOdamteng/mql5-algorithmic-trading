param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [double]$AccountPerSymbol = 100000.0,
    [int]$SymbolCount = 0,
    [double]$DailyLossPct = 5.0,
    [double]$GlobalLossPct = 10.0,
    [double]$ProfitTargetPct = 10.0,

    [ValidateSet('RawPnl', 'NormalizedRisk')]
    [string]$PnlMode = 'RawPnl',
    [double]$StartingBalance = 0.0,
    [double]$OriginalRiskPct = 1.0,
    [double]$CommunalRiskPct = 0.25,

    [ValidateSet('OUT', 'IN', 'ALL')]
    [string]$StartEventType = 'OUT',

    [string]$DetailsPath = '',
    [switch]$Csv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Decode-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-Path -LiteralPath $Path
    $bytes = [System.IO.File]::ReadAllBytes($resolved)

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

function Convert-ToDouble {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return 0.0
    }

    return [double]::Parse($Text, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-Median {
    param([double[]]$Values)

    if ($Values.Count -eq 0) {
        return $null
    }

    $sorted = @($Values | Sort-Object)
    $middle = [int][math]::Floor($sorted.Count / 2)

    if ($sorted.Count % 2 -eq 1) {
        return $sorted[$middle]
    }

    return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}

function Format-NullableNumber {
    param($Value, [int]$Digits = 2)

    if ($null -eq $Value) {
        return 'n/a'
    }

    return ([math]::Round([double]$Value, $Digits)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

$text = Decode-TextFile -Path $CsvPath
$lines = $text -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$rawRows = $lines | ConvertFrom-Csv

if ($rawRows.Count -eq 0) {
    throw "No CSV rows found in $CsvPath"
}

$events = @(
    $rawRows | ForEach-Object {
        $dealTime = [datetime]::ParseExact(
            $_.deal_time,
            'yyyy.MM.dd HH:mm',
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $profit = Convert-ToDouble $_.profit
        $swap = Convert-ToDouble $_.swap
        $commission = Convert-ToDouble $_.commission

        [pscustomobject]@{
            Symbol = [string]$_.symbol
            Ticket = [long]$_.ticket
            EntryType = ([string]$_.entry_type).ToUpperInvariant()
            Direction = [string]$_.direction
            Time = $dealTime
            Day = $dealTime.Date
            Profit = $profit
            Swap = $swap
            Commission = $commission
            NetPnl = $profit + $swap + $commission
        }
    } | Sort-Object Time, Ticket
)

$symbols = @($events | Select-Object -ExpandProperty Symbol -Unique | Sort-Object)
if ($SymbolCount -le 0) {
    $SymbolCount = $symbols.Count
}

$startingBalance = if ($StartingBalance -gt 0.0) { $StartingBalance } else { $AccountPerSymbol * $SymbolCount }
$dailyLossLimit = $startingBalance * ($DailyLossPct / 100.0)
$globalLossLimit = $startingBalance * ($GlobalLossPct / 100.0)
$profitTarget = $startingBalance * ($ProfitTargetPct / 100.0)

$eventsWithR = @($events)
if ($PnlMode -eq 'NormalizedRisk') {
    $symbolBalances = @{}
    foreach ($symbol in $symbols) {
        $symbolBalances[$symbol] = $AccountPerSymbol
    }

    $eventsWithR = @(
        foreach ($event in $events) {
            $rMultiple = 0.0
            if ($event.EntryType -eq 'OUT') {
                $preOutSymbolBalance = [double]$symbolBalances[$event.Symbol]
                $originalRiskAmount = $preOutSymbolBalance * ($OriginalRiskPct / 100.0)
                if ($originalRiskAmount -gt 0.0) {
                    $rMultiple = $event.NetPnl / $originalRiskAmount
                }
                $symbolBalances[$event.Symbol] = $preOutSymbolBalance + $event.NetPnl
            }

            $event | Add-Member -NotePropertyName RMultiple -NotePropertyValue $rMultiple -PassThru
        }
    )
}
else {
    $eventsWithR = @(
        foreach ($event in $events) {
            $event | Add-Member -NotePropertyName RMultiple -NotePropertyValue 0.0 -PassThru
        }
    )
}

$startIndexes = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $events.Count; $i++) {
    if ($StartEventType -eq 'ALL' -or $events[$i].EntryType -eq $StartEventType) {
        [void]$startIndexes.Add($i)
    }
}

if ($startIndexes.Count -eq 0) {
    throw "No start events found for StartEventType=$StartEventType"
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($startIndex in $startIndexes) {
    $startEvent = $eventsWithR[$startIndex]
    $balance = $startingBalance
    $dayStartBalance = $startingBalance
    $currentDay = $startEvent.Day
    $outEventsProcessed = 0
    $maxDailyLossUsedPct = 0.0
    $maxGlobalLossUsedPct = 0.0
    $maxProfitProgressPct = 0.0
    $outcome = 'UNRESOLVED'
    $reason = 'END_OF_DATA'
    $endEvent = $eventsWithR[$eventsWithR.Count - 1]

    for ($j = $startIndex; $j -lt $eventsWithR.Count; $j++) {
        $event = $eventsWithR[$j]

        if ($event.Day -ne $currentDay) {
            $currentDay = $event.Day
            $dayStartBalance = $balance
        }

        if ($event.EntryType -eq 'OUT') {
            if ($PnlMode -eq 'NormalizedRisk') {
                $balance += $event.RMultiple * $balance * ($CommunalRiskPct / 100.0)
            }
            else {
                $balance += $event.NetPnl
            }
            $outEventsProcessed++
        }

        $dailyLoss = [math]::Max(0.0, $dayStartBalance - $balance)
        $globalLoss = [math]::Max(0.0, $startingBalance - $balance)
        $profitProgress = [math]::Max(0.0, $balance - $startingBalance)

        $maxDailyLossUsedPct = [math]::Max($maxDailyLossUsedPct, ($dailyLoss / $dailyLossLimit) * 100.0)
        $maxGlobalLossUsedPct = [math]::Max($maxGlobalLossUsedPct, ($globalLoss / $globalLossLimit) * 100.0)
        $maxProfitProgressPct = [math]::Max($maxProfitProgressPct, ($profitProgress / $profitTarget) * 100.0)

        $hitDailyLoss = $dailyLoss -ge $dailyLossLimit
        $hitGlobalLoss = $globalLoss -ge $globalLossLimit
        $hitProfitTarget = $profitProgress -ge $profitTarget

        if ($hitDailyLoss -or $hitGlobalLoss) {
            $outcome = 'FAIL'
            if ($hitDailyLoss -and $hitGlobalLoss) {
                $reason = 'DAILY_AND_GLOBAL_LOSS'
            }
            elseif ($hitDailyLoss) {
                $reason = 'DAILY_LOSS'
            }
            else {
                $reason = 'GLOBAL_LOSS'
            }
            $endEvent = $event
            break
        }

        if ($hitProfitTarget) {
            $outcome = 'PASS'
            $reason = 'PROFIT_TARGET'
            $endEvent = $event
            break
        }
    }

    $duration = $endEvent.Time - $startEvent.Time
    [void]$results.Add([pscustomobject]@{
        StartIndex = $startIndex
        StartTicket = $startEvent.Ticket
        StartSymbol = $startEvent.Symbol
        StartEventType = $startEvent.EntryType
        StartTime = $startEvent.Time.ToString('yyyy-MM-dd HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
        Outcome = $outcome
        Reason = $reason
        EndTicket = $endEvent.Ticket
        EndSymbol = $endEvent.Symbol
        EndEventType = $endEvent.EntryType
        EndTime = $endEvent.Time.ToString('yyyy-MM-dd HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
        DurationDays = [math]::Round($duration.TotalDays, 2)
        OutEventsProcessed = $outEventsProcessed
        EndingBalance = [math]::Round($balance, 2)
        NetPnl = [math]::Round($balance - $startingBalance, 2)
        MaxDailyLossUsedPct = [math]::Round($maxDailyLossUsedPct, 3)
        MaxGlobalLossUsedPct = [math]::Round($maxGlobalLossUsedPct, 3)
        MaxProfitTargetProgressPct = [math]::Round($maxProfitProgressPct, 3)
    })
}

if (-not [string]::IsNullOrWhiteSpace($DetailsPath)) {
    $results | Export-Csv -NoTypeInformation -Path $DetailsPath -Encoding UTF8
}

if ($Csv) {
    $results | ConvertTo-Csv -NoTypeInformation
    return
}

$passRows = @($results | Where-Object Outcome -eq 'PASS')
$failRows = @($results | Where-Object Outcome -eq 'FAIL')
$unresolvedRows = @($results | Where-Object Outcome -eq 'UNRESOLVED')
$resolvedRows = @($results | Where-Object Outcome -ne 'UNRESOLVED')
$dailyFailRows = @($results | Where-Object { $_.Reason -eq 'DAILY_LOSS' -or $_.Reason -eq 'DAILY_AND_GLOBAL_LOSS' })
$globalFailRows = @($results | Where-Object { $_.Reason -eq 'GLOBAL_LOSS' -or $_.Reason -eq 'DAILY_AND_GLOBAL_LOSS' })

$passRate = ($passRows.Count / $results.Count) * 100.0
$resolvedPassRate = if ($resolvedRows.Count -gt 0) { ($passRows.Count / $resolvedRows.Count) * 100.0 } else { $null }
$failRate = ($failRows.Count / $results.Count) * 100.0
$unresolvedRate = ($unresolvedRows.Count / $results.Count) * 100.0

Write-Output "Closed-PnL FTMO Survivability Analysis"
Write-Output "CSV: $CsvPath"
Write-Output "Symbols ($($symbols.Count)): $($symbols -join ', ')"
Write-Output "SymbolCountUsed: $SymbolCount"
Write-Output "StartingBalance: $([math]::Round($startingBalance, 2))"
Write-Output "PnlMode: $PnlMode"
if ($PnlMode -eq 'NormalizedRisk') {
    Write-Output "OriginalRiskPct: $OriginalRiskPct"
    Write-Output "CommunalRiskPct: $CommunalRiskPct"
}
Write-Output "DailyLossLimit: $([math]::Round($dailyLossLimit, 2)) ($DailyLossPct%)"
Write-Output "GlobalLossLimit: $([math]::Round($globalLossLimit, 2)) ($GlobalLossPct%)"
Write-Output "ProfitTarget: $([math]::Round($profitTarget, 2)) ($ProfitTargetPct%)"
Write-Output "StartEventType: $StartEventType"
Write-Output ""
Write-Output "Runs: $($results.Count)"
Write-Output "Pass: $($passRows.Count) ($(Format-NullableNumber $passRate 2)%)"
Write-Output "Fail: $($failRows.Count) ($(Format-NullableNumber $failRate 2)%)"
Write-Output "Unresolved: $($unresolvedRows.Count) ($(Format-NullableNumber $unresolvedRate 2)%)"
Write-Output "ResolvedPassRate: $(Format-NullableNumber $resolvedPassRate 2)%"
Write-Output "DailyLossFailures: $($dailyFailRows.Count)"
Write-Output "GlobalLossFailures: $($globalFailRows.Count)"
Write-Output ""
Write-Output "MedianPassDays: $(Format-NullableNumber (Get-Median @($passRows | Select-Object -ExpandProperty DurationDays)) 2)"
Write-Output "MedianPassOutEvents: $(Format-NullableNumber (Get-Median @($passRows | Select-Object -ExpandProperty OutEventsProcessed)) 2)"
Write-Output "MedianFailDays: $(Format-NullableNumber (Get-Median @($failRows | Select-Object -ExpandProperty DurationDays)) 2)"
Write-Output "MedianFailOutEvents: $(Format-NullableNumber (Get-Median @($failRows | Select-Object -ExpandProperty OutEventsProcessed)) 2)"
Write-Output "MedianMaxDailyLossUsedPct: $(Format-NullableNumber (Get-Median @($results | Select-Object -ExpandProperty MaxDailyLossUsedPct)) 2)"
Write-Output "MedianMaxGlobalLossUsedPct: $(Format-NullableNumber (Get-Median @($results | Select-Object -ExpandProperty MaxGlobalLossUsedPct)) 2)"
Write-Output "MedianMaxProfitTargetProgressPct: $(Format-NullableNumber (Get-Median @($results | Select-Object -ExpandProperty MaxProfitTargetProgressPct)) 2)"
Write-Output ""
Write-Output "OutcomeByReason:"
$results | Group-Object Reason | Sort-Object Count -Descending | ForEach-Object {
    Write-Output ("  {0}: {1}" -f $_.Name, $_.Count)
}

if (-not [string]::IsNullOrWhiteSpace($DetailsPath)) {
    Write-Output ""
    Write-Output "DetailsPath: $DetailsPath"
}
