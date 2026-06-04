$mt5 = "C:\Program Files\MetaTrader 5\terminal64.exe"
$maxRuntimeHours = 6

$configs = @(
    # "EURUSD.ini",
    # "GBPUSD.ini",
    # "USDJPY.ini",
    # "XAUUSD.ini",
    # "XAGUSD.ini",
    # "US30.ini",
    # "US500.ini",
    # "US100.ini", # Excluded: broker history starts 2014.09.15; MT5 can hang indefinitely for 2000-based tests.
    "UK100.ini"
    # "GBPUSD.ini",
    # "USDJPY.ini",
    # "USDCHF.ini",
    # "USDCAD.ini",
    # "AUDUSD.ini",
    # "NZDUSD.ini",

    # "EURJPY.ini"
    # "GBPJPY.ini",
    # "AUDJPY.ini"
    # "CADJPY.ini",
    # "CHFJPY.ini",
    # "NZDJPY.ini",

    # "EURGBP.ini"
    # "EURAUD.ini",
    # "EURNZD.ini",
    # "EURCAD.ini",
    # "EURCHF.ini",

    # "GBPAUD.ini",
    # "GBPNZD.ini",
    # "GBPCAD.ini",
    # "GBPCHF.ini",

    # "AUDNZD.ini",
    # "AUDCAD.ini",
    # "AUDCHF.ini",

    # "NZDCAD.ini",
    # "NZDCHF.ini",

    # "CADCHF.ini"

    # "XAUUSD.ini",
    # "XAGUSD.ini"
    # "XPTUSD.ini",
    # "XPDUSD.ini",

    # "US500.ini",
    # "US30.ini"
    # "US100.ini",
    # "US2000.ini"
    # "UK100.ini",
    # "WHEAT.ini",
    # "SOYBN.ini",
    # "AU200.ini",
    # "EU50.ini"
    # "HK50.ini"

)

$overallStartTime = Get-Date

foreach ($config in $configs) {

    Write-Host ""
    Write-Host "====================================="
    Write-Host "Running test for $config"
    Write-Host "====================================="


    Remove-Item `
      "C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*" `
      -Recurse -Force -ErrorAction SilentlyContinue

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
        if ($elapsed.TotalHours -ge $maxRuntimeHours) {
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
