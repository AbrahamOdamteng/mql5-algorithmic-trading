param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ExperimentId = 'mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m_optm1ohlc',
  [datetime]$FirstOosStart = '2025-01-01',
  [datetime]$LastOosStart = '2025-06-01',
  [ValidateSet('ValidationScore', 'PositiveBestRatio', 'ValidationProfit', 'LowestValidationDD', 'HighestValidationPF', 'LowestValidationTrades', 'BackForwardScoreThenLowestDD', 'BackForwardScoreThenHighestProfit', 'BackForwardScoreThenHighestTrades', 'BackForwardScoreThenLowestTrades', 'BackForwardScoreThenHighestPF', 'BackForwardScoreThenHighestDD', 'BackForwardScoreFallbackHighestTrades')]
  [string]$ForwardSelectionMode = 'BackForwardScoreThenHighestTrades',
  [double]$MinBackScore = 90.0,
  [double]$MinForwardScore = 90.0,
  [int]$StartAtWindow = 1,
  [int]$MaxWindows = 0,
  [int]$MaxFixedTests = 0,
  [double]$MinISProfit = 0.0,
  [double]$MaxISDDPct = 30.0,
  [int]$MinISTrades = 40,
  [double]$MinValidationProfit = 0.0,
  [double]$MinValidationProfitFactor = 1.10,
  [double]$MaxValidationDDPct = 25.0,
  [int]$MinValidationTrades = 40,
  [int]$OptimizationTimeoutMinutes = 1440,
  [int]$MaxRuntimeMinutes = 20,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$ClearTesterCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runner = Join-Path $PSScriptRoot 'Run-MRV-EURUSD-ForwardPerturbationGenerator.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "Runner not found: $runner" }

$runnerArgs = @{
  TerminalPath = $TerminalPath
  ExperimentId = $ExperimentId
  TempSetFile = 'ATRMomentumRelVolEMAFilter_ForwardValidation_Generated.set'
  TempConfigPath = (Join-Path $PSScriptRoot 'mrv_ema_forward_validation_current.ini')
  FirstOosStart = $FirstOosStart
  LastOosStart = $LastOosStart
  ISMonths = 24
  ValidationMonths = 24
  OosMonths = 1
  StepMonths = 1
  MinISProfit = $MinISProfit
  MaxISDDPct = $MaxISDDPct
  MinISTrades = $MinISTrades
  MinValidationProfit = $MinValidationProfit
  MinValidationProfitFactor = $MinValidationProfitFactor
  MaxValidationDDPct = $MaxValidationDDPct
  MinValidationTrades = $MinValidationTrades
  ForwardSelectionMode = $ForwardSelectionMode
  OptimizationTimeoutMinutes = $OptimizationTimeoutMinutes
  MaxRuntimeMinutes = $MaxRuntimeMinutes
  StartAtWindow = $StartAtWindow
  MaxWindows = $MaxWindows
  MaxFixedTests = $MaxFixedTests
  SkipPerturbation = $true
  MinBackScore = $MinBackScore
  MinForwardScore = $MinForwardScore
}

if ($PrepareOnly) { $runnerArgs.PrepareOnly = $true }
if ($RunExistingReports) { $runnerArgs.RunExistingReports = $true }
if ($ClearTesterCache) { $runnerArgs.ClearTesterCache = $true }

& $runner @runnerArgs
