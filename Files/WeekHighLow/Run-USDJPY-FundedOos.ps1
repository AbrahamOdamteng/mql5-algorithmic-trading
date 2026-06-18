param(
  [string]$TerminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe",
  [int]$TimeoutMinutes = 30,
  [switch]$StopOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$iniFiles = @(
  'USDJPY_Funded_Pass3363_OOS.ini',
  'USDJPY_Funded_Pass3401_OOS.ini',
  'USDJPY_Funded_Pass2650_OOS.ini',
  'USDJPY_Funded_Pass3563_OOS.ini',
  'USDJPY_Funded_Pass1583_OOS.ini',
  'USDJPY_Funded_Pass2185_OOS.ini',
  'USDJPY_Funded_Pass1811_OOS.ini',
  'USDJPY_Funded_Pass2402_OOS.ini'
)

if (-not (Test-Path -LiteralPath $TerminalPath)) {
  throw "MT5 terminal not found: $TerminalPath"
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
$results | Format-Table -AutoSize
