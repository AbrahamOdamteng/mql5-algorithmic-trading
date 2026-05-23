$mt5 = "C:\Program Files\MetaTrader 5\terminal64.exe"

$configs = @(
    "EURUSD.ini"
    # "GBPUSD.ini"
    # "USDJPY.ini",
    # "USDCHF.ini",
    # "USDCAD.ini",
    # "AUDUSD.ini",
    # "NZDUSD.ini",

    # "EURJPY.ini",
    # "GBPJPY.ini",
    # "AUDJPY.ini",
    # "CADJPY.ini",
    # "CHFJPY.ini",
    # "NZDJPY.ini",

    # "EURGBP.ini",
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

    # "CADCHF.ini",

    # "XAUUSD.ini",
    # "XAGUSD.ini"
)

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

    $process.WaitForExit()

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "Finished $config"
    Write-Host "Duration: $($duration.ToString())"
}

