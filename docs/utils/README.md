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

## TDTS EURUSD Ephemeral Generator Runner

Use `Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1` for the active EURUSD baseline generator run.

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ThreeDayTrendSignal\Run-TDTS-EURUSD-EphemeralGenerator.ps1
```

Default hyperparameters:

- IS: `5` years.
- Validation: `6` months.
- OOS: `12` months.
- Primary OOS horizon: first `3` months.
- Rolling step: `1` month.

Restart behavior:

- Rerun the same command to resume.
- Completed optimizer XML files and fixed-test `.xml.htm` reports are skipped.
- Validation ranking selects exactly one OOS candidate per completed window; it does not use a validation pass/fail filter that can select nothing.
- Unprofitable OOS reports are recorded and do not stop the runner.

Useful options:

- `-MaxWindows 1` limits the session to one monthly window.
- `-MaxFixedTests 10` limits fixed validation/OOS tests in the current session.
- `-StartAtWindow 25` starts scanning from a later monthly window.
- `-PrepareOnly` writes the windows file and current optimizer config without launching MT5.

Outputs are written under the terminal data folder in `reports\tdts_eg_eurusd_is5y_val6m_oos12m_step1m` by default.

## Legacy Rolling Manifold Cycle Runner

Use `Files/WeekHighLow/Run-RollingManifoldCycle.ps1` to run one configurable loop of the rolling short-horizon manifold workflow.

Safe preparation example, which creates the optimizer config and stops if the optimizer XML does not already exist:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\WeekHighLow\Run-RollingManifoldCycle.ps1 `
  -CycleId RM_2012Q1 `
  -OptimizationStart 2007.01.01 `
  -OptimizationEnd 2012.01.01 `
  -ValidationStart 2012.01.01 `
  -ValidationEnd 2012.02.01 `
  -DeployStart 2012.02.01 `
  -DeployEnd 2012.05.01 `
  -PrepareOnly
```

Normal run example:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\WeekHighLow\Run-RollingManifoldCycle.ps1 `
  -CycleId RM_2012Q2_STRICT `
  -OptimizationStart 2007.01.01 `
  -OptimizationEnd 2012.01.01 `
  -ValidationStart 2012.01.01 `
  -ValidationEnd 2012.04.01 `
  -DeployStart 2012.04.01 `
  -DeployEnd 2012.07.01 `
  -TopCandidateCount 25 `
  -MaxCandidatesAfterSanity 10 `
  -ValidationMinPassingSymbols 2 `
  -MaxRuntimeMinutes 10
```

This runner belongs to the older EURUSD-discovery plus cross-symbol-promotion workflow. Treat it as legacy scaffolding unless it is revised for the active per-symbol Ephemeral Manifold Generator process.

The script selects final `m^` after validation, not immediately after optimization-window cross-symbol testing. Optimization-window non-EURUSD tests are weak sanity filters only. Deployment tests enable CSV logging and write an expected common-files CSV named `manifold_trades_<m^>.csv` for later FTMO replay.

The old stricter defaults require the discovery symbol to pass validation and require at least `2` validation-passing symbols. Use `-AllowValidationWithoutDiscoverySymbol` only for diagnostic runs where EURUSD is not required to remain in `S^`.

Useful options:

- `-ExistingOptimizerXml` reuses a completed optimizer spreadsheet instead of running genetic optimization.
- `-SkipOptimizationRun` requires an existing optimizer XML and skips the optimizer launch.
- `-SkipFixedRuns` analyzes existing fixed reports without launching new fixed tests.
- `-MaxTests` runs only a limited number of fixed tests in the current session; rerun the same command to resume.
- `-RunExistingReports` reruns tests even when reports already exist.
- `-Symbols` overrides the default FX28 symbol universe.
- `-SanityRequireDiscoverySymbol` requires `EURUSD` to pass the sanity stage.
- `-AllowValidationWithoutDiscoverySymbol` disables the default requirement that `EURUSD` must pass validation.

## Notes

- Files in `docs/results` are treated as ephemeral working artifacts.
- Record durable findings in `docs/experiment-log.md`, not only in generated reports.
