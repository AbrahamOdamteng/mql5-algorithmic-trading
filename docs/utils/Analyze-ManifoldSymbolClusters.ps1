param(
    [Parameter(Mandatory = $true)]
    [string]$ReportsDir,

    [string]$Pattern = '*.xml.htm',
    [string[]]$Segments = @('VAL', 'OOS'),
    [ValidateSet('ProfitableAll', 'AcceptedAll', 'AnyReport')]
    [string]$SymbolMode = 'ProfitableAll',
    [int]$MinGroupSize = 2,
    [int]$MaxGroupSize = 4,
    [double]$MinRatio = 2.0,
    [double]$MaxDrawdownPct = 30.0,
    [double]$StartingDeposit = 100000.0,
    [int]$Top = 50,
    [switch]$Csv
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

function Get-ReportIdentity {
    param([Parameter(Mandatory = $true)][string]$Name)

    $symbol = if ($Name -match '^([^_]+)_') { $Matches[1] } else { $null }
    $segment = if ($Name -match '_(IS|VAL|OOS)_') { $Matches[1] } else { $null }
    $pass = if ($Name -match 'Pass(\d+)') { $Matches[1] } else { $null }
    $run = if ($Name -match '_(RUN\d+)_Pass') { $Matches[1] } else { $null }
    $manifold = if ($run) { "$run`_Pass$pass" } elseif ($pass) { "Pass$pass" } else { $null }

    return [pscustomobject]@{
        Symbol   = $symbol
        Segment  = $segment
        Manifold = $manifold
    }
}

function Get-Combinations {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [Parameter(Mandatory = $true)][int]$Size,
        [int]$Start = 0,
        [object[]]$Prefix = @()
    )

    if ($Prefix.Count -eq $Size) {
        return , [pscustomobject]@{ Items = @($Prefix) }
    }

    $results = @()
    $remainingNeeded = $Size - $Prefix.Count
    $lastStart = $Items.Count - $remainingNeeded

    for ($i = $Start; $i -le $lastStart; $i++) {
        $nextPrefix = @($Prefix) + $Items[$i]
        $results += Get-Combinations -Items $Items -Size $Size -Start ($i + 1) -Prefix $nextPrefix
    }

    return $results
}

if ($MinGroupSize -lt 1) {
    throw 'MinGroupSize must be at least 1.'
}
if ($MaxGroupSize -lt $MinGroupSize) {
    throw 'MaxGroupSize must be greater than or equal to MinGroupSize.'
}

$requestedSegments = @($Segments | ForEach-Object { $_ -split ',' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().ToUpperInvariant() })
$files = @(Get-ChildItem -LiteralPath $ReportsDir -Filter $Pattern -File)
$rows = @()

foreach ($file in $files) {
    $identity = Get-ReportIdentity -Name $file.Name
    if (-not $identity.Symbol -or -not $identity.Segment -or -not $identity.Manifold) {
        continue
    }
    if ($requestedSegments -notcontains $identity.Segment) {
        continue
    }

    $html = Decode-Report -Path $file.FullName
    $profit = Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Net Profit')
    $equityDdMaxText = Get-ReportMetric -Html $html -Label 'Equity Drawdown Maximal'
    $equityDdRelText = Get-ReportMetric -Html $html -Label 'Equity Drawdown Relative'
    $ddPct = $null

    if ($equityDdMaxText -match '\(([-0-9.,\s]+)%\)') {
        $ddPct = Convert-Mt5Number $Matches[1]
    }
    elseif ($equityDdRelText -match '([-0-9.,\s]+)%') {
        $ddPct = Convert-Mt5Number $Matches[1]
    }

    $ratio = if ($null -ne $ddPct -and $ddPct -ne 0) {
        [Math]::Round(($profit / ($StartingDeposit / 100.0)) / $ddPct, 3)
    }
    else {
        $null
    }

    $accepted = $profit -gt 0 -and $ratio -ge $MinRatio -and $ddPct -le $MaxDrawdownPct

    $rows += [pscustomobject]@{
        Manifold    = $identity.Manifold
        Symbol      = $identity.Symbol
        Segment     = $identity.Segment
        Profit      = [Math]::Round($profit, 2)
        EquityDDPct = [Math]::Round($ddPct, 2)
        Ratio       = $ratio
        Trades      = [int](Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Trades'))
        Accepted    = $accepted
        File        = $file.Name
    }
}

$symbolRows = @()
foreach ($group in ($rows | Group-Object Manifold, Symbol)) {
    $groupRows = @($group.Group)
    $presentSegments = @($groupRows.Segment | Sort-Object -Unique)
    $hasAllSegments = @($requestedSegments | Where-Object { $presentSegments -notcontains $_ }).Count -eq 0

    if (-not $hasAllSegments) {
        continue
    }

    $profitableRows = @($groupRows | Where-Object { $_.Profit -gt 0 }).Count
    $acceptedRows = @($groupRows | Where-Object { $_.Accepted }).Count
    $rowCount = $groupRows.Count
    $includeSymbol = $false

    if ($SymbolMode -eq 'AnyReport') {
        $includeSymbol = $true
    }
    elseif ($SymbolMode -eq 'ProfitableAll') {
        $includeSymbol = $profitableRows -eq $rowCount
    }
    elseif ($SymbolMode -eq 'AcceptedAll') {
        $includeSymbol = $acceptedRows -eq $rowCount
    }

    if (-not $includeSymbol) {
        continue
    }

    $totalProfit = ($groupRows | Measure-Object Profit -Sum).Sum
    $totalTrades = ($groupRows | Measure-Object Trades -Sum).Sum
    $maxDd = ($groupRows | Measure-Object EquityDDPct -Maximum).Maximum
    $minRatioValue = ($groupRows | Measure-Object Ratio -Minimum).Minimum
    $avgRatio = ($groupRows | Measure-Object Ratio -Average).Average
    $minTrades = ($groupRows | Measure-Object Trades -Minimum).Minimum

    $symbolRows += [pscustomobject]@{
        Manifold       = $groupRows[0].Manifold
        Symbol         = $groupRows[0].Symbol
        Segments       = ($presentSegments -join '+')
        RowCount       = $rowCount
        AcceptedRows   = $acceptedRows
        ProfitableRows = $profitableRows
        TotalProfit    = [Math]::Round($totalProfit, 2)
        TotalTrades    = [int]$totalTrades
        MaxDDPct       = [Math]::Round($maxDd, 2)
        MinRatio       = [Math]::Round($minRatioValue, 3)
        AvgRatio       = [Math]::Round($avgRatio, 3)
        MinTrades      = [int]$minTrades
    }
}

$clusters = @()
foreach ($manifoldGroup in ($symbolRows | Group-Object Manifold)) {
    $symbols = @($manifoldGroup.Group | Sort-Object Symbol)
    if ($symbols.Count -lt $MinGroupSize) {
        continue
    }

    $maxSize = [Math]::Min($MaxGroupSize, $symbols.Count)
    for ($size = $MinGroupSize; $size -le $maxSize; $size++) {
        foreach ($combo in (Get-Combinations -Items $symbols -Size $size)) {
            $comboRows = @($combo.Items)
            $profit = ($comboRows | Measure-Object TotalProfit -Sum).Sum
            $positiveProfit = ($comboRows | Where-Object { $_.TotalProfit -gt 0 } | Measure-Object TotalProfit -Sum).Sum
            $largestSymbolProfit = ($comboRows | Measure-Object TotalProfit -Maximum).Maximum
            $concentrationPct = if ($positiveProfit -gt 0) { ($largestSymbolProfit / $positiveProfit) * 100.0 } else { $null }
            $totalTrades = ($comboRows | Measure-Object TotalTrades -Sum).Sum
            $maxDd = ($comboRows | Measure-Object MaxDDPct -Maximum).Maximum
            $minRatioValue = ($comboRows | Measure-Object MinRatio -Minimum).Minimum
            $avgRatio = ($comboRows | Measure-Object AvgRatio -Average).Average
            $acceptedRows = ($comboRows | Measure-Object AcceptedRows -Sum).Sum
            $rowCount = ($comboRows | Measure-Object RowCount -Sum).Sum
            $minTrades = ($comboRows | Measure-Object MinTrades -Minimum).Minimum

            $clusters += [pscustomobject]@{
                Manifold              = $comboRows[0].Manifold
                GroupSize             = $size
                Symbols               = (($comboRows | Select-Object -ExpandProperty Symbol | Sort-Object) -join '+')
                Segments              = ($requestedSegments -join '+')
                TotalProfit           = [Math]::Round($profit, 2)
                TotalTrades           = [int]$totalTrades
                RowCount              = [int]$rowCount
                AcceptedRows          = [int]$acceptedRows
                AcceptedRowPct        = [Math]::Round(($acceptedRows / $rowCount) * 100.0, 2)
                MaxDDPct              = [Math]::Round($maxDd, 2)
                MinRatio              = [Math]::Round($minRatioValue, 3)
                AvgRatio              = [Math]::Round($avgRatio, 3)
                MinTrades             = [int]$minTrades
                LargestSymbolProfitPct = if ($null -ne $concentrationPct) { [Math]::Round($concentrationPct, 2) } else { $null }
            }
        }
    }
}

$ranked = @($clusters | Sort-Object @{ Expression = 'GroupSize'; Descending = $true }, @{ Expression = 'AcceptedRowPct'; Descending = $true }, @{ Expression = 'MinRatio'; Descending = $true }, @{ Expression = 'TotalProfit'; Descending = $true })

if ($Csv) {
    $ranked | ConvertTo-Csv -NoTypeInformation
    exit 0
}

'COUNTS'
[pscustomobject]@{
    ReportsParsed   = $rows.Count
    Manifolds       = @($rows | Select-Object -ExpandProperty Manifold -Unique).Count
    EligibleSymbols = $symbolRows.Count
    Clusters        = $clusters.Count
    Segments        = ($requestedSegments -join '+')
    SymbolMode      = $SymbolMode
} | Format-List

'TOP_SYMBOL_CLUSTERS'
$ranked |
    Select-Object -First $Top |
    Format-Table -AutoSize Manifold, GroupSize, Symbols, TotalProfit, TotalTrades, AcceptedRows, AcceptedRowPct, MaxDDPct, MinRatio, AvgRatio, MinTrades, LargestSymbolProfitPct

'ELIGIBLE_SYMBOLS'
$symbolRows |
    Sort-Object Manifold, Symbol |
    Format-Table -AutoSize Manifold, Symbol, TotalProfit, TotalTrades, AcceptedRows, RowCount, MaxDDPct, MinRatio, AvgRatio, MinTrades
