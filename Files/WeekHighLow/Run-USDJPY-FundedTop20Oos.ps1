param(
  [string]$TerminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe",
  [int]$TimeoutMinutes = 30,
  [int[]]$PassId = @(),
  [switch]$RunExistingReports,
  [switch]$StopOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$terminalRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot '..\..\..')).Path
$profileDir = Join-Path $terminalRoot 'MQL5\Profiles\Tester'
$reportsDir = Join-Path $terminalRoot 'reports\usdjpy_funded_oos'

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

if (-not (Test-Path -LiteralPath $profileDir)) {
  throw "Tester profile directory not found: $profileDir"
}

if (-not (Test-Path -LiteralPath $reportsDir)) {
  New-Item -ItemType Directory -Path $reportsDir | Out-Null
}

$candidates = @(
  [pscustomobject]@{ Pass = 3363; MinCluster = 5; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 96; PullbackLookforward = 30; ImpulseMult = '0.6'; PullbackMult = '1.4'; TP = 5 },
  [pscustomobject]@{ Pass = 3701; MinCluster = 5; ClusterMult = '0.5'; StopLossMult = '0.5'; ImpulseLookback = 144; PullbackLookforward = 30; ImpulseMult = '1.4'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 3602; MinCluster = 5; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 120; PullbackLookforward = 30; ImpulseMult = '1.4'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 3751; MinCluster = 7; ClusterMult = '0.5'; StopLossMult = '0.5'; ImpulseLookback = 120; PullbackLookforward = 24; ImpulseMult = '1.2'; PullbackMult = '1.4'; TP = 4 },
  [pscustomobject]@{ Pass = 3401; MinCluster = 2; ClusterMult = '0.2'; StopLossMult = '0.45'; ImpulseLookback = 72; PullbackLookforward = 24; ImpulseMult = '1.0'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 4094; MinCluster = 8; ClusterMult = '0.5'; StopLossMult = '0.5'; ImpulseLookback = 120; PullbackLookforward = 24; ImpulseMult = '1.4'; PullbackMult = '1.4'; TP = 3 },
  [pscustomobject]@{ Pass = 3020; MinCluster = 8; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 72; PullbackLookforward = 24; ImpulseMult = '1.0'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 2575; MinCluster = 5; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 72; PullbackLookforward = 24; ImpulseMult = '1.0'; PullbackMult = '1.4'; TP = 5 },
  [pscustomobject]@{ Pass = 2521; MinCluster = 5; ClusterMult = '0.4'; StopLossMult = '0.45'; ImpulseLookback = 96; PullbackLookforward = 24; ImpulseMult = '1.0'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 3494; MinCluster = 8; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 72; PullbackLookforward = 24; ImpulseMult = '1.2'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 3503; MinCluster = 8; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 72; PullbackLookforward = 24; ImpulseMult = '0.8'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 3607; MinCluster = 5; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 96; PullbackLookforward = 24; ImpulseMult = '1.0'; PullbackMult = '1.4'; TP = 5 },
  [pscustomobject]@{ Pass = 3857; MinCluster = 7; ClusterMult = '0.5'; StopLossMult = '0.5'; ImpulseLookback = 72; PullbackLookforward = 24; ImpulseMult = '1.0'; PullbackMult = '1.2'; TP = 3 },
  [pscustomobject]@{ Pass = 4078; MinCluster = 7; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 168; PullbackLookforward = 24; ImpulseMult = '1.2'; PullbackMult = '1.4'; TP = 4 },
  [pscustomobject]@{ Pass = 3458; MinCluster = 7; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 120; PullbackLookforward = 24; ImpulseMult = '1.2'; PullbackMult = '1.4'; TP = 4 },
  [pscustomobject]@{ Pass = 3914; MinCluster = 7; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 144; PullbackLookforward = 30; ImpulseMult = '0.8'; PullbackMult = '1.4'; TP = 5 },
  [pscustomobject]@{ Pass = 3807; MinCluster = 8; ClusterMult = '0.5'; StopLossMult = '0.45'; ImpulseLookback = 144; PullbackLookforward = 24; ImpulseMult = '0.8'; PullbackMult = '1.4'; TP = 4 },
  [pscustomobject]@{ Pass = 2698; MinCluster = 4; ClusterMult = '0.4'; StopLossMult = '0.3'; ImpulseLookback = 168; PullbackLookforward = 36; ImpulseMult = '1.6'; PullbackMult = '0.8'; TP = 4 },
  [pscustomobject]@{ Pass = 3773; MinCluster = 7; ClusterMult = '0.5'; StopLossMult = '0.35'; ImpulseLookback = 96; PullbackLookforward = 24; ImpulseMult = '0.8'; PullbackMult = '1.2'; TP = 5 },
  [pscustomobject]@{ Pass = 4564; MinCluster = 3; ClusterMult = '0.3'; StopLossMult = '0.45'; ImpulseLookback = 144; PullbackLookforward = 24; ImpulseMult = '1.4'; PullbackMult = '1.4'; TP = 2 }
)

if ($PassId.Count -gt 0) {
  $candidates = @($candidates | Where-Object { $PassId -contains $_.Pass })
}

if ($candidates.Count -eq 0) {
  throw 'No USDJPY top-20 candidates selected.'
}

function New-SetContentForCandidate {
  param([Parameter(Mandatory = $true)]$Candidate)

  return @"
; Fixed OOS preset from USDJPY funded genetic pass $($Candidate.Pass).
g_HighLowPeriod=16408||16408||1||16408||N
g_ATR_Period=14||14||1||14||N
g_MinClusterSize=$($Candidate.MinCluster)||$($Candidate.MinCluster)||1||8||N
g_ATR_Cluster_multiplier=$($Candidate.ClusterMult)||$($Candidate.ClusterMult)||0.1||0.5||N
g_ATR_StopLoss_multiplier=$($Candidate.StopLossMult)||$($Candidate.StopLossMult)||0.05||0.5||N
g_impulse_lookback_hours=$($Candidate.ImpulseLookback)||$($Candidate.ImpulseLookback)||24||168||N
g_pullback_lookforward_hours=$($Candidate.PullbackLookforward)||$($Candidate.PullbackLookforward)||6||96||N
g_Impulse_ATR_multiplier=$($Candidate.ImpulseMult)||$($Candidate.ImpulseMult)||0.2||3.0||N
g_MinPullback_ATR_multiplier=$($Candidate.PullbackMult)||$($Candidate.PullbackMult)||0.2||3.0||N
g_TakeProfitMultiplier=$($Candidate.TP)||$($Candidate.TP)||1||5||N
g_Risk_Percentage=1.0||1.0||0.5||3.0||N
g_EnableTradeCsvLogging=false||false||0||true||N
g_TradeCsvManifoldId=USDJPY_Funded_Pass$($Candidate.Pass)
g_TradeCsvTestId=
"@
}

function New-IniContentForCandidate {
  param(
    [Parameter(Mandatory = $true)]$Candidate,
    [Parameter(Mandatory = $true)][string]$SetFileName,
    [Parameter(Mandatory = $true)][string]$ReportName
  )

  return @"
[Tester]
Expert=WeekHighLow\WeekHighLowEA.ex5
Symbol=USDJPY
Period=H1

FromDate=2018.01.01
ToDate=2026.06.01

Model=4
Optimization=0
Visual=0

ExpertParameters=$SetFileName
Report=reports\usdjpy_funded_oos\$ReportName

; ForwardMode=2
; OptimizationCriterion=7

ShutdownTerminal=1
"@
}

$results = New-Object System.Collections.Generic.List[object]
$batchStart = Get-Date

foreach ($candidate in $candidates) {
  $pass = [int]$candidate.Pass
  $setFileName = "ImpulseContinuation_USDJPY_Funded_Top20_Pass$pass.set"
  $iniFileName = "USDJPY_Funded_Top20_Pass$pass`_OOS.ini"
  $reportName = "USDJPY_D1StopLossSplit_Funded_Pass$pass`_OOS_20180101_20260601.xml"
  $reportHtmlPath = Join-Path $reportsDir "$reportName.htm"

  if ((-not $RunExistingReports) -and (Test-Path -LiteralPath $reportHtmlPath)) {
    "Skipping pass $pass because report already exists: $reportHtmlPath"
    $results.Add([pscustomobject]@{
      Pass = $pass
      IniFile = $iniFileName
      Status = 'SkippedExistingReport'
      ExitCode = $null
      Started = $null
      Ended = $null
      DurationMinutes = 0
    })
    continue
  }

  $setPath = Join-Path $profileDir $setFileName
  $iniPath = Join-Path $scriptRoot $iniFileName
  Set-Content -LiteralPath $setPath -Value (New-SetContentForCandidate -Candidate $candidate) -Encoding ASCII
  Set-Content -LiteralPath $iniPath -Value (New-IniContentForCandidate -Candidate $candidate -SetFileName $setFileName -ReportName $reportName) -Encoding ASCII

  $start = Get-Date
  "Starting USDJPY pass $pass at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"

  $process = Start-Process `
    -FilePath $TerminalPath `
    -ArgumentList "/config:`"$iniPath`"" `
    -PassThru

  $completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
  $end = Get-Date

  if (-not $completed) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $results.Add([pscustomobject]@{
      Pass = $pass
      IniFile = $iniFileName
      Status = 'TimedOut'
      ExitCode = $null
      Started = $start
      Ended = $end
      DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
    })

    "Timed out USDJPY pass $pass after $TimeoutMinutes minutes"
    if ($StopOnFailure) {
      break
    }

    continue
  }

  $process.Refresh()
  $exitCode = $process.ExitCode
  $status = if ($exitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }

  $results.Add([pscustomobject]@{
    Pass = $pass
    IniFile = $iniFileName
    Status = $status
    ExitCode = $exitCode
    Started = $start
    Ended = $end
    DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
  })

  "Finished USDJPY pass $pass with status $status in $([math]::Round(($end - $start).TotalMinutes, 2)) minutes"

  if ($StopOnFailure -and $status -ne 'Completed') {
    break
  }
}

"Batch finished in $([math]::Round(((Get-Date) - $batchStart).TotalMinutes, 2)) minutes"
$results | Format-Table -AutoSize
