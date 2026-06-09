param(
    [Parameter(Mandatory = $true)]
    [string]$OptimizerXml,

    [Parameter(Mandatory = $true)]
    [string]$ForwardXml,

    [double]$MinRatio = 2.0,
    [double]$MaxDrawdownPct = 30.0,
    [int]$StrictMinInSampleTrades = 200,
    [int]$StrictMinForwardTrades = 100,
    [int]$LooseMinInSampleTrades = 50,
    [int]$LooseMinForwardTrades = 25,
    [int]$Top = 20,
    [switch]$Csv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Mt5Spreadsheet {
    param([Parameter(Mandatory = $true)][string]$Path)

    [xml]$xml = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    $nsm = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
    $nsm.AddNamespace('ss', 'urn:schemas-microsoft-com:office:spreadsheet')

    $rows = $xml.SelectNodes('//ss:Worksheet/ss:Table/ss:Row', $nsm)
    if ($rows.Count -lt 2) {
        return @()
    }

    $headers = @()
    foreach ($cell in $rows[0].SelectNodes('ss:Cell', $nsm)) {
        $headers += $cell.SelectSingleNode('ss:Data', $nsm).InnerText
    }

    $result = @()
    for ($i = 1; $i -lt $rows.Count; $i++) {
        $cells = $rows[$i].SelectNodes('ss:Cell', $nsm)
        $obj = [ordered]@{}

        for ($j = 0; $j -lt $headers.Count; $j++) {
            $text = $cells[$j].SelectSingleNode('ss:Data', $nsm).InnerText
            $num = 0.0

            if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
                $obj[$headers[$j]] = $num
            }
            else {
                $obj[$headers[$j]] = $text
            }
        }

        $result += [pscustomobject]$obj
    }

    return $result
}

function Get-PropValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }

    return $Default
}

$opt = @(Read-Mt5Spreadsheet -Path $OptimizerXml)
$fwd = @(Read-Mt5Spreadsheet -Path $ForwardXml)

$optByPass = @{}
foreach ($row in $opt) {
    $optByPass[[int]$row.Pass] = $row
}

$pairs = @()
foreach ($fr in $fwd) {
    $pass = [int]$fr.Pass
    if (-not $optByPass.ContainsKey($pass)) {
        continue
    }

    $or = $optByPass[$pass]
    $isDd = [double]$or.'Equity DD %'
    $fwdDd = [double]$fr.'Equity DD %'
    $isProfit = [double]$or.Profit
    $fwdProfit = [double]$fr.Profit
    $isRatio = if ($isDd -gt 0) { $isProfit / 1000.0 / $isDd } else { [double]::PositiveInfinity }
    $fwdRatio = if ($fwdDd -gt 0) { $fwdProfit / 1000.0 / $fwdDd } else { [double]::PositiveInfinity }

    $pairs += [pscustomobject]@{
        Pass                = $pass
        MinRatio            = [Math]::Round([Math]::Min($isRatio, $fwdRatio), 3)
        ISProfit            = [Math]::Round($isProfit, 2)
        ISDD                = [Math]::Round($isDd, 2)
        ISRatio             = [Math]::Round($isRatio, 2)
        ISTrades            = [int]$or.Trades
        FwdProfit           = [Math]::Round($fwdProfit, 2)
        FwdDD               = [Math]::Round($fwdDd, 2)
        FwdRatio            = [Math]::Round($fwdRatio, 2)
        FwdTrades           = [int]$fr.Trades
        ISProfitFactor      = [Math]::Round([double]$or.'Profit Factor', 2)
        FwdProfitFactor     = [Math]::Round([double]$fr.'Profit Factor', 2)
        HighLowPeriod       = Get-PropValue -Object $fr -Name 'g_HighLowPeriod'
        MinCluster          = [int](Get-PropValue -Object $fr -Name 'g_MinClusterSize')
        ClusterMult         = Get-PropValue -Object $fr -Name 'g_ATR_Cluster_multiplier'
        StopLossMult        = Get-PropValue -Object $fr -Name 'g_ATR_StopLoss_multiplier'
        ImpulseLookback     = [int](Get-PropValue -Object $fr -Name 'g_impulse_lookback_hours')
        PullbackLookforward = [int](Get-PropValue -Object $fr -Name 'g_pullback_lookforward_hours')
        ImpulseMult         = Get-PropValue -Object $fr -Name 'g_Impulse_ATR_multiplier'
        PullbackMult        = Get-PropValue -Object $fr -Name 'g_MinPullback_ATR_multiplier'
        TP                  = [int](Get-PropValue -Object $fr -Name 'g_TakeProfitMultiplier')
    }
}

$positive = @($pairs | Where-Object { $_.ISProfit -gt 0 -and $_.FwdProfit -gt 0 })
$ratio = @($positive | Where-Object { $_.ISRatio -gt $MinRatio -and $_.FwdRatio -gt $MinRatio })
$ddcap = @($ratio | Where-Object { $_.ISDD -le $MaxDrawdownPct -and $_.FwdDD -le $MaxDrawdownPct })
$strict = @($ddcap | Where-Object { $_.ISTrades -ge $StrictMinInSampleTrades -and $_.FwdTrades -ge $StrictMinForwardTrades })
$loose = @($ddcap | Where-Object { $_.ISTrades -ge $LooseMinInSampleTrades -and $_.FwdTrades -ge $LooseMinForwardTrades })

if ($Csv) {
    $loose | Sort-Object MinRatio -Descending | ConvertTo-Csv -NoTypeInformation
    exit 0
}

'COUNTS'
[pscustomobject]@{
    OptimizerRows           = $opt.Count
    ForwardRows             = $fwd.Count
    PairedRows              = $pairs.Count
    PositiveProfitPairs     = $positive.Count
    RatioQualified          = $ratio.Count
    AfterDrawdownCap        = $ddcap.Count
    AfterStrictTradeFilter  = $strict.Count
    AfterLooseTradeFilter   = $loose.Count
} | Format-List

'TOP_AFTER_DRAWDOWN_CAP'
$ddcap |
    Sort-Object MinRatio -Descending |
    Select-Object -First $Top |
    Format-Table -AutoSize Pass, MinRatio, ISProfit, ISDD, ISRatio, ISTrades, FwdProfit, FwdDD, FwdRatio, FwdTrades, FwdProfitFactor, MinCluster, ClusterMult, StopLossMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP

'STRICT_TRADE_CANDIDATES'
$strict |
    Sort-Object MinRatio -Descending |
    Select-Object -First $Top |
    Format-Table -AutoSize Pass, MinRatio, ISProfit, ISDD, ISRatio, ISTrades, FwdProfit, FwdDD, FwdRatio, FwdTrades, FwdProfitFactor, MinCluster, ClusterMult, StopLossMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP

'LOOSE_TRADE_CANDIDATES'
$loose |
    Sort-Object MinRatio -Descending |
    Select-Object -First $Top |
    Format-Table -AutoSize Pass, MinRatio, ISProfit, ISDD, ISRatio, ISTrades, FwdProfit, FwdDD, FwdRatio, FwdTrades, FwdProfitFactor, MinCluster, ClusterMult, StopLossMult, ImpulseLookback, PullbackLookforward, ImpulseMult, PullbackMult, TP
