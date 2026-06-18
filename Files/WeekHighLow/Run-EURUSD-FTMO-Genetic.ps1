param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [int]$TimeoutMinutes = 1440
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$iniPath = Join-Path $scriptRoot 'EURUSD_FTMO_Genetic.ini'
$reportDir = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\reports\ftmo_eurusd_d1_stoploss_split_genetic_20260617'

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
}

if (-not (Test-Path -LiteralPath $iniPath)) {
  throw "INI file not found: $iniPath"
}

if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir | Out-Null
}

$start = Get-Date
"Starting EURUSD FTMO genetic run at $($start.ToString('yyyy-MM-dd HH:mm:ss'))"
"Reports directory: $reportDir"

$process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$iniPath`"" -PassThru
$completed = $process.WaitForExit([int]($TimeoutMinutes * 60 * 1000))
$end = Get-Date

if (-not $completed) {
  Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  throw "Timed out EURUSD_FTMO_Genetic.ini after $TimeoutMinutes minutes."
}

$process.Refresh()
$status = if ($process.ExitCode -eq 0) { 'Completed' } else { 'ExitedNonZero' }
"Finished EURUSD FTMO genetic run with status $status in $([math]::Round(($end - $start).TotalMinutes, 2)) minutes"
"Exit code: $($process.ExitCode)"
