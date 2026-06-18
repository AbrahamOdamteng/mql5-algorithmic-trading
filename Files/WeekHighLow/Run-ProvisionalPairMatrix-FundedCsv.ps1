param(
  [string]$TerminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe",
  [int]$TimeoutMinutes = 30,
  [int[]]$EurUsdPassId = @(),
  [int[]]$UsdJpyPassId = @(),
  [switch]$KeepExistingCsv,
  [switch]$DryRun,
  [switch]$StopOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$terminalRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot '..\..\..')).Path
$profileDir = Join-Path $terminalRoot 'MQL5\Profiles\Tester'
$reportsDir = Join-Path $terminalRoot 'reports\provisional_pair_matrix_funded'
$commonFilesDir = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'

$eurusdCandidates = @(
  [pscustomobject]@{ Symbol = 'EURUSD'; Pass = 3441; SourceSet = 'ImpulseContinuation_EURUSD_Funded_Pass3441.set' },
  [pscustomobject]@{ Symbol = 'EURUSD'; Pass = 3044; SourceSet = 'ImpulseContinuation_EURUSD_Funded_Pass3044.set' },
  [pscustomobject]@{ Symbol = 'EURUSD'; Pass = 3634; SourceSet = 'ImpulseContinuation_EURUSD_Funded_Pass3634.set' },
  [pscustomobject]@{ Symbol = 'EURUSD'; Pass = 2303; SourceSet = 'ImpulseContinuation_EURUSD_Funded_Pass2303.set' },
  [pscustomobject]@{ Symbol = 'EURUSD'; Pass = 2396; SourceSet = 'ImpulseContinuation_EURUSD_Funded_Pass2396.set' }
)

$usdjpyCandidates = @(
  [pscustomobject]@{ Symbol = 'USDJPY'; Pass = 1811; SourceSet = 'ImpulseContinuation_USDJPY_Funded_Pass1811.set' },
  [pscustomobject]@{ Symbol = 'USDJPY'; Pass = 2402; SourceSet = 'ImpulseContinuation_USDJPY_Funded_Pass2402.set' },
  [pscustomobject]@{ Symbol = 'USDJPY'; Pass = 3363; SourceSet = 'ImpulseContinuation_USDJPY_Funded_Pass3363.set' },
  [pscustomobject]@{ Symbol = 'USDJPY'; Pass = 2698; SourceSet = 'ImpulseContinuation_USDJPY_Funded_Top20_Pass2698.set' }
)

if ($EurUsdPassId.Count -gt 0) {
  $eurusdCandidates = @($eurusdCandidates | Where-Object { $EurUsdPassId -contains $_.Pass })
}

if ($UsdJpyPassId.Count -gt 0) {
  $usdjpyCandidates = @($usdjpyCandidates | Where-Object { $UsdJpyPassId -contains $_.Pass })
}

if ($eurusdCandidates.Count -eq 0) {
  throw 'No EURUSD candidates selected.'
}

if ($usdjpyCandidates.Count -eq 0) {
  throw 'No USDJPY candidates selected.'
}

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

if (-not (Test-Path -LiteralPath $profileDir)) {
  throw "Tester profile directory not found: $profileDir"
}

if (-not (Test-Path -LiteralPath $reportsDir)) {
  New-Item -ItemType Directory -Path $reportsDir | Out-Null
}

if (-not (Test-Path -LiteralPath $commonFilesDir)) {
  New-Item -ItemType Directory -Path $commonFilesDir | Out-Null
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
    }
    else {
      $line
    }
  }

  if (-not $found) {
    $updated += $Value
  }

  return @($updated)
}

function New-PortfolioSetFile {
  param(
    [Parameter(Mandatory = $true)]$Candidate,
    [Parameter(Mandatory = $true)][string]$ManifoldId,
    [Parameter(Mandatory = $true)][string]$TestId
  )

  $sourcePath = Join-Path $profileDir $Candidate.SourceSet
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source preset not found: $sourcePath"
  }

  $lines = @(Get-Content -LiteralPath $sourcePath)
  $lines = Set-Or-AppendLine -Lines $lines -Name 'g_EnableTradeCsvLogging' -Value 'g_EnableTradeCsvLogging=true||false||0||true||N'
  $lines = Set-Or-AppendLine -Lines $lines -Name 'g_TradeCsvManifoldId' -Value "g_TradeCsvManifoldId=$ManifoldId"
  $lines = Set-Or-AppendLine -Lines $lines -Name 'g_TradeCsvTestId' -Value "g_TradeCsvTestId=$TestId"

  $targetName = "ImpulseContinuation_${ManifoldId}_${TestId}.set"
  $targetPath = Join-Path $profileDir $targetName
  Set-Content -LiteralPath $targetPath -Value $lines -Encoding ASCII

  return $targetName
}

function New-PortfolioIniFile {
  param(
    [Parameter(Mandatory = $true)]$Candidate,
    [Parameter(Mandatory = $true)][string]$SetFileName,
    [Parameter(Mandatory = $true)][string]$ManifoldId,
    [Parameter(Mandatory = $true)][string]$TestId
  )

  $iniName = "${ManifoldId}_${TestId}.ini"
  $iniPath = Join-Path $scriptRoot $iniName
  $reportName = "${ManifoldId}_${TestId}_20180101_20260601.xml"

  $content = @"
[Tester]
Expert=WeekHighLow\WeekHighLowEA.ex5
Symbol=$($Candidate.Symbol)
Period=H1

FromDate=2018.01.01
ToDate=2026.06.01

Model=4
Optimization=0
Visual=0

ExpertParameters=$SetFileName
Report=reports\provisional_pair_matrix_funded\$reportName

; ForwardMode=2
; OptimizationCriterion=7

ShutdownTerminal=1
"@

  Set-Content -LiteralPath $iniPath -Value $content -Encoding ASCII
  return $iniPath
}

$results = New-Object System.Collections.Generic.List[object]
$batchStart = Get-Date
$expectedTests = $eurusdCandidates.Count * $usdjpyCandidates.Count * 2

"Selected EURUSD passes: $($eurusdCandidates.Pass -join ', ')"
"Selected USDJPY passes: $($usdjpyCandidates.Pass -join ', ')"
"Expected MT5 tests: $expectedTests"
"Report directory: $reportsDir"

if ($DryRun) {
  $dryRunRows = foreach ($eur in $eurusdCandidates) {
    foreach ($jpy in $usdjpyCandidates) {
      $manifoldId = "Pair_EURUSD$($eur.Pass)_USDJPY$($jpy.Pass)_FundedOOS"
      $csvFile = Join-Path $commonFilesDir "manifold_trades_$manifoldId.csv"
      [pscustomobject]@{
        ManifoldId = $manifoldId
        EurUsdPass = $eur.Pass
        UsdJpyPass = $jpy.Pass
        Tests = 2
        CsvPath = $csvFile
      }
    }
  }

  $dryRunRows | Format-Table -AutoSize

  exit 0
}

foreach ($eur in $eurusdCandidates) {
  foreach ($jpy in $usdjpyCandidates) {
    $manifoldId = "Pair_EURUSD$($eur.Pass)_USDJPY$($jpy.Pass)_FundedOOS"
    $csvFile = Join-Path $commonFilesDir "manifold_trades_$manifoldId.csv"

    if ((-not $KeepExistingCsv) -and (Test-Path -LiteralPath $csvFile)) {
      Remove-Item -LiteralPath $csvFile -Force
      "Deleted existing pair CSV: $csvFile"
    }

    $components = @(
      [pscustomobject]@{ Candidate = $eur; TestId = "EURUSD_Pass$($eur.Pass)_OOS" },
      [pscustomobject]@{ Candidate = $jpy; TestId = "USDJPY_Pass$($jpy.Pass)_OOS" }
    )

    foreach ($component in $components) {
      $candidate = $component.Candidate
      $testId = $component.TestId
      $setFileName = New-PortfolioSetFile -Candidate $candidate -ManifoldId $manifoldId -TestId $testId
      $iniPath = New-PortfolioIniFile -Candidate $candidate -SetFileName $setFileName -ManifoldId $manifoldId -TestId $testId

      $start = Get-Date
      "Starting $manifoldId / $testId at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"

      $process = Start-Process `
        -FilePath $TerminalPath `
        -ArgumentList "/config:`"$iniPath`"" `
        -PassThru

      $completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
      $end = Get-Date

      if (-not $completed) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $results.Add([pscustomobject]@{
          ManifoldId = $manifoldId
          TestId = $testId
          Symbol = $candidate.Symbol
          Pass = $candidate.Pass
          Status = 'TimedOut'
          ExitCode = $null
          Started = $start
          Ended = $end
          DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
          CsvPath = $csvFile
        })

        "Timed out $manifoldId / $testId after $TimeoutMinutes minutes"
        if ($StopOnFailure) {
          break
        }

        continue
      }

      $process.Refresh()
      $exitCode = $process.ExitCode
      $status = if ($exitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }

      $results.Add([pscustomobject]@{
        ManifoldId = $manifoldId
        TestId = $testId
        Symbol = $candidate.Symbol
        Pass = $candidate.Pass
        Status = $status
        ExitCode = $exitCode
        Started = $start
        Ended = $end
        DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
        CsvPath = $csvFile
      })

      "Finished $manifoldId / $testId with status $status in $([math]::Round(($end - $start).TotalMinutes, 2)) minutes"

      if ($StopOnFailure -and $status -ne 'Completed') {
        break
      }
    }

    if ($StopOnFailure -and @($results | Where-Object { $_.Status -ne 'Completed' }).Count -gt 0) {
      break
    }
  }

  if ($StopOnFailure -and @($results | Where-Object { $_.Status -ne 'Completed' }).Count -gt 0) {
    break
  }
}

"Batch finished in $([math]::Round(((Get-Date) - $batchStart).TotalMinutes, 2)) minutes"
$results | Format-Table -AutoSize ManifoldId, TestId, Status, ExitCode, DurationMinutes
