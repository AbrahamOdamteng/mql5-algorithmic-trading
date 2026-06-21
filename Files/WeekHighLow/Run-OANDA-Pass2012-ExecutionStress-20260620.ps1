param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [int]$TimeoutMinutes = 60,
  [string[]]$Scenario = @('RandomDelay', 'Delay1000ms', 'Delay3000ms'),
  [string[]]$Symbol = @('EURUSD', 'XAUUSD'),
  [switch]$KeepExistingCsv,
  [switch]$PrepareOnly,
  [switch]$StopOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

function Set-Or-AppendLine {
  param(
    [Parameter(Mandatory = $true)][string[]]$Lines,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $found = $false
  $updated = foreach ($line in $Lines) {
    if ($line -match ('^' + [regex]::Escape($Name) + '=')) {
      $found = $true
      $Value
    } else {
      $line
    }
  }

  if (-not $found) {
    $updated += $Value
  }

  return @($updated)
}

function New-CsvEnabledSetFile {
  param(
    [Parameter(Mandatory = $true)][string]$SourceSet,
    [Parameter(Mandatory = $true)][string]$ManifoldId,
    [Parameter(Mandatory = $true)][string]$TestId
  )

  $sourcePath = Join-Path $testerProfilesDir $SourceSet
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source preset not found: $sourcePath"
  }

  $lines = @(Get-Content -LiteralPath $sourcePath)
  $lines = Set-Or-AppendLine -Lines $lines -Name 'g_EnableTradeCsvLogging' -Value 'g_EnableTradeCsvLogging=true||false||0||true||N'
  $lines = Set-Or-AppendLine -Lines $lines -Name 'g_TradeCsvManifoldId' -Value "g_TradeCsvManifoldId=$ManifoldId"
  $lines = Set-Or-AppendLine -Lines $lines -Name 'g_TradeCsvTestId' -Value "g_TradeCsvTestId=$TestId"

  $targetName = "ImpulseContinuation_${ManifoldId}_${TestId}.set"
  $targetPath = Join-Path $testerProfilesDir $targetName
  $lines | Set-Content -LiteralPath $targetPath -Encoding ASCII
  Copy-Item -LiteralPath $targetPath -Destination (Join-Path $reportDir $targetName) -Force

  return $targetName
}

function New-TestConfigFile {
  param(
    [Parameter(Mandatory = $true)][string]$SymbolName,
    [Parameter(Mandatory = $true)][string]$SetFileName,
    [Parameter(Mandatory = $true)][object]$ScenarioInfo,
    [Parameter(Mandatory = $true)][string]$ManifoldId,
    [Parameter(Mandatory = $true)][string]$TestId
  )

  $iniName = "${ManifoldId}_${TestId}.ini"
  $iniPath = Join-Path $scriptRoot $iniName
  $reportName = "${ManifoldId}_${TestId}_FULL_20000101_20260601.xml"

  $content = @(
    '[Tester]',
    'Expert=WeekHighLow\WeekHighLowEA.ex5',
    "Symbol=$SymbolName",
    'Period=H1',
    '',
    'FromDate=2000.01.01',
    'ToDate=2026.06.01',
    '',
    'Model=4',
    "ExecutionMode=$($ScenarioInfo.ExecutionMode)",
    'Optimization=0',
    'Visual=0',
    '',
    "ExpertParameters=$SetFileName",
    "Report=reports\oanda_eurusd_xauusd_same_manifold_20260619\$reportName",
    '',
    '; ForwardMode=2',
    '; OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )

  $content | Set-Content -LiteralPath $iniPath -Encoding ASCII
  Copy-Item -LiteralPath $iniPath -Destination (Join-Path $reportDir $iniName) -Force

  return $iniPath
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mql5Root = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$reportDir = Join-Path $terminalDataRoot 'reports\oanda_eurusd_xauusd_same_manifold_20260619'
$commonFilesDir = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$progressPath = Join-Path $reportDir 'pass2012_execution_stress_progress.csv'
$manifestPath = Join-Path $reportDir 'pass2012_execution_stress_manifest.csv'

if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $commonFilesDir)) {
  New-Item -ItemType Directory -Path $commonFilesDir -Force | Out-Null
}

Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $reportDir 'Run-OANDA-Pass2012-ExecutionStress-20260620.ps1') -Force

$Scenario = @(Expand-FilterValues $Scenario)
$Symbol = @(Expand-FilterValues $Symbol)

$availableScenarios = @(
  [pscustomobject]@{ Name = 'RandomDelay'; ExecutionMode = '-1'; Description = 'MT5 random trade execution delay' },
  [pscustomobject]@{ Name = 'Delay1000ms'; ExecutionMode = '1000'; Description = 'Fixed 1000 ms trade execution delay' },
  [pscustomobject]@{ Name = 'Delay3000ms'; ExecutionMode = '3000'; Description = 'Fixed 3000 ms trade execution delay' }
)

$selectedScenarios = @($availableScenarios | Where-Object { $Scenario -contains $_.Name })
if ($selectedScenarios.Count -eq 0) {
  throw 'No selected execution-stress scenarios matched available scenarios.'
}

if ($Symbol.Count -eq 0) {
  throw 'No symbols selected.'
}

$sourceSet = 'ImpulseContinuation_OANDA_SameManifold_Pass2012.set'
$manifest = New-Object System.Collections.Generic.List[object]
$testIndex = 1

foreach ($scenarioInfo in $selectedScenarios) {
  $manifoldId = "OANDA_Pass2012_ExecStress_$($scenarioInfo.Name)"
  $csvFile = Join-Path $commonFilesDir "manifold_trades_$manifoldId.csv"

  foreach ($symbolName in $Symbol) {
    $testId = "${symbolName}_Pass2012_$($scenarioInfo.Name)_FULL"
    $setFileName = New-CsvEnabledSetFile -SourceSet $sourceSet -ManifoldId $manifoldId -TestId $testId
    $iniPath = New-TestConfigFile -SymbolName $symbolName -SetFileName $setFileName -ScenarioInfo $scenarioInfo -ManifoldId $manifoldId -TestId $testId

    $manifest.Add([pscustomobject]@{
      TestIndex = $testIndex
      Scenario = $scenarioInfo.Name
      ExecutionMode = $scenarioInfo.ExecutionMode
      Description = $scenarioInfo.Description
      ManifoldId = $manifoldId
      TestId = $testId
      Symbol = $symbolName
      FromDate = '2000.01.01'
      ToDate = '2026.06.01'
      IniPath = $iniPath
      CsvPath = $csvFile
      ExpectedReport = Join-Path $reportDir "${manifoldId}_${testId}_FULL_20000101_20260601.xml.htm"
    })

    $testIndex++
  }
}

$manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding ASCII

Write-Host "Report directory: $reportDir"
Write-Host "Common CSV directory: $commonFilesDir"
Write-Host "Manifest: $manifestPath"
Write-Host "Progress log: $progressPath"
Write-Host "Tests prepared: $($manifest.Count)"
Write-Host 'Note: MT5 command-line config supports ExecutionMode delay stress, not an explicit fixed-spread override.'
$manifest | Select-Object Scenario, ExecutionMode, ManifoldId, TestId, Symbol, CsvPath | Format-Table -AutoSize

if ($PrepareOnly) {
  Write-Host 'PrepareOnly set. No MT5 tests were run.'
  return
}

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

foreach ($csvPath in @($manifest | Select-Object -ExpandProperty CsvPath -Unique)) {
  if ((-not $KeepExistingCsv) -and (Test-Path -LiteralPath $csvPath)) {
    Remove-Item -LiteralPath $csvPath -Force
    Write-Host "Deleted existing CSV: $csvPath"
  }
}

$results = New-Object System.Collections.Generic.List[object]
$batchStart = Get-Date

foreach ($test in $manifest) {
  $start = Get-Date
  Write-Host "Starting $($test.ManifoldId) / $($test.TestId) at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"

  $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$($test.IniPath)`"" -PassThru
  $completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
  $end = Get-Date

  if (-not $completed) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $status = 'TimedOut'
    $exitCode = $null
  } else {
    $process.Refresh()
    $exitCode = $process.ExitCode
    $status = if ($exitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }
  }

  $reportExists = Test-Path -LiteralPath $test.ExpectedReport
  $csvExists = Test-Path -LiteralPath $test.CsvPath

  $results.Add([pscustomobject]@{
    Timestamp = $end.ToString('s')
    Scenario = $test.Scenario
    ExecutionMode = $test.ExecutionMode
    ManifoldId = $test.ManifoldId
    TestId = $test.TestId
    Symbol = $test.Symbol
    Status = $status
    ExitCode = $exitCode
    DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
    ReportExists = $reportExists
    CsvExists = $csvExists
    CsvPath = $test.CsvPath
  })

  Write-Host "Finished $($test.TestId): $status report=$reportExists csv=$csvExists"

  if ($StopOnFailure -and ($status -ne 'Completed' -or -not $reportExists -or -not $csvExists)) {
    break
  }
}

$results | Export-Csv -LiteralPath $progressPath -NoTypeInformation -Encoding ASCII

Write-Host "Batch finished in $([math]::Round(((Get-Date) - $batchStart).TotalMinutes, 2)) minutes"
Write-Host 'CSV outputs:'
@($manifest | Select-Object -ExpandProperty CsvPath -Unique) | ForEach-Object { Write-Host $_ }
$results | Format-Table -AutoSize
