$mt5 = "C:\Program Files\MetaTrader 5\terminal64.exe"
$maxRuntimeMinutes = 10

$configs = @(
    "GBPUSD_D1Clustered_Pass707_IS.ini",
    "GBPUSD_D1Clustered_Pass707_VAL.ini",
    "GBPUSD_D1Clustered_Pass707_OOS.ini",
    "USDJPY_D1Clustered_Pass707_IS.ini",
    "USDJPY_D1Clustered_Pass707_VAL.ini",
    "USDJPY_D1Clustered_Pass707_OOS.ini",
    "EURJPY_D1Clustered_Pass707_IS.ini",
    "EURJPY_D1Clustered_Pass707_VAL.ini",
    "EURJPY_D1Clustered_Pass707_OOS.ini",
    "XAUUSD_D1Clustered_Pass707_IS.ini",
    "XAUUSD_D1Clustered_Pass707_VAL.ini",
    "XAUUSD_D1Clustered_Pass707_OOS.ini",
    "US500_D1Clustered_Pass707_IS.ini",
    "US500_D1Clustered_Pass707_VAL.ini",
    "US500_D1Clustered_Pass707_OOS.ini",
    "US30_D1Clustered_Pass707_IS.ini",
    "US30_D1Clustered_Pass707_VAL.ini",
    "US30_D1Clustered_Pass707_OOS.ini",
    "GBPUSD_D1Clustered_Pass816_IS.ini",
    "GBPUSD_D1Clustered_Pass816_VAL.ini",
    "GBPUSD_D1Clustered_Pass816_OOS.ini",
    "USDJPY_D1Clustered_Pass816_IS.ini",
    "USDJPY_D1Clustered_Pass816_VAL.ini",
    "USDJPY_D1Clustered_Pass816_OOS.ini",
    "EURJPY_D1Clustered_Pass816_IS.ini",
    "EURJPY_D1Clustered_Pass816_VAL.ini",
    "EURJPY_D1Clustered_Pass816_OOS.ini",
    "XAUUSD_D1Clustered_Pass816_IS.ini",
    "XAUUSD_D1Clustered_Pass816_VAL.ini",
    "XAUUSD_D1Clustered_Pass816_OOS.ini",
    "US500_D1Clustered_Pass816_IS.ini",
    "US500_D1Clustered_Pass816_VAL.ini",
    "US500_D1Clustered_Pass816_OOS.ini",
    "US30_D1Clustered_Pass816_IS.ini",
    "US30_D1Clustered_Pass816_VAL.ini",
    "US30_D1Clustered_Pass816_OOS.ini",
    "GBPUSD_D1Clustered_Pass8_IS.ini",
    "GBPUSD_D1Clustered_Pass8_VAL.ini",
    "GBPUSD_D1Clustered_Pass8_OOS.ini",
    "USDJPY_D1Clustered_Pass8_IS.ini",
    "USDJPY_D1Clustered_Pass8_VAL.ini",
    "USDJPY_D1Clustered_Pass8_OOS.ini",
    "EURJPY_D1Clustered_Pass8_IS.ini",
    "EURJPY_D1Clustered_Pass8_VAL.ini",
    "EURJPY_D1Clustered_Pass8_OOS.ini",
    "XAUUSD_D1Clustered_Pass8_IS.ini",
    "XAUUSD_D1Clustered_Pass8_VAL.ini",
    "XAUUSD_D1Clustered_Pass8_OOS.ini",
    "US500_D1Clustered_Pass8_IS.ini",
    "US500_D1Clustered_Pass8_VAL.ini",
    "US500_D1Clustered_Pass8_OOS.ini",
    "US30_D1Clustered_Pass8_IS.ini",
    "US30_D1Clustered_Pass8_VAL.ini",
    "US30_D1Clustered_Pass8_OOS.ini"
)

$overallStartTime = Get-Date

foreach ($config in $configs) {

    Write-Host ""
    Write-Host "====================================="
    Write-Host "Running test for $config"
    Write-Host "====================================="

    # Cache deletion is intentionally disabled for fixed same-model batch runs.
    # Remove-Item `
    #   "C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*" `
    #   -Recurse -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 5

    $configPath = Join-Path $PSScriptRoot $config

    $startTime = Get-Date

    $process = Start-Process `
        -FilePath $mt5 `
        -ArgumentList "/config:`"$configPath`"" `
        -PassThru

    while (-not $process.HasExited) {
        Start-Sleep -Seconds 30
        $process.Refresh()

        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalMinutes -ge $maxRuntimeMinutes) {
            Write-Host "Timeout reached for $config after $($elapsed.ToString()). Stopping MT5 process."
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            break
        }
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "Finished $config"
    Write-Host "Duration: $($duration.ToString())"
}

$overallEndTime = Get-Date
$overallDuration = $overallEndTime - $overallStartTime
Write-Host "Overall Duration: $($overallDuration.ToString())"
