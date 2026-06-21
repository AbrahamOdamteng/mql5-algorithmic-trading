param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ExperimentDir = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\reports\ftmo_eurusd_d1_stoploss_split_genetic_20260617',
  [string]$CandidateCsv = '',
  [string]$ManifestPath = '',
  [string]$ProgressPath = '',
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'ftmo_eurusd_genetic_cross_symbol_current.ini'),
  [string]$TemplateSetFile = 'ImpulseContinuation_EURUSD_FTMO_Genetic.set',
  [string]$TempSetFile = 'ImpulseContinuation_FTMO_EURUSDGenetic_CrossSymbol_Current.set',
  [int]$TopN = 0,
  [int]$MaxRuntimeMinutes = 10,
  [int]$PollSeconds = 30,
  [int]$StartAtIndex = 1,
  [int]$MaxTests = 0,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$ClearTesterCache,
  [switch]$SkipMetals,
  [switch]$SkipEnergy,
  [string[]]$ManifoldId = @(),
  [string[]]$Symbol = @(),
  [string[]]$MarketGroup = @(),
  [string[]]$Segment = @(),
  [string[]]$IndexSymbol = @('US500.cash', 'US30.cash', 'US100.cash', 'UK100.cash')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testerCachePath = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*'

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

function New-SymbolRows {
  param([string[]]$IndexSymbols, [bool]$ExcludeMetals, [bool]$ExcludeEnergy)

  $fxSymbols = @(
    'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'USDCAD', 'AUDUSD', 'NZDUSD',
    'EURGBP', 'EURJPY', 'EURCHF', 'EURCAD', 'EURAUD', 'EURNZD',
    'GBPJPY', 'GBPCHF', 'GBPCAD', 'GBPAUD', 'GBPNZD',
    'CHFJPY', 'CADJPY', 'AUDJPY', 'NZDJPY',
    'CADCHF', 'AUDCHF', 'NZDCHF',
    'AUDCAD', 'NZDCAD', 'AUDNZD'
  )

  $metalSymbols = @(
    'XAUUSD', 'XAUEUR', 'XAUAUD',
    'XAGUSD', 'XAGEUR', 'XAGAUD',
    'XPTUSD', 'XPDUSD', 'XCUUSD'
  )

  $energySymbols = @('USOIL.cash', 'UKOIL.cash')

  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($item in $fxSymbols) {
    $rows.Add([pscustomobject]@{ Symbol = $item; MarketGroup = 'FX' })
  }

  if (-not $ExcludeMetals) {
    foreach ($item in $metalSymbols) {
      $rows.Add([pscustomobject]@{ Symbol = $item; MarketGroup = 'Metals' })
    }
  }

  foreach ($item in $IndexSymbols) {
    $rows.Add([pscustomobject]@{ Symbol = $item; MarketGroup = 'Indices' })
  }

  if (-not $ExcludeEnergy) {
    foreach ($item in $energySymbols) {
      $rows.Add([pscustomobject]@{ Symbol = $item; MarketGroup = 'Energy' })
    }
  }

  return $rows
}

function Convert-ReportPathToFullPath {
  param(
    [string]$ReportRoot,
    [string]$ExpectedReport
  )

  $relative = $ExpectedReport -replace '/', '\'
  return Join-Path $ReportRoot $relative
}

function Set-InputLine {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Name,
    [string]$Value,
    [switch]$PlainString
  )

  $line = "$Name=$Value||$Value||0||$Value||N"
  if ($PlainString) {
    $line = "$Name=$Value"
  }

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -like "$Name=*") {
      $Lines[$i] = $line
      return
    }
  }

  $Lines.Add($line)
}

function New-TestSetFile {
  param(
    [object]$Test,
    [string]$TemplateSetPath,
    [string]$TempSetPath,
    [string]$TempSetFile
  )

  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [System.IO.File]::ReadAllLines($TemplateSetPath, [System.Text.Encoding]::Unicode)) {
    $lines.Add($line)
  }

  Set-InputLine -Lines $lines -Name 'g_MinClusterSize' -Value $Test.MinCluster
  Set-InputLine -Lines $lines -Name 'g_ATR_Cluster_multiplier' -Value $Test.ClusterMult
  Set-InputLine -Lines $lines -Name 'g_ATR_StopLoss_multiplier' -Value $Test.StopLossMult
  Set-InputLine -Lines $lines -Name 'g_impulse_lookback_hours' -Value $Test.ImpulseLookback
  Set-InputLine -Lines $lines -Name 'g_pullback_lookforward_hours' -Value $Test.PullbackLookforward
  Set-InputLine -Lines $lines -Name 'g_Impulse_ATR_multiplier' -Value $Test.ImpulseMult
  Set-InputLine -Lines $lines -Name 'g_MinPullback_ATR_multiplier' -Value $Test.PullbackMult
  Set-InputLine -Lines $lines -Name 'g_TakeProfitMultiplier' -Value $Test.TP
  Set-InputLine -Lines $lines -Name 'g_EnableTradeCsvLogging' -Value 'false'
  Set-InputLine -Lines $lines -Name 'g_TradeCsvManifoldId' -Value $Test.ManifoldId -PlainString
  Set-InputLine -Lines $lines -Name 'g_TradeCsvTestId' -Value $Test.TestId -PlainString

  [System.IO.File]::WriteAllLines($TempSetPath, $lines, [System.Text.Encoding]::Unicode)
  return $TempSetFile
}

function Append-Progress {
  param(
    [object]$Test,
    [string]$Status,
    [double]$DurationSeconds,
    [string]$ReportPath,
    [string]$Note
  )

  $row = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('s')
    TestIndex = $Test.TestIndex
    TestId = $Test.TestId
    ManifoldId = $Test.ManifoldId
    Pass = $Test.Pass
    Symbol = $Test.Symbol
    MarketGroup = $Test.MarketGroup
    Segment = $Test.Segment
    FromDate = $Test.FromDate
    ToDate = $Test.ToDate
    Status = $Status
    DurationSeconds = [math]::Round($DurationSeconds, 2)
    ReportPath = $ReportPath
    Note = $Note
  }

  if (Test-Path -LiteralPath $ProgressPath) {
    $row | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Append -Encoding ASCII
  } else {
    $row | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Encoding ASCII
  }
}

if (-not $CandidateCsv) {
  $CandidateCsv = Join-Path $ExperimentDir 'EURUSD_D1StopLossSplit_FTMO_Genetic_2000_2018_FWD_20260617_candidates_profit_floor.csv'
}
if (-not $ManifestPath) {
  $ManifestPath = Join-Path $ExperimentDir 'cross_symbol_is_val_manifest.csv'
}
if (-not $ProgressPath) {
  $ProgressPath = Join-Path $ExperimentDir 'cross_symbol_is_val_progress.csv'
}

if (-not (Test-Path -LiteralPath $ExperimentDir)) {
  throw "Experiment directory not found: $ExperimentDir"
}
if (-not (Test-Path -LiteralPath $CandidateCsv)) {
  throw "Candidate CSV not found: $CandidateCsv"
}
if (-not (Test-Path -LiteralPath $TerminalPath) -and -not $PrepareOnly) {
  throw "MT5 terminal not found: $TerminalPath"
}

$mql5Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$templateSetPath = Join-Path $testerProfilesDir $TemplateSetFile
$tempSetPath = Join-Path $testerProfilesDir $TempSetFile
if (-not (Test-Path -LiteralPath $templateSetPath)) {
  throw "Template set file not found: $templateSetPath"
}

$experimentName = Split-Path -Leaf $ExperimentDir
$reportSubdir = "reports\$experimentName\cross_symbol_is_val"
$reportDir = Join-Path $terminalDataRoot $reportSubdir
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$segments = @(
  [pscustomobject]@{ Name = 'IS'; From = '2000.01.01'; To = '2012.01.01' },
  [pscustomobject]@{ Name = 'VAL'; From = '2012.01.01'; To = '2018.01.01' }
)

$IndexSymbol = @(Expand-FilterValues $IndexSymbol)
$symbols = @(New-SymbolRows -IndexSymbols $IndexSymbol -ExcludeMetals ([bool]$SkipMetals) -ExcludeEnergy ([bool]$SkipEnergy))
$candidates = @(Import-Csv -LiteralPath $CandidateCsv)
if ($TopN -gt 0) {
  $candidates = @($candidates | Select-Object -First $TopN)
}

$manifestRows = New-Object System.Collections.Generic.List[object]
$testIndex = 1
foreach ($candidate in $candidates) {
  $candidateManifoldId = "FTMOEURUSD_Pass$($candidate.Pass)"
  foreach ($symbolRow in $symbols) {
    foreach ($segmentRow in $segments) {
      $dateLabel = ($segmentRow.From -replace '\.', '') + '_' + ($segmentRow.To -replace '\.', '')
      $report = "$reportSubdir\$($symbolRow.Symbol)_D1StopLossSplit_$($candidateManifoldId)_$($segmentRow.Name)_$dateLabel.xml"
      $testId = ('{0:D5}_{1}_{2}_{3}' -f $testIndex, $candidateManifoldId, $symbolRow.Symbol, $segmentRow.Name)

      $manifestRows.Add([pscustomobject]@{
        TestIndex = $testIndex
        TestId = $testId
        ManifoldId = $candidateManifoldId
        Pass = $candidate.Pass
        Symbol = $symbolRow.Symbol
        MarketGroup = $symbolRow.MarketGroup
        Segment = $segmentRow.Name
        FromDate = $segmentRow.From
        ToDate = $segmentRow.To
        Report = $report
        ExpectedReport = "$report.htm"
        MinRatio = $candidate.MinRatio
        ISProfit = $candidate.ISProfit
        FwdProfit = $candidate.FwdProfit
        TotalProfit = $candidate.TotalProfit
        MinCluster = $candidate.MinCluster
        ClusterMult = $candidate.ClusterMult
        StopLossMult = $candidate.StopLossMult
        ImpulseLookback = $candidate.ImpulseLookback
        PullbackLookforward = $candidate.PullbackLookforward
        ImpulseMult = $candidate.ImpulseMult
        PullbackMult = $candidate.PullbackMult
        TP = $candidate.TP
      })
      $testIndex++
    }
  }
}

$manifestRows | Export-Csv -LiteralPath $ManifestPath -NoTypeInformation -Encoding ASCII

Write-Host "Experiment directory: $ExperimentDir"
Write-Host "Candidate CSV: $CandidateCsv"
Write-Host "Manifest: $ManifestPath"
Write-Host "Progress log: $ProgressPath"
Write-Host "Report directory: $reportDir"
Write-Host "Candidate manifolds: $($candidates.Count)"
Write-Host "Symbols: $($symbols.Count)"
Write-Host "Segments: $($segments.Count)"
Write-Host "Manifest tests: $($manifestRows.Count)"
Write-Host "FX symbols: 28"
Write-Host "Metal symbols: $(if ($SkipMetals) { 0 } else { 9 })"
Write-Host "Index symbols: $($IndexSymbol.Count) ($($IndexSymbol -join ', '))"
Write-Host "Energy symbols: $(if ($SkipEnergy) { 0 } else { 2 }) (USOIL.cash, UKOIL.cash)"

if ($PrepareOnly) {
  Write-Host 'PrepareOnly set. No MT5 tests were run.'
  return
}

$ManifoldId = @(Expand-FilterValues $ManifoldId)
$Symbol = @(Expand-FilterValues $Symbol)
$MarketGroup = @(Expand-FilterValues $MarketGroup)
$Segment = @(Expand-FilterValues $Segment)

$manifest = Import-Csv -LiteralPath $ManifestPath | Sort-Object { [int]$_.TestIndex }
if ($ManifoldId.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $ManifoldId -contains $_.ManifoldId })
}
if ($Symbol.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $Symbol -contains $_.Symbol })
}
if ($MarketGroup.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $MarketGroup -contains $_.MarketGroup })
}
if ($Segment.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $Segment -contains $_.Segment })
}
if ($manifest.Count -eq 0) {
  throw 'Manifest has no tests after filters.'
}

$completedStatuses = @('Completed', 'SkippedExistingReport')
$completedByProgress = @{}
if (Test-Path -LiteralPath $ProgressPath) {
  Import-Csv -LiteralPath $ProgressPath | ForEach-Object {
    if ($completedStatuses -contains $_.Status) {
      $completedByProgress[$_.TestId] = $true
    }
  }
}

$testsRunThisSession = 0
$overallStart = Get-Date

foreach ($test in $manifest) {
  $testIndex = [int]$test.TestIndex
  if ($testIndex -lt $StartAtIndex) {
    continue
  }
  if ($MaxTests -gt 0 -and $testsRunThisSession -ge $MaxTests) {
    break
  }

  $expectedReportPath = Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $test.ExpectedReport
  if (-not $RunExistingReports -and ($completedByProgress.ContainsKey($test.TestId) -or (Test-Path -LiteralPath $expectedReportPath))) {
    if (-not $completedByProgress.ContainsKey($test.TestId)) {
      Append-Progress -Test $test -Status 'SkippedExistingReport' -DurationSeconds 0 -ReportPath $expectedReportPath -Note 'Report already existed before run.'
    }
    continue
  }

  Write-Host ''
  Write-Host '====================================='
  Write-Host "Running $($test.TestIndex)/$($manifestRows.Count): $($test.TestId)"
  Write-Host "$($test.Symbol) $($test.Segment) $($test.FromDate) -> $($test.ToDate)"
  Write-Host '====================================='

  if ($ClearTesterCache) {
    Write-Host 'Clearing tester cache'
    Remove-Item $testerCachePath -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
  }

  $expertParameters = New-TestSetFile -Test $test -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -TempSetFile $TempSetFile
  $configContent = @(
    '[Tester]',
    'Expert=WeekHighLow\WeekHighLowEA.ex5',
    "Symbol=$($test.Symbol)",
    'Period=H1',
    '',
    "FromDate=$($test.FromDate)",
    "ToDate=$($test.ToDate)",
    '',
    'Model=4',
    'Optimization=0',
    'Visual=0',
    '',
    "ExpertParameters=$expertParameters",
    "Report=$($test.Report)",
    '',
    '; ForwardMode=2',
    '; OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )

  $configContent | Set-Content -LiteralPath $TempConfigPath -Encoding ASCII

  $startTime = Get-Date
  $status = 'FailedNoReport'
  $note = ''
  $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$TempConfigPath`"" -PassThru

  while (-not $process.HasExited) {
    Start-Sleep -Seconds $PollSeconds
    $process.Refresh()

    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalMinutes -ge $MaxRuntimeMinutes) {
      $status = 'TimedOut'
      $note = "Timeout after $MaxRuntimeMinutes minutes."
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      break
    }
  }

  Start-Sleep -Seconds 2
  $duration = ((Get-Date) - $startTime).TotalSeconds
  if (Test-Path -LiteralPath $expectedReportPath) {
    $status = 'Completed'
    if (-not $note) {
      $note = 'Report file found.'
    }
  } elseif (-not $note) {
    $note = 'MT5 exited but expected report was not found.'
  }

  Append-Progress -Test $test -Status $status -DurationSeconds $duration -ReportPath $expectedReportPath -Note $note
  $testsRunThisSession++

  Write-Host "Finished $($test.TestId): $status"
  Write-Host "Test duration: $([TimeSpan]::FromSeconds($duration).ToString())"
  Write-Host "Total elapsed: $(((Get-Date) - $overallStart).ToString())"
}

$overallDuration = (Get-Date) - $overallStart
Write-Host ''
Write-Host "Session complete. Tests run this session: $testsRunThisSession"
Write-Host "Overall duration: $($overallDuration.ToString())"
Write-Host "Progress log: $ProgressPath"
