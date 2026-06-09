param(
    [Parameter(Mandatory = $true)]
    [string]$ReportsDir,

    [string]$Pattern = "*_OOS_*.xml.htm",
    [double]$MinRatio = 2.0,
    [double]$MaxDrawdownPct = 30.0,
    [double]$StartingDeposit = 100000.0,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    $value = $value -replace "<[^>]+>", " "
    $value = $value -replace "\s+", " "
    return $value.Trim()
}

function Convert-Mt5Number {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $match = [regex]::Match($Text, "-?[0-9][0-9\s]*([.,][0-9]+)?")
    if (-not $match.Success) {
        return $null
    }

    $number = $match.Value -replace "\s", ""
    $number = $number -replace ",", "."
    return [double]::Parse($number, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-ReportMetric {
    param(
        [Parameter(Mandatory = $true)][string]$Html,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $pattern = [regex]::Escape($Label) + ":</td>\s*<td[^>]*>\s*<b>(.*?)</b>"
    $match = [regex]::Match($Html, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) {
        return Clean-HtmlText $match.Groups[1].Value
    }

    return $null
}

function Get-InputValue {
    param(
        [Parameter(Mandatory = $true)][string]$Html,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = [regex]::Escape($Name) + "=(.*?)</b>"
    $match = [regex]::Match($Html, $pattern)
    if ($match.Success) {
        return Clean-HtmlText $match.Groups[1].Value
    }

    return $null
}

function Get-PassFromFileName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $match = [regex]::Match($Name, "Pass(\d+)")
    if ($match.Success) {
        return [int]$match.Groups[1].Value
    }

    return $null
}

function Get-RunFromFileName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $match = [regex]::Match($Name, "_(RUN\d+)_")
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

$dir = Resolve-Path -LiteralPath $ReportsDir
$files = @(Get-ChildItem -LiteralPath $dir -Filter $Pattern -File)
$results = @()

foreach ($file in $files) {
    $html = Decode-Report -Path $file.FullName
    $profit = Convert-Mt5Number (Get-ReportMetric -Html $html -Label "Total Net Profit")
    $equityDdMaxText = Get-ReportMetric -Html $html -Label "Equity Drawdown Maximal"
    $equityDdRelText = Get-ReportMetric -Html $html -Label "Equity Drawdown Relative"
    $ddPct = $null

    if ($equityDdMaxText -match "\(([-0-9.,\s]+)%\)") {
        $ddPct = Convert-Mt5Number $Matches[1]
    }
    elseif ($equityDdRelText -match "([-0-9.,\s]+)%") {
        $ddPct = Convert-Mt5Number $Matches[1]
    }

    $ratio = if ($null -ne $ddPct -and $ddPct -ne 0) {
        [Math]::Round(($profit / ($StartingDeposit / 100.0)) / $ddPct, 3)
    }
    else {
        $null
    }

    $accepted = $profit -gt 0 -and $ratio -gt $MinRatio -and $ddPct -le $MaxDrawdownPct

    $results += [pscustomobject]@{
        Run                 = Get-RunFromFileName -Name $file.Name
        Pass                = Get-PassFromFileName -Name $file.Name
        Accepted            = $accepted
        Profit              = [Math]::Round($profit, 2)
        EquityDDPct         = [Math]::Round($ddPct, 2)
        Ratio               = $ratio
        Trades              = [int](Convert-Mt5Number (Get-ReportMetric -Html $html -Label "Total Trades"))
        ProfitFactor        = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label "Profit Factor")), 2)
        Recovery            = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label "Recovery Factor")), 2)
        Sharpe              = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label "Sharpe Ratio")), 2)
        MinCluster          = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name "g_MinClusterSize"))
        ClusterMult         = Convert-Mt5Number (Get-InputValue -Html $html -Name "g_ATR_Cluster_multiplier")
        StopLossMult        = Convert-Mt5Number (Get-InputValue -Html $html -Name "g_ATR_StopLoss_multiplier")
        ImpulseLookback     = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name "g_impulse_lookback_hours"))
        PullbackLookforward = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name "g_pullback_lookforward_hours"))
        ImpulseMult         = Convert-Mt5Number (Get-InputValue -Html $html -Name "g_Impulse_ATR_multiplier")
        PullbackMult        = Convert-Mt5Number (Get-InputValue -Html $html -Name "g_MinPullback_ATR_multiplier")
        TP                  = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name "g_TakeProfitMultiplier"))
        File                = $file.Name
        FullName            = $file.FullName
    }
}

$acceptedResults = @($results | Where-Object { $_.Accepted } | Sort-Object Ratio -Descending)
$failedResults = @($results | Where-Object { -not $_.Accepted } | Sort-Object Run, Pass)

$acceptedCsvPath = Join-Path $dir "accepted_oos_candidates.csv"
$deletedCsvPath = Join-Path $dir "deleted_failed_oos_candidates.csv"
$acceptedResults | Select-Object Run, Pass, Profit, EquityDDPct, Ratio, Trades, ProfitFactor, Recovery, Sharpe, MinCluster, ClusterMult, StopLossMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP, File |
    Export-Csv -LiteralPath $acceptedCsvPath -NoTypeInformation -Encoding ASCII
$failedResults | Select-Object Run, Pass, Profit, EquityDDPct, Ratio, Trades, ProfitFactor, Recovery, Sharpe, File |
    Export-Csv -LiteralPath $deletedCsvPath -NoTypeInformation -Encoding ASCII

$filesDeleted = 0
foreach ($failed in $failedResults) {
    $reportBaseName = $failed.File -replace "\.htm$", ""
    $sidecars = @(Get-ChildItem -LiteralPath $dir -Filter "$reportBaseName*" -File)
    foreach ($sidecar in $sidecars) {
        if ($WhatIf) {
            continue
        }

        Remove-Item -LiteralPath $sidecar.FullName -Force
        $filesDeleted++
    }
}

[pscustomobject]@{
    ReportsParsed         = $results.Count
    Accepted              = $acceptedResults.Count
    Failed                = $failedResults.Count
    FilesDeleted          = $filesDeleted
    AcceptedCsv           = $acceptedCsvPath
    DeletedFailedAuditCsv = $deletedCsvPath
    WhatIf                = [bool]$WhatIf
} | Format-List

"ACCEPTED_BY_RUN"
$acceptedResults | Group-Object Run | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Run = $_.Name; Count = $_.Count }
} | Format-Table -AutoSize

"TOP_ACCEPTED"
$acceptedResults |
    Select-Object -First 20 Run, Pass, Profit, EquityDDPct, Ratio, Trades, ProfitFactor, Recovery, Sharpe, MinCluster, ClusterMult, StopLossMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP |
    Format-Table -AutoSize
