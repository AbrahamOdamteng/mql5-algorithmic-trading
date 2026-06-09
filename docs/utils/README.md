# MT5 Result Utilities

These PowerShell scripts parse MT5 tester result files so review logic does not need to be recreated each session.

## Optimizer + Forward Review

Use `Analyze-Mt5OptimizerForward.ps1` for MT5 optimizer XML spreadsheets and matching `.forward.xml` spreadsheets.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Analyze-Mt5OptimizerForward.ps1 `
  -OptimizerXml .\docs\results\example.xml `
  -ForwardXml .\docs\results\example.forward.xml
```

Useful options:

- `-Csv` outputs the loose-filter candidates as CSV.
- `-Top 50` changes how many candidates are printed.
- `-MinRatio`, `-MaxDrawdownPct`, `-StrictMinInSampleTrades`, `-StrictMinForwardTrades`, `-LooseMinInSampleTrades`, and `-LooseMinForwardTrades` adjust review thresholds.

## Fixed OOS Report Review

Use `Analyze-Mt5OosReports.ps1` for fixed single-test `.xml.htm` reports.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Analyze-Mt5OosReports.ps1 `
  -ReportsDir .\docs\results\reports `
  -Pattern 'EURUSD_D1HighLow_Clustered_Pass*_OOS_*.xml.htm'
```

Useful options:

- `-Csv` outputs all parsed reports as CSV sorted by ratio.
- `-Top 50` changes how many profitable candidates are printed.
- `-MinRatio`, `-MaxDrawdownPct`, and `-StartingDeposit` adjust acceptance calculations.

## Fixed Report First Trade Date

Use `Get-Mt5ReportFirstTradeDate.ps1` to extract the first EA trade/order timestamp from fixed MT5 `.xml.htm` reports. This is useful for checking effective symbol start coverage when a test is requested from an earlier date than the broker's usable history.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Get-Mt5ReportFirstTradeDate.ps1 `
  -ReportsDir .\docs\results\start_date_probe `
  -Pattern '*StartProbe*.xml.htm'
```

Important limitation: this reports the first EA trade/order event in the report, not the broker's first raw historical bar. A strategy may need warmup bars before the first trade/order appears.

## Closed-PnL FTMO Survivability

Use `Analyze-FtmoClosedPnlSurvivability.ps1` for rolling FTMO-style survivability checks from the trade CSV logger output.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Analyze-FtmoClosedPnlSurvivability.ps1 `
  -CsvPath .\docs\results\all_symbols_oanda_trades.csv `
  -DetailsPath .\docs\results\ftmo_closed_pnl_survivability.csv
```

Useful options:

- `-AccountPerSymbol` changes the assumed capital allocation per symbol. Default is `100000`.
- `-SymbolCount` overrides the inferred unique-symbol count.
- `-DailyLossPct`, `-GlobalLossPct`, and `-ProfitTargetPct` adjust FTMO-style rule thresholds.
- `-StartEventType OUT` starts each simulation from every closed trade event, which is the default because realized P/L is booked on `OUT` rows.
- `-PnlMode NormalizedRisk` replays each closed trade as an approximate R-multiple instead of using raw CSV profit.
- `-StartingBalance 100000`, `-OriginalRiskPct 1.0`, and `-CommunalRiskPct 0.25` model a single communal FTMO account risking a fixed percentage of current balance per trade.
- `-Csv` outputs per-start simulation rows to stdout.

Important limitation: this is a closed-PnL proxy. It does not know intratrade floating equity, so it can miss equity-based daily loss, global loss, or profit-target touches that happened before a trade closed.

Newer trade CSV logs include `trade_id` from MT5 `DEAL_POSITION_ID` and `risk_percentage` from `g_Risk_Percentage`. Older logs may not have these columns, so analysis scripts should remain tolerant of missing fields when reviewing historical CSV files.

## Notes

- Files in `docs/results` are treated as ephemeral working artifacts.
- Record durable findings in `docs/experiment-log.md`, not only in generated reports.
