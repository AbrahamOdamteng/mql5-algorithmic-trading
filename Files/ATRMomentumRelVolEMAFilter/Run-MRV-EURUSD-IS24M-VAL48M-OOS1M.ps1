param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [datetime]$FirstOosStart = '2025-01-01',
  [datetime]$LastOosStart = '2025-04-01',
  [ValidateSet('Score', 'Profit', 'Trades', 'LowestTrades', 'PositiveLowestTrades', 'PositiveLowestTradesThenDD', 'PositiveLowestTradesHardGates', 'PositiveLowestTradesQualityFloor', 'PositiveLowestTradesFinalMonth', 'PositiveBestRatio', 'PositiveHighestPF', 'PositiveTradeBand', 'LowestDD', 'HighestDD')]
  [string]$ValidationSelectionMode = 'PositiveBestRatio',
  [int]$TopOptimizerCandidates = 25,
  [int]$StartAtWindow = 1,
  [int]$MaxWindows = 0,
  [int]$MaxFixedTests = 0,
  [int]$OptimizationTimeoutMinutes = 1440,
  [int]$MaxRuntimeMinutes = 20,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$ClearTesterCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runner = Join-Path $PSScriptRoot 'Run-MRV-EURUSD-EphemeralGenerator.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "Runner not found: $runner" }

$runnerArgs = @{
  TerminalPath = $TerminalPath
  ExperimentId = 'mrv_ema_eg_eurusd_2025_is24m_val48m_oos1m_step1m'
  FirstOosStart = $FirstOosStart
  LastOosStart = $LastOosStart
  ISMonths = 24
  ValidationMonths = 48
  OosMonths = 1
  PrimaryOosMonths = 1
  StepMonths = 1
  TopOptimizerCandidates = $TopOptimizerCandidates
  ValidationSelectionMode = $ValidationSelectionMode
  StartAtWindow = $StartAtWindow
  MaxWindows = $MaxWindows
  MaxFixedTests = $MaxFixedTests
  OptimizationTimeoutMinutes = $OptimizationTimeoutMinutes
  MaxRuntimeMinutes = $MaxRuntimeMinutes
}

if ($PrepareOnly) { $runnerArgs.PrepareOnly = $true }
if ($RunExistingReports) { $runnerArgs.RunExistingReports = $true }
if ($ClearTesterCache) { $runnerArgs.ClearTesterCache = $true }

& $runner @runnerArgs
