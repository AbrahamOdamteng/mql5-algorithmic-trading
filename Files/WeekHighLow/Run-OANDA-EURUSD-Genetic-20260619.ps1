param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [int]$TimeoutMinutes = 1440,
  [switch]$PrepareOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mql5Root = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root

$iniPath = Join-Path $scriptRoot 'OANDA_EURUSD_Genetic_20260619.ini'
$setPath = Join-Path $mql5Root 'Profiles\Tester\ImpulseContinuation_OANDA_EURUSD_Genetic_20260619.set'
$reportDir = Join-Path $terminalDataRoot 'reports\oanda_eurusd_xauusd_same_manifold_20260619'

if (-not (Test-Path -LiteralPath $iniPath)) {
  throw "INI file not found: $iniPath"
}

if (-not (Test-Path -LiteralPath $setPath)) {
  throw "SET file not found: $setPath"
}

if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Copy-Item -LiteralPath $iniPath -Destination (Join-Path $reportDir 'OANDA_EURUSD_Genetic_20260619.ini') -Force
Copy-Item -LiteralPath $setPath -Destination (Join-Path $reportDir 'ImpulseContinuation_OANDA_EURUSD_Genetic_20260619.set') -Force
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $reportDir 'Run-OANDA-EURUSD-Genetic-20260619.ps1') -Force

"Prepared OANDA EURUSD genetic experiment."
"Reports directory: $reportDir"
"INI snapshot: $(Join-Path $reportDir 'OANDA_EURUSD_Genetic_20260619.ini')"
"SET snapshot: $(Join-Path $reportDir 'ImpulseContinuation_OANDA_EURUSD_Genetic_20260619.set')"

if ($PrepareOnly) {
  "PrepareOnly set. No MT5 test was run."
  return
}

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

$start = Get-Date
"Starting OANDA EURUSD genetic run at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"

$process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$iniPath`"" -PassThru
$completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
$end = Get-Date

if (-not $completed) {
  Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  throw "Timed out OANDA_EURUSD_Genetic_20260619.ini after $TimeoutMinutes minutes."
}

$process.Refresh()
$status = if ($process.ExitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }
"Finished OANDA EURUSD genetic run with status $status in $([math]::Round(($end - $start).TotalMinutes, 2)) minutes"
"Exit code: $($process.ExitCode)"
