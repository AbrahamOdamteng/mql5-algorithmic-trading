param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ManifestPath = (Join-Path $PSScriptRoot 'funded_cross_symbol_manifest.csv'),
  [string]$ProgressPath = (Join-Path $PSScriptRoot 'funded_cross_symbol_progress.csv'),
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'funded_cross_symbol_current.ini'),
  [int]$MaxRuntimeMinutes = 10,
  [int]$PollSeconds = 30,
  [int]$StartAtIndex = 1,
  [int]$MaxTests = 0,
  [switch]$RunExistingReports,
  [switch]$PrepareOnly,
  [string[]]$PassId = @(),
  [string[]]$Symbol = @(),
  [string[]]$Segment = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

function New-FundedCrossSymbolManifest {
  $passes = @(
    [pscustomobject]@{ Pass = '3441'; SetFile = 'ImpulseContinuation_EURUSD_Funded_Pass3441.set' },
    [pscustomobject]@{ Pass = '3044'; SetFile = 'ImpulseContinuation_EURUSD_Funded_Pass3044.set' },
    [pscustomobject]@{ Pass = '3634'; SetFile = 'ImpulseContinuation_EURUSD_Funded_Pass3634.set' },
    [pscustomobject]@{ Pass = '2303'; SetFile = 'ImpulseContinuation_EURUSD_Funded_Pass2303.set' },
    [pscustomobject]@{ Pass = '2396'; SetFile = 'ImpulseContinuation_EURUSD_Funded_Pass2396.set' }
  )

  $standardSegments = @(
    [pscustomobject]@{ Name = 'IS'; From = '2000.01.01'; To = '2012.01.01' },
    [pscustomobject]@{ Name = 'VAL'; From = '2012.01.01'; To = '2018.01.01' },
    [pscustomobject]@{ Name = 'OOS'; From = '2018.01.01'; To = '2026.06.01' }
  )

  $us100Segments = @(
    [pscustomobject]@{ Name = 'VAL'; From = '2014.09.15'; To = '2018.01.01' },
    [pscustomobject]@{ Name = 'OOS'; From = '2018.01.01'; To = '2026.06.01' }
  )

  $symbols = @(
    [pscustomobject]@{ Symbol = 'EURUSD'; Group = 'FX'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'GBPUSD'; Group = 'FX'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'USDJPY'; Group = 'FX'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'EURJPY'; Group = 'FX'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'XAUUSD'; Group = 'Metals'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'XAGUSD'; Group = 'Metals'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'US500'; Group = 'Indices'; Segments = $standardSegments },
    [pscustomobject]@{ Symbol = 'US100'; Group = 'Indices'; Segments = $us100Segments },
    [pscustomobject]@{ Symbol = 'UK100'; Group = 'Indices'; Segments = $standardSegments }
  )

  $manifest = New-Object System.Collections.Generic.List[object]
  $testIndex = 1

  foreach ($pass in $passes) {
    foreach ($symbol in $symbols) {
      foreach ($segment in $symbol.Segments) {
        $dateLabel = ($segment.From -replace '\.', '') + '_' + ($segment.To -replace '\.', '')
        $report = "reports\funded_cross_symbol\$($symbol.Symbol)_D1StopLossSplit_Funded_Pass$($pass.Pass)_$($segment.Name)_$dateLabel.xml"
        $testId = ('{0:D4}_Pass{1}_{2}_{3}' -f $testIndex, $pass.Pass, $symbol.Symbol, $segment.Name)

        $manifest.Add([pscustomobject]@{
          TestIndex = $testIndex
          TestId = $testId
          Pass = $pass.Pass
          Symbol = $symbol.Symbol
          MarketGroup = $symbol.Group
          Segment = $segment.Name
          FromDate = $segment.From
          ToDate = $segment.To
          SetFile = $pass.SetFile
          Report = $report
          ExpectedReport = "$report.htm"
        })

        $testIndex++
      }
    }
  }

  return $manifest
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

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

$mql5Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$fundedReportDir = Join-Path $terminalDataRoot 'reports\funded_cross_symbol'
if (-not (Test-Path -LiteralPath $fundedReportDir)) {
  New-Item -ItemType Directory -Path $fundedReportDir -Force | Out-Null
}

$generatedManifest = New-FundedCrossSymbolManifest
$generatedManifest | Export-Csv -LiteralPath $ManifestPath -NoTypeInformation -Encoding ASCII

Write-Host "Manifest: $ManifestPath"
Write-Host "Progress log: $ProgressPath"
Write-Host "Report directory: $fundedReportDir"
Write-Host "Manifest tests: $($generatedManifest.Count)"

if ($PrepareOnly) {
  Write-Host 'PrepareOnly set. No MT5 tests were run.'
  return
}

$PassId = @(Expand-FilterValues $PassId)
$Symbol = @(Expand-FilterValues $Symbol)
$Segment = @(Expand-FilterValues $Segment)

$manifest = Import-Csv -LiteralPath $ManifestPath | Sort-Object { [int]$_.TestIndex }
if ($PassId.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $PassId -contains $_.Pass })
}
if ($Symbol.Count -gt 0) {
  $manifest = @($manifest | Where-Object { $Symbol -contains $_.Symbol })
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

  $setPath = Join-Path $testerProfilesDir $test.SetFile
  if (-not (Test-Path -LiteralPath $setPath)) {
    throw "Set file not found: $setPath"
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
  Write-Host "$($test.Symbol) $($test.Segment) $($test.FromDate) -> $($test.ToDate)"
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
