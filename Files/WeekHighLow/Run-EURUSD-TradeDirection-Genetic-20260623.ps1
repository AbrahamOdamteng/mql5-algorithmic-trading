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

$iniPath = Join-Path $scriptRoot 'EURUSD_TradeDirection_Genetic_20260623.ini'
$setPath = Join-Path $mql5Root 'Profiles\Tester\ImpulseContinuation_EURUSD_TradeDirection_Genetic_20260623.set'
$reportDir = Join-Path $terminalDataRoot 'reports\eurusd_trade_direction_genetic_20260623'

if (-not (Test-Path -LiteralPath $iniPath)) {
  throw "INI file not found: $iniPath"
}

if (-not (Test-Path -LiteralPath $setPath)) {
  throw "SET file not found: $setPath"
}

if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Copy-Item -LiteralPath $iniPath -Destination (Join-Path $reportDir 'EURUSD_TradeDirection_Genetic_20260623.ini') -Force
Copy-Item -LiteralPath $setPath -Destination (Join-Path $reportDir 'ImpulseContinuation_EURUSD_TradeDirection_Genetic_20260623.set') -Force
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $reportDir 'Run-EURUSD-TradeDirection-Genetic-20260623.ps1') -Force

"Prepared EURUSD trade-direction genetic experiment."
"Reports directory: $reportDir"
"INI snapshot: $(Join-Path $reportDir 'EURUSD_TradeDirection_Genetic_20260623.ini')"
"SET snapshot: $(Join-Path $reportDir 'ImpulseContinuation_EURUSD_TradeDirection_Genetic_20260623.set')"

if ($PrepareOnly) {
  "PrepareOnly set. No MT5 test was run."
  return
}

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

$start = Get-Date
"Starting EURUSD trade-direction genetic run at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"

$process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$iniPath`"" -PassThru
$completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
$end = Get-Date

if (-not $completed) {
  Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  throw "Timed out EURUSD_TradeDirection_Genetic_20260623.ini after $TimeoutMinutes minutes."
}

$process.Refresh()
$status = if ($process.ExitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }
"Finished EURUSD trade-direction genetic run with status $status in $([math]::Round(($end - $start).TotalMinutes, 2)) minutes"
"Exit code: $($process.ExitCode)"
