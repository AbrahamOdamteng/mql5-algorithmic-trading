param(
    [Parameter(Mandatory = $true)]
    [string]$ReportsDir,

    [string]$Pattern = '*_OOS_*.xml.htm',
    [double]$MinRatio = 2.0,
    [double]$MaxDrawdownPct = 30.0,
    [double]$StartingDeposit = 100000.0,
    [int]$Top = 20,
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

function Get-InputValue {
    param(
        [Parameter(Mandatory = $true)][string]$Html,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = [regex]::Escape($Name) + '=(.*?)</b>'
    $match = [regex]::Match($Html, $pattern)
    if ($match.Success) {
        return Clean-HtmlText $match.Groups[1].Value
    }

    return $null
}

function Get-PassFromFileName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $match = [regex]::Match($Name, 'Pass(\d+)')
    if ($match.Success) {
        return [int]$match.Groups[1].Value
    }

    return $null
}

$files = @(Get-ChildItem -LiteralPath $ReportsDir -Filter $Pattern -File)
$results = @()

foreach ($file in $files) {
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

    $results += [pscustomobject]@{
        Pass                = Get-PassFromFileName -Name $file.Name
        Profit              = [Math]::Round($profit, 2)
        EquityDDPct         = [Math]::Round($ddPct, 2)
        Ratio               = $ratio
        Trades              = [int](Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Trades'))
        ProfitFactor        = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Profit Factor')), 2)
        Recovery            = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Recovery Factor')), 2)
        Sharpe              = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Sharpe Ratio')), 2)
        GrossProfit         = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Gross Profit')), 2)
        GrossLoss           = [Math]::Round((Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Gross Loss')), 2)
        HighLowPeriod       = Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_HighLowPeriod')
        MinCluster          = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_MinClusterSize'))
        ClusterMult         = Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_ATR_Cluster_multiplier')
        ImpulseLookback     = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_impulse_lookback_hours'))
        PullbackLookforward = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_pullback_lookforward_hours'))
        ImpulseMult         = Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_Impulse_ATR_multiplier')
        PullbackMult        = Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_MinPullback_ATR_multiplier')
        TP                  = [int](Convert-Mt5Number (Get-InputValue -Html $html -Name 'g_TakeProfitMultiplier'))
        File                = $file.Name
    }
}

$accepted = @($results | Where-Object { $_.Profit -gt 0 -and $_.Ratio -gt $MinRatio -and $_.EquityDDPct -le $MaxDrawdownPct })

if ($Csv) {
    $results | Sort-Object Ratio -Descending | ConvertTo-Csv -NoTypeInformation
    exit 0
}

'COUNTS'
[pscustomobject]@{
    ReportsParsed    = $results.Count
    Profitable       = @($results | Where-Object { $_.Profit -gt 0 }).Count
    RatioQualified   = @($results | Where-Object { $_.Profit -gt 0 -and $_.Ratio -gt $MinRatio }).Count
    DrawdownUnderCap = @($results | Where-Object { $_.EquityDDPct -le $MaxDrawdownPct }).Count
    Accepted         = $accepted.Count
} | Format-List

'ACCEPTED'
$accepted |
    Sort-Object Ratio -Descending |
    Format-Table -AutoSize Pass, Profit, EquityDDPct, Ratio, Trades, ProfitFactor, Recovery, Sharpe, MinCluster, ClusterMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP

'TOP_PROFITABLE_BY_RATIO'
$results |
    Where-Object { $_.Profit -gt 0 } |
    Sort-Object Ratio -Descending |
    Select-Object -First $Top |
    Format-Table -AutoSize Pass, Profit, EquityDDPct, Ratio, Trades, ProfitFactor, Recovery, Sharpe, MinCluster, ClusterMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP
