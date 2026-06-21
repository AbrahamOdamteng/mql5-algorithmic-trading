param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [int]$MaxRuntimeMinutes = 45,
  [int]$PollSeconds = 30,
  [int]$StartAtIndex = 1,
  [int]$MaxTests = 0,
  [switch]$RunExistingReports,
  [switch]$PrepareOnly,
  [string[]]$Symbol = @('EURUSD', 'XAUUSD'),
  [string[]]$Window = @('W2003_2010', 'W2010_2017', 'W2017_2026')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

function Convert-ReportPathToFullPath {
  param(
    [string]$ReportRoot,
    [string]$ExpectedReport
  )

  $relative = $ExpectedReport -replace '/', '\'
  return Join-Path $ReportRoot $relative
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
    Symbol = $Test.Symbol
    Window = $Test.Window
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

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mql5Root = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$reportDir = Join-Path $terminalDataRoot 'reports\oanda_eurusd_xauusd_same_manifold_20260619'
$ManifestPath = Join-Path $reportDir 'pass2012_shifted_windows_manifest.csv'
$ProgressPath = Join-Path $reportDir 'pass2012_shifted_windows_progress.csv'
$TempConfigPath = Join-Path $scriptRoot 'oanda_pass2012_shifted_window_current.ini'
$setFile = 'ImpulseContinuation_OANDA_SameManifold_Pass2012.set'

if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$setPath = Join-Path $testerProfilesDir $setFile
if (-not (Test-Path -LiteralPath $setPath)) {
  throw "Set file not found: $setPath"
}

Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $reportDir 'Run-OANDA-Pass2012-ShiftedWindows-20260620.ps1') -Force
Copy-Item -LiteralPath $setPath -Destination (Join-Path $reportDir $setFile) -Force

$windows = @(
  [pscustomobject]@{ Name = 'W2003_2010'; From = '2003.01.01'; To = '2010.01.01' },
  [pscustomobject]@{ Name = 'W2010_2017'; From = '2010.01.01'; To = '2017.01.01' },
  [pscustomobject]@{ Name = 'W2017_2026'; From = '2017.01.01'; To = '2026.06.01' }
)

$Symbol = @(Expand-FilterValues $Symbol)
$Window = @(Expand-FilterValues $Window)

$selectedWindows = @($windows | Where-Object { $Window -contains $_.Name })
if ($selectedWindows.Count -eq 0) {
  throw 'No selected shifted windows matched available windows.'
}

if ($Symbol.Count -eq 0) {
  throw 'No symbols selected.'
}

$generatedManifest = New-Object System.Collections.Generic.List[object]
$testIndex = 1
foreach ($symbolName in $Symbol) {
  foreach ($windowInfo in $selectedWindows) {
    $dateLabel = ($windowInfo.From -replace '\.', '') + '_' + ($windowInfo.To -replace '\.', '')
    $report = "reports\oanda_eurusd_xauusd_same_manifold_20260619\$($symbolName)_Pass2012_Shifted_$($windowInfo.Name)_$dateLabel.xml"
    $testId = ('{0:D3}_Pass2012_{1}_{2}' -f $testIndex, $symbolName, $windowInfo.Name)

    $generatedManifest.Add([pscustomobject]@{
      TestIndex = $testIndex
      TestId = $testId
      Symbol = $symbolName
      Window = $windowInfo.Name
      FromDate = $windowInfo.From
      ToDate = $windowInfo.To
      SetFile = $setFile
      Report = $report
      ExpectedReport = "$report.htm"
    })

    $testIndex++
  }
}

$generatedManifest | Export-Csv -LiteralPath $ManifestPath -NoTypeInformation -Encoding ASCII

Write-Host "Report directory: $reportDir"
Write-Host "Manifest: $ManifestPath"
Write-Host "Progress log: $ProgressPath"
Write-Host "Manifest tests: $($generatedManifest.Count)"
$generatedManifest | Format-Table TestIndex, TestId, Symbol, Window, FromDate, ToDate -AutoSize

if ($PrepareOnly) {
  Write-Host 'PrepareOnly set. No MT5 tests were run.'
  return
}

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

$manifest = Import-Csv -LiteralPath $ManifestPath | Sort-Object { [int]$_.TestIndex }
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
  Write-Host "Running $($test.TestIndex)/$($generatedManifest.Count): $($test.TestId)"
  Write-Host "$($test.Symbol) $($test.Window) $($test.FromDate) -> $($test.ToDate)"
  Write-Host '====================================='

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
    "ExpertParameters=$($test.SetFile)",
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
