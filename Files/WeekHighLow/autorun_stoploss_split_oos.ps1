$mt5 = "C:\Program Files\MetaTrader 5\terminal64.exe"
$maxRuntimeMinutes = 10
$clearTesterCacheBeforeEachRun = $false
$testerCachePath = "C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*"

$configs = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "EURUSD_D1StopLossSplit_RUN*_Pass*_OOS.ini" |
    Sort-Object Name |
    Select-Object -ExpandProperty Name

$overallStartTime = Get-Date

foreach ($config in $configs) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host "Running OOS test for $config"
    Write-Host "====================================="

    if ($clearTesterCacheBeforeEachRun) {
        Write-Host "Clearing tester cache"
        Remove-Item $testerCachePath -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }

    $configPath = Join-Path $PSScriptRoot $config
    $startTime = Get-Date
    $process = Start-Process -FilePath $mt5 -ArgumentList "/config:`"$configPath`"" -PassThru

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
