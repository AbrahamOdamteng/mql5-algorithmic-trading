param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ManifestPath = (Join-Path $PSScriptRoot 'expanded_basket_manifest.csv'),
  [string]$ProgressPath = (Join-Path $PSScriptRoot 'expanded_basket_progress.csv'),
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'expanded_basket_current.ini'),
  [int]$MaxRuntimeMinutes = 10,
  [int]$PollSeconds = 30,
  [int]$StartAtIndex = 1,
  [int]$MaxTests = 0,
  [switch]$ClearTesterCache,
  [switch]$EnableTradeCsvLogging,
  [switch]$RunExistingReports,
  [string[]]$ManifoldId = @(),
  [string[]]$Symbol = @()
)

$testerCachePath = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*'

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
  throw "Manifest not found: $ManifestPath. Run New-ExpandedBasketBatch.ps1 first."
}

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

$ManifoldId = Expand-FilterValues $ManifoldId
$Symbol = Expand-FilterValues $Symbol

$manifest = Import-Csv -LiteralPath $ManifestPath | Sort-Object { [int]$_.TestIndex }
if ($ManifoldId.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $ManifoldId -contains $_.ManifoldId })
}
if ($Symbol.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $Symbol -contains $_.Symbol })
}
if ($manifest.Count -eq 0) {
  throw "Manifest has no tests after filters: $ManifestPath"
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

$mql5Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$tempSetFile = 'ImpulseContinuation_ExpandedBasket_Current.set'
$tempSetPath = Join-Path $testerProfilesDir $tempSetFile
$expandedReportDir = Join-Path $terminalDataRoot 'reports\expanded_basket'
if (-not (Test-Path -LiteralPath $expandedReportDir)) {
  New-Item -ItemType Directory -Path $expandedReportDir -Force | Out-Null
}

Write-Host "Report directory: $expandedReportDir"
Write-Host "Progress log: $ProgressPath"

function Convert-ReportPathToFullPath {
  param([string]$ExpectedReport)
  $relative = $ExpectedReport -replace '/', '\'
  return Join-Path $reportRoot $relative
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
    Symbol = $Test.Symbol
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
  param([object]$Test)

  $sourceSetPath = Join-Path $testerProfilesDir $Test.SetFile
  if (-not (Test-Path -LiteralPath $sourceSetPath)) {
    throw "Set file not found: $sourceSetPath"
  }

  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [System.IO.File]::ReadAllLines($sourceSetPath)) {
    $lines.Add($line)
  }

  Set-InputLine -Lines $lines -Name 'g_EnableTradeCsvLogging' -Value 'true'
  Set-InputLine -Lines $lines -Name 'g_TradeCsvManifoldId' -Value $Test.ManifoldId -PlainString
  Set-InputLine -Lines $lines -Name 'g_TradeCsvTestId' -Value $Test.TestId -PlainString

  [System.IO.File]::WriteAllLines($tempSetPath, $lines, [System.Text.Encoding]::ASCII)
  return $tempSetFile
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

  $expectedReportPath = Convert-ReportPathToFullPath $test.ExpectedReport
  if (-not $RunExistingReports -and ($completedByProgress.ContainsKey($test.TestId) -or (Test-Path -LiteralPath $expectedReportPath))) {
    if (-not $completedByProgress.ContainsKey($test.TestId)) {
      Append-Progress -Test $test -Status 'SkippedExistingReport' -DurationSeconds 0 -ReportPath $expectedReportPath -Note 'Report already existed before run.'
    }
    continue
  }

  Write-Host ""
  Write-Host "====================================="
  Write-Host "Running $($test.TestIndex)/$($manifest.Count): $($test.TestId)"
  Write-Host "$($test.Symbol) $($test.Segment) $($test.FromDate) -> $($test.ToDate)"
  Write-Host "====================================="

  if ($ClearTesterCache) {
    Write-Host 'Clearing tester cache'
    Remove-Item $testerCachePath -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
  }

  $expertParameters = $test.SetFile
  if ($EnableTradeCsvLogging) {
    $expertParameters = New-TestSetFile -Test $test
  }

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
Write-Host ""
Write-Host "Session complete. Tests run this session: $testsRunThisSession"
Write-Host "Overall duration: $($overallDuration.ToString())"
Write-Host "Progress log: $ProgressPath"
