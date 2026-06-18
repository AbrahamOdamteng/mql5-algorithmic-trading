param(
  [string]$TerminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe",
  [int]$TimeoutMinutes = 30,
  [switch]$KeepExistingCsv,
  [switch]$StopOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$terminalRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot '..\..\..')).Path
$reportsDir = Join-Path $terminalRoot 'reports\provisional_eurusd_usdjpy_funded'
$commonFilesDir = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$csvFile = Join-Path $commonFilesDir 'manifold_trades_Provisional_EURUSD3441_USDJPY1811_FundedOOS.csv'

$iniFiles = @(
  'ProvisionalPortfolio_EURUSD_Pass3441_Csv.ini',
  'ProvisionalPortfolio_USDJPY_Pass1811_Csv.ini'
)

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

if (-not (Test-Path -LiteralPath $reportsDir)) {
  New-Item -ItemType Directory -Path $reportsDir | Out-Null
}

if (-not (Test-Path -LiteralPath $commonFilesDir)) {
  New-Item -ItemType Directory -Path $commonFilesDir | Out-Null
}

if ((-not $KeepExistingCsv) -and (Test-Path -LiteralPath $csvFile)) {
  Remove-Item -LiteralPath $csvFile -Force
  "Deleted existing portfolio CSV: $csvFile"
}

$results = New-Object System.Collections.Generic.List[object]
$batchStart = Get-Date

foreach ($iniFile in $iniFiles) {
  $iniPath = Join-Path $scriptRoot $iniFile
  if (-not (Test-Path -LiteralPath $iniPath)) {
    throw "INI file not found: $iniPath"
  }

  $start = Get-Date
  "Starting $iniFile at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"

  $process = Start-Process `
    -FilePath $TerminalPath `
    -ArgumentList "/config:`"$iniPath`"" `
    -PassThru

  $completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
  $end = Get-Date

  if (-not $completed) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $results.Add([pscustomobject]@{
      IniFile = $iniFile
      Status = 'TimedOut'
      ExitCode = $null
      Started = $start
      Ended = $end
      DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
    })

    "Timed out $iniFile after $TimeoutMinutes minutes"
    if ($StopOnFailure) {
      break
    }

    continue
  }

  $process.Refresh()
  $exitCode = $process.ExitCode
  $status = if ($exitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }

  $results.Add([pscustomobject]@{
    IniFile = $iniFile
    Status = $status
    ExitCode = $exitCode
    Started = $start
    Ended = $end
    DurationMinutes = [math]::Round(($end - $start).TotalMinutes, 2)
  })

  "Finished $iniFile with status $status in $([math]::Round(($end - $start).TotalMinutes, 2)) minutes"

  if ($StopOnFailure -and $status -ne 'Completed') {
    break
  }
}

"Batch finished in $([math]::Round(((Get-Date) - $batchStart).TotalMinutes, 2)) minutes"
"Portfolio CSV target: $csvFile"
$results | Format-Table -AutoSize
