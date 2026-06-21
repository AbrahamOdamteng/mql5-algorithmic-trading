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

## Manifold Symbol Cluster Review

Use `Analyze-ManifoldSymbolClusters.ps1` to find symbol pairs, triples, or larger groups that work well under the same manifold. This is useful when a manifold is not robust across the full basket but may be useful on a smaller symbol cluster.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Analyze-ManifoldSymbolClusters.ps1 `
  -ReportsDir ..\reports\funded_cross_symbol `
  -Segments VAL,OOS `
  -MinGroupSize 2 `
  -MaxGroupSize 4
```

Useful options:

- `-Segments IS,VAL` reviews discovery-safe groups without OOS. `-Segments VAL,OOS` reviews forward plus OOS behavior.
- `-SymbolMode ProfitableAll` keeps symbols profitable in every selected segment.
- `-SymbolMode AcceptedAll` keeps only symbols that pass profit, ratio, and drawdown criteria in every selected segment.
- `-SymbolMode AnyReport` includes all symbols with complete selected reports so weak rows remain visible.
- `-Csv` outputs ranked groups for spreadsheet review.

## Fixed Report First Trade Date

Use `Get-Mt5ReportFirstTradeDate.ps1` to extract the first EA trade/order timestamp from fixed MT5 `.xml.htm` reports. This is useful for checking effective symbol start coverage when a test is requested from an earlier date than the broker's usable history.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Get-Mt5ReportFirstTradeDate.ps1 `
  -ReportsDir .\docs\results\start_date_probe `
  -Pattern '*StartProbe*.xml.htm'
```

Important limitation: this reports the first EA trade/order event in the report, not the broker's first raw historical bar. A strategy may need warmup bars before the first trade/order appears.

## Expanded Basket Restartable Runner

Use `New-ExpandedBasketBatch.ps1` to generate fixed candidate presets and the full `12`-symbol expanded-basket manifest from `Files/WeekHighLow/expanded_basket_candidates.csv`.

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\WeekHighLow\New-ExpandedBasketBatch.ps1
```

Use `Run-ExpandedBasketRestartable.ps1` to run the manifest. The runner writes progress to `Files/WeekHighLow/expanded_basket_progress.csv`, writes reports under the terminal data folder `reports/expanded_basket`, and skips tests whose expected `.xml.htm` report already exists. Restarting the same command resumes from completed reports/progress.

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\WeekHighLow\Run-ExpandedBasketRestartable.ps1
```

Useful options:

- `-MaxRuntimeMinutes 10` changes the per-test timeout. The default is `10` minutes per test.
- `-StartAtIndex 1000` starts scanning from a specific manifest row.
- `-MaxTests 50` runs only a limited number of new tests in the current session.
- `-ClearTesterCache` clears the MT5 tester cache before each test.
- `-EnableTradeCsvLogging` creates a temporary per-test preset that enables CSV logging and injects `g_TradeCsvManifoldId` plus `g_TradeCsvTestId`.
- `-RunExistingReports` reruns tests even when the expected report already exists. This is useful when reports have already been generated but trade CSV files still need to be created.
- `-ManifoldId RUN1_Pass2794,RUN1_Pass3059` limits the run to specific manifolds.
- `-Symbol EURUSD,GBPUSD,XAUUSD,XAGUSD` limits the run to specific symbols.

`Files/WeekHighLow/autorun.ps1` is a wrapper around the restartable runner and forwards any supplied options.

Example CSV replay run for a limited batch:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\WeekHighLow\Run-ExpandedBasketRestartable.ps1 `
  -EnableTradeCsvLogging `
  -RunExistingReports `
  -ManifoldId RUN1_Pass2794,RUN1_Pass3059 `
  -Symbol EURUSD,GBPUSD,XAUUSD,XAGUSD `
  -MaxTests 20
```

When `g_TradeCsvManifoldId` is set, the EA writes to `manifold_trades_<manifold_id>.csv` in the MT5 common files area and appends rows for each symbol/segment test. The CSV includes `manifold_id` and `test_id` columns so later analysis can sort by `deal_time` and dedupe reruns.

Current shortlisted core replay command:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\WeekHighLow\Run-ExpandedBasketRestartable.ps1 `
  -EnableTradeCsvLogging `
  -RunExistingReports `
  -ManifoldId RUN1_Pass2794,RUN1_Pass3059,RUN1_Pass1991,RUN2_Pass5578,RUN2_Pass5191 `
  -Symbol EURUSD,GBPUSD,XAUUSD,XAGUSD
```

Cleanup guidance after report-level analysis:

- Safe to delete generated fixed-report artifacts under the terminal data folder `reports/expanded_basket` after durable findings have been recorded.
- Preserve `Files/WeekHighLow/expanded_basket_candidates.csv`, `expanded_basket_manifest.csv`, and `expanded_basket_progress.csv` for candidate identity and auditability.
- Preserve generated `Profiles/Tester/ImpulseContinuation_ExpandedBasket_*.set` files unless the batch is deliberately regenerated.
- Preserve any generated `manifold_trades_*.csv` files for FTMO analysis.

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

## Behavior Cluster Analysis

The planned symbol-specific cluster workflow needs additional utilities or extensions. See `docs/behavior-clusters.md` for the research definition.

Required analysis capabilities:

- Normalize candidate parameters by tested range and calculate pairwise manifold distance.
- Match trades between two manifolds using symbol, direction, entry-time tolerance, and optional price tolerance.
- Report `OverlapCoverage`, `JaccardOverlap`, and `TradeDistance` for candidate pairs.
- Assign candidates into behavior clusters so clone-like parameter sets are not counted as independent strategy units.
- Select random or median representatives from accepted behavior clusters.
- Replay portfolios built from `symbol + behavior cluster` units against challenge `+10%`, verification `+5%`, daily loss, global loss, pass-rate-first grading, and consistency diagnostics.

## Notes

- Files in `docs/results` are treated as ephemeral working artifacts.
- Record durable findings in `docs/experiment-log.md`, not only in generated reports.
