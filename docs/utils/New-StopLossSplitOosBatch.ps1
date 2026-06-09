param(
    [string]$ResultsDir = ".\docs\results\StopLossSplit",
    [string]$ProfilesDir = ".\Profiles\Tester",
    [string]$ConfigDir = ".\Files\WeekHighLow",
    [string]$Symbol = "EURUSD",
    [string]$FromDate = "2018.01.01",
    [string]$ToDate = "2026.05.31",
    [string]$ReportDate = "20260608",
    [double]$MinRatio = 2.0,
    [double]$MaxDrawdownPct = 30.0,
    [int]$StrictMinInSampleTrades = 200,
    [int]$StrictMinForwardTrades = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Mt5Spreadsheet {
    param([Parameter(Mandatory = $true)][string]$Path)

    [xml]$xml = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    $nsm = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
    $nsm.AddNamespace("ss", "urn:schemas-microsoft-com:office:spreadsheet")

    $rows = $xml.SelectNodes("//ss:Worksheet/ss:Table/ss:Row", $nsm)
    if ($rows.Count -lt 2) {
        return @()
    }

    $headers = @()
    foreach ($cell in $rows[0].SelectNodes("ss:Cell", $nsm)) {
        $headers += $cell.SelectSingleNode("ss:Data", $nsm).InnerText
    }

    $result = @()
    for ($i = 1; $i -lt $rows.Count; $i++) {
        $cells = $rows[$i].SelectNodes("ss:Cell", $nsm)
        $obj = [ordered]@{}

        for ($j = 0; $j -lt $headers.Count; $j++) {
            $text = $cells[$j].SelectSingleNode("ss:Data", $nsm).InnerText
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

function Format-Invariant {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [double] -or $Value -is [float] -or $Value -is [decimal]) {
        return $Value.ToString("0.################", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    return [string]$Value
}

function Get-StrictCandidates {
    param(
        [Parameter(Mandatory = $true)][string]$Run,
        [Parameter(Mandatory = $true)][bool]$CacheCleared,
        [Parameter(Mandatory = $true)][string]$OptimizerXml,
        [Parameter(Mandatory = $true)][string]$ForwardXml
    )

    $opt = @(Read-Mt5Spreadsheet -Path $OptimizerXml)
    $fwd = @(Read-Mt5Spreadsheet -Path $ForwardXml)

    $optByPass = @{}
    foreach ($row in $opt) {
        $optByPass[[int]$row.Pass] = $row
    }

    $candidates = @()
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
        $isRatioRounded = [Math]::Round($isRatio, 2)
        $fwdRatioRounded = [Math]::Round($fwdRatio, 2)

        if ($isProfit -le 0 -or $fwdProfit -le 0) { continue }
        if ($isRatioRounded -le $MinRatio -or $fwdRatioRounded -le $MinRatio) { continue }
        if ($isDd -gt $MaxDrawdownPct -or $fwdDd -gt $MaxDrawdownPct) { continue }
        if ([int]$or.Trades -lt $StrictMinInSampleTrades -or [int]$fr.Trades -lt $StrictMinForwardTrades) { continue }

        $minCluster = [int](Get-PropValue -Object $fr -Name "g_MinClusterSize")
        $clusterMult = Get-PropValue -Object $fr -Name "g_ATR_Cluster_multiplier"
        $stopLossMult = Get-PropValue -Object $fr -Name "g_ATR_StopLoss_multiplier"
        $impulseLookback = [int](Get-PropValue -Object $fr -Name "g_impulse_lookback_hours")
        $pullbackLookforward = [int](Get-PropValue -Object $fr -Name "g_pullback_lookforward_hours")
        $impulseMult = Get-PropValue -Object $fr -Name "g_Impulse_ATR_multiplier"
        $pullbackMult = Get-PropValue -Object $fr -Name "g_MinPullback_ATR_multiplier"
        $tp = [int](Get-PropValue -Object $fr -Name "g_TakeProfitMultiplier")
        $parameterKey = [string]::Join("|", @(
            $minCluster,
            (Format-Invariant $clusterMult),
            (Format-Invariant $stopLossMult),
            $impulseLookback,
            $pullbackLookforward,
            (Format-Invariant $impulseMult),
            (Format-Invariant $pullbackMult),
            $tp
        ))

        $candidates += [pscustomobject]@{
            Run                 = $Run
            CacheCleared        = $CacheCleared
            Pass                = $pass
            MinRatio            = [Math]::Round([Math]::Min($isRatio, $fwdRatio), 3)
            ISProfit            = [Math]::Round($isProfit, 2)
            ISDD                = [Math]::Round($isDd, 2)
            ISRatio             = $isRatioRounded
            ISTrades            = [int]$or.Trades
            FwdProfit           = [Math]::Round($fwdProfit, 2)
            FwdDD               = [Math]::Round($fwdDd, 2)
            FwdRatio            = $fwdRatioRounded
            FwdTrades           = [int]$fr.Trades
            MinCluster          = $minCluster
            ClusterMult         = $clusterMult
            StopLossMult        = $stopLossMult
            ImpulseLookback     = $impulseLookback
            PullbackLookforward = $pullbackLookforward
            ImpulseMult         = $impulseMult
            PullbackMult        = $pullbackMult
            TP                  = $tp
            ParameterKey        = $parameterKey
        }
    }

    return $candidates
}

function New-FixedSetFile {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = @(
        "; $Symbol D1 StopLossSplit fixed OOS set from $($Candidate.Run) strict pass $($Candidate.Pass).",
        "; Candidate met strict profit, ratio, drawdown, and trade-count filters on optimizer-forward review.",
        "g_HighLowPeriod=16408||16408||1||16408||N",
        "g_ATR_Period=14||14||1||14||N",
        "g_MinClusterSize=$($Candidate.MinCluster)||$($Candidate.MinCluster)||1||$($Candidate.MinCluster)||N",
        "g_ATR_Cluster_multiplier=$(Format-Invariant $Candidate.ClusterMult)||$(Format-Invariant $Candidate.ClusterMult)||0.01||$(Format-Invariant $Candidate.ClusterMult)||N",
        "g_ATR_StopLoss_multiplier=$(Format-Invariant $Candidate.StopLossMult)||$(Format-Invariant $Candidate.StopLossMult)||0.01||$(Format-Invariant $Candidate.StopLossMult)||N",
        "g_impulse_lookback_hours=$($Candidate.ImpulseLookback)||$($Candidate.ImpulseLookback)||1||$($Candidate.ImpulseLookback)||N",
        "g_pullback_lookforward_hours=$($Candidate.PullbackLookforward)||$($Candidate.PullbackLookforward)||1||$($Candidate.PullbackLookforward)||N",
        "g_Impulse_ATR_multiplier=$(Format-Invariant $Candidate.ImpulseMult)||$(Format-Invariant $Candidate.ImpulseMult)||0.1||$(Format-Invariant $Candidate.ImpulseMult)||N",
        "g_MinPullback_ATR_multiplier=$(Format-Invariant $Candidate.PullbackMult)||$(Format-Invariant $Candidate.PullbackMult)||0.1||$(Format-Invariant $Candidate.PullbackMult)||N",
        "g_TakeProfitMultiplier=$($Candidate.TP)||$($Candidate.TP)||1||$($Candidate.TP)||N",
        "g_Risk_Percentage=1.0||1.0||0.5||3.0||N",
        "g_EnableTradeCsvLogging=false||false||0||true||N"
    )

    Set-Content -LiteralPath $Path -Value $lines -Encoding ASCII
}

function New-OosConfigFile {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$SetFileName
    )

    $report = "reports\${Symbol}_D1HighLow_Clustered_StopLossSplit_$($Candidate.Run)_Pass$($Candidate.Pass)_OOS_2018_2026_${ReportDate}.xml"
    $lines = @(
        "[Tester]",
        "Expert=WeekHighLow\WeekHighLowEA.ex5",
        "Symbol=$Symbol",
        "Period=H1",
        "",
        "FromDate=$FromDate",
        "ToDate=$ToDate",
        "",
        "Model=4",
        "Optimization=0",
        "Visual=0",
        "",
        "ExpertParameters=$SetFileName",
        "Report=$report",
        "",
        "; ForwardMode=2",
        "; OptimizationCriterion=7",
        "",
        "ShutdownTerminal=1"
    )

    Set-Content -LiteralPath $Path -Value $lines -Encoding ASCII
}

$runFiles = @(
    [pscustomobject]@{
        Run          = "RUN1"
        CacheCleared = $false
        OptimizerXml = Join-Path $ResultsDir "EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607.xml"
        ForwardXml   = Join-Path $ResultsDir "EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607.forward.xml"
    },
    [pscustomobject]@{
        Run          = "RUN2"
        CacheCleared = $false
        OptimizerXml = Join-Path $ResultsDir "EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607_RUN2.xml"
        ForwardXml   = Join-Path $ResultsDir "EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607_RUN2.forward.xml"
    },
    [pscustomobject]@{
        Run          = "RUN3"
        CacheCleared = $true
        OptimizerXml = Join-Path $ResultsDir "EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607_RUN3.xml"
        ForwardXml   = Join-Path $ResultsDir "EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607_RUN3.forward.xml"
    }
)

$allCandidates = @()
foreach ($runFile in $runFiles) {
    $allCandidates += Get-StrictCandidates `
        -Run $runFile.Run `
        -CacheCleared $runFile.CacheCleared `
        -OptimizerXml $runFile.OptimizerXml `
        -ForwardXml $runFile.ForwardXml
}

$allCandidates = @($allCandidates | Sort-Object Run, Pass)

Get-ChildItem -Path (Join-Path $ProfilesDir "ImpulseContinuation_${Symbol}_D1StopLossSplit_RUN*_Pass*.set") -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $ConfigDir "${Symbol}_D1StopLossSplit_RUN*_Pass*_OOS.ini") -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$candidateCsvPath = Join-Path $ResultsDir "strict_candidates.csv"
$allCandidates | Export-Csv -LiteralPath $candidateCsvPath -NoTypeInformation -Encoding ASCII

foreach ($candidate in $allCandidates) {
    $baseName = "ImpulseContinuation_${Symbol}_D1StopLossSplit_$($candidate.Run)_Pass$($candidate.Pass)"
    $setFileName = "$baseName.set"
    $configFileName = "${Symbol}_D1StopLossSplit_$($candidate.Run)_Pass$($candidate.Pass)_OOS.ini"

    New-FixedSetFile `
        -Candidate $candidate `
        -Path (Join-Path $ProfilesDir $setFileName)

    New-OosConfigFile `
        -Candidate $candidate `
        -Path (Join-Path $ConfigDir $configFileName) `
        -SetFileName $setFileName
}

$autorunPath = Join-Path $ConfigDir "autorun_stoploss_split_oos.ps1"
$autorunLines = @(
    '$mt5 = "C:\Program Files\MetaTrader 5\terminal64.exe"',
    '$maxRuntimeMinutes = 120',
    '$clearTesterCacheBeforeEachRun = $false',
    '$testerCachePath = "C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*"',
    '',
    '$configs = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "EURUSD_D1StopLossSplit_RUN*_Pass*_OOS.ini" |',
    '    Sort-Object Name |',
    '    Select-Object -ExpandProperty Name',
    '',
    '$overallStartTime = Get-Date',
    '',
    'foreach ($config in $configs) {',
    '    Write-Host ""',
    '    Write-Host "====================================="',
    '    Write-Host "Running OOS test for $config"',
    '    Write-Host "====================================="',
    '',
    '    if ($clearTesterCacheBeforeEachRun) {',
    '        Write-Host "Clearing tester cache"',
    '        Remove-Item $testerCachePath -Recurse -Force -ErrorAction SilentlyContinue',
    '        Start-Sleep -Seconds 5',
    '    }',
    '',
    '    $configPath = Join-Path $PSScriptRoot $config',
    '    $startTime = Get-Date',
    '    $process = Start-Process -FilePath $mt5 -ArgumentList "/config:`"$configPath`"" -PassThru',
    '',
    '    while (-not $process.HasExited) {',
    '        Start-Sleep -Seconds 30',
    '        $process.Refresh()',
    '',
    '        $elapsed = (Get-Date) - $startTime',
    '        if ($elapsed.TotalMinutes -ge $maxRuntimeMinutes) {',
    '            Write-Host "Timeout reached for $config after $($elapsed.ToString()). Stopping MT5 process."',
    '            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue',
    '            break',
    '        }',
    '    }',
    '',
    '    $endTime = Get-Date',
    '    $duration = $endTime - $startTime',
    '    Write-Host "Finished $config"',
    '    Write-Host "Duration: $($duration.ToString())"',
    '}',
    '',
    '$overallEndTime = Get-Date',
    '$overallDuration = $overallEndTime - $overallStartTime',
    'Write-Host "Overall Duration: $($overallDuration.ToString())"'
)
Set-Content -LiteralPath $autorunPath -Value $autorunLines -Encoding ASCII

$duplicates = @($allCandidates | Group-Object ParameterKey | Where-Object { $_.Count -gt 1 })
[pscustomobject]@{
    StrictCandidates      = $allCandidates.Count
    UniqueParameterSets   = @($allCandidates | Group-Object ParameterKey).Count
    DuplicateParameterSets = $duplicates.Count
    CandidateCsv          = $candidateCsvPath
    SetFilesCreated       = $allCandidates.Count
    ConfigFilesCreated    = $allCandidates.Count
    AutorunScript         = $autorunPath
} | Format-List
