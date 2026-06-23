# Experiment Log

This file records experiments, code changes, tests, and observed outcomes for the WeekHighLow EA and indicator.

Update this log only when explicitly asked.

## Format

Each entry should include:

- Date
- Goal
- Change or experiment
- Test setup
- Outcome
- Decision or next step

## Entries

### 2026-06-02 - EURUSD Optimization And Forward Review

- Goal: Review the combined MT5 optimizer and forward-test results to determine whether any parameter manifold succeeded in both in-sample and validation periods.
- Source file: `docs/EURUSD_Optimize_2000_2018_FWD_OPT.xlsx`.
- Test setup: EURUSD MT5 optimization results amalgamated with MT5 optimizer forward results.
- Test periods: `2000 -> 2012` in-sample optimization, `2012 -> 2018` optimizer forward validation.
- Workbook structure: 1 worksheet, `23,100` data rows, `18` columns.
- Row breakdown: `21,000` optimizer rows and `2,100` forward rows.
- Pairing method: `Pass` links an `OPTIMIZER` row with its corresponding `FORWARD` row.
- Parameters tested: `g_ATR_Cluster_multiplier`, `g_impulse_lookback_hours`, `g_pullback_lookforward_hours`, `g_Impulse_ATR_multiplier`, `g_pullback_ATR_multiplier`, `g_TakeProfitMultiplier`.
- Acceptance criteria used: in-sample profit `> 0`, validation profit `> 0`, and equity drawdown `< 20%` in every test period.
- Result: `0` paired passes met the drawdown requirement. No row had equity drawdown below `20%` in both optimizer and forward periods.
- Additional observation: Without the drawdown requirement, `61` paired passes had positive optimizer profit, positive forward profit, and profit factor greater than `1` in both periods.
- Non-qualifying successful-profit region: most of the `61` positive-profit paired passes clustered around `g_ATR_Cluster_multiplier = 0.25`, `g_pullback_lookforward_hours = 24`, `g_pullback_ATR_multiplier = 0.35` or `0.40`, and `g_TakeProfitMultiplier = 3` or `5`.
- Best balanced non-qualifying candidate by positive profit in both periods: pass `16494`, using `g_ATR_Cluster_multiplier = 0.25`, `g_impulse_lookback_hours = 48`, `g_pullback_lookforward_hours = 24`, `g_Impulse_ATR_multiplier = 0.7`, `g_pullback_ATR_multiplier = 0.4`, `g_TakeProfitMultiplier = 4`; optimizer profit `57,996.88`, optimizer profit factor `1.038`, optimizer equity DD `71.63%`, forward profit `57,017.35`, forward profit factor `1.059`, forward equity DD `35.73%`.
- Decision or next step: This optimization/forward file does not contain an acceptable manifold under the current profit and drawdown rules. Further tests should prioritize reducing drawdown before evaluating out-of-sample `2018 -> 2026` performance.

### 2026-06-04 - Ratio-Based Review Criteria

- Goal: Replace the strict equity DD `< 20%` rule with a more useful criterion for percentage-risk and FTMO-style evaluation.
- Change or experiment: Adopted profit-to-drawdown ratio review, calculated as `(profit / starting deposit * 100) / Equity DD %`.
- Test setup: Starting deposit assumed to be `100,000` USD. Review criteria used profit `> 0`, profit/DD ratio `> 2.0`, diagnostic raw DD cap `<= 30%`, and trade-count context.
- Outcome: Ratio review allowed strong return/DD candidates such as W1-high/low pass `156` to be evaluated instead of rejected only because validation DD was slightly above `20%`.
- Decision or next step: Use ratio-based criteria for candidate discovery, while still checking OOS behavior and retaining a raw DD cap. For multi-symbol FTMO-style deployment, low trade count on one symbol should not automatically reject a manifold; it should be marked for cross-symbol validation.

### 2026-06-04 - W1 High/Low High-Impulse Genetic Follow-Up

- Goal: Test whether raising the impulse ATR multiplier improves drawdown and identifies ratio-qualified EURUSD candidates.
- Source files: `docs/results/EURUSD_W1HighLow_Genetic_HighImpulse_2000_2018_FWD_20260603.xml` and `.forward.xml`.
- Change or experiment: Expanded `g_Impulse_ATR_multiplier` to `1.3 -> 2.0` in `0.1` steps for a genetic optimizer run.
- Test setup: EURUSD, `H1` tester timeframe, W1 high/low period semantics, `2000 -> 2012` in-sample and `2012 -> 2018` optimizer-forward validation.
- Outcome: `179` paired rows, `61` positive-profit pairs, `5` pairs with profit/DD ratio `> 2.0` in both periods, `2` pairs accepted after DD cap and trade-count filters.
- Accepted candidates: pass `156` and pass `41`.
- Pass `156`: in-sample profit `138,615.22`, DD `17.67%`, ratio `7.84`, trades `1,373`; validation profit `63,728.11`, DD `22.05%`, ratio `2.89`, trades `651`; parameters `0.40, 168, 24, 1.7, 0.30, 2`.
- Pass `41`: in-sample profit `133,447.09`, DD `16.91%`, ratio `7.89`, trades `1,339`; validation profit `49,371.32`, DD `23.12%`, ratio `2.14`, trades `591`; parameters `0.40, 96, 6, 1.5, 0.35, 2`.
- Decision or next step: Created fixed `.set` and `.ini` files for passes `156` and `41` and ran IS, validation, and OOS backtests.

### 2026-06-04 - W1 High/Low Fixed IS/VAL/OOS Backtests

- Goal: Confirm whether W1 high/low passes `156` and `41` survive the full `2000 -> 2026` workflow.
- Source files: `docs/results/EURUSD_W1HighLow_Pass156_*_20260604.xml.htm` and `docs/results/EURUSD_W1HighLow_Pass41_*_20260604.xml.htm`.
- Test setup: Fixed backtests for `2000 -> 2012` in-sample, `2012 -> 2018` validation, and `2018 -> 2026` OOS. Optimization disabled.
- Outcome: Both candidates reproduced in-sample and validation, but both failed OOS.
- Pass `156`: IS profit `138,615.22`, DD `17.67%`, ratio `7.84`, trades `1,373`; VAL profit `63,728.11`, DD `22.05%`, ratio `2.89`, trades `651`; OOS profit `-27,855.73`, DD `60.57%`, ratio `-0.46`, trades `887`.
- Pass `41`: IS profit `133,447.09`, DD `16.91%`, ratio `7.89`, trades `1,339`; VAL profit `49,371.32`, DD `23.12%`, ratio `2.14`, trades `591`; OOS profit `-37,953.37`, DD `66.79%`, ratio `-0.57`, trades `837`.
- Decision or next step: W1 high/low candidates did not generalize into OOS. Shifted focus back to D1 high/low logic.

### 2026-06-04 - Code And Preset Changes For D1 High/Low Percentage-Risk Testing

- Goal: Prepare the EA for D1 high/low testing with percentage-based risk instead of fixed currency risk.
- Change or experiment: Added `g_Risk_Percentage = 1.0` input and wired active order placement to `Calculate_Lot_Size_V3(g_Risk_Percentage, entryPrice, stopLoss)`.
- Change or experiment: Replaced active `PERIOD_W1` period checks with `PERIOD_D1` in shared period and signal logic.
- Change or experiment: Updated `Profiles/Tester/ImpulseContinuation_EURUSD_Optimize.set` for high-impulse D1 genetic testing and fixed `g_Risk_Percentage` at `1.0` during optimization.
- Change or experiment: Expanded `g_pullback_ATR_multiplier` range to `0.1 -> 2.0` in `0.1` steps.
- Test setup: `Files/WeekHighLow/EURUSD.ini` configured for EURUSD genetic optimization with report name `EURUSD_D1HighLow_Genetic_HighImpulse_2000_2018_FWD_20260604.xml`.
- Outcome: Code inspection confirmed active project files no longer used `PERIOD_W1` in WeekHighLow logic and no longer used `Calculate_Lot_Size_V2(1000, ...)` in the active order path.
- Verification note: Compile verification was not run because `MetaEditor64.exe` was not available on PATH.

### 2026-06-04 - D1 High/Low High-Impulse Genetic Optimization

- Goal: Find EURUSD D1 high/low parameter manifolds that pass in-sample and validation under ratio-based criteria.
- Source files: `docs/results/EURUSD_D1HighLow_Genetic_HighImpulse_2000_2018_FWD_20260604.xml` and `.forward.xml`.
- Test setup: EURUSD, `H1` tester timeframe, D1 high/low period logic, `2000 -> 2012` in-sample and `2012 -> 2018` optimizer-forward validation.
- Outcome: `516` paired rows, `238` positive-profit pairs, `13` pairs with ratio `> 2.0` in both periods, `12` pairs after DD cap, and `4` accepted after single-symbol trade-count filters.
- Accepted candidates: passes `265`, `160`, `227`, and `370`.
- Pass `265`: IS profit `71,658.06`, DD `25.45%`, ratio `2.82`, trades `268`; VAL profit `50,926.31`, DD `13.26%`, ratio `3.84`, trades `143`; parameters `0.40, 96, 12, 1.4, 1.0, 4`.
- Pass `160`: IS profit `73,551.23`, DD `21.50%`, ratio `3.42`, trades `672`; VAL profit `52,592.27`, DD `15.60%`, ratio `3.37`, trades `316`; parameters `0.40, 168, 24, 1.7, 0.8, 3`.
- Pass `227`: IS profit `151,715.88`, DD `29.60%`, ratio `5.12`, trades `1,474`; VAL profit `74,606.59`, DD `29.48%`, ratio `2.53`, trades `685`; parameters `0.40, 144, 18, 1.5, 0.4, 2`.
- Pass `370`: IS profit `106,419.85`, DD `29.18%`, ratio `3.65`, trades `1,404`; VAL profit `62,814.60`, DD `24.22%`, ratio `2.59`, trades `661`; parameters `0.40, 120, 24, 1.7, 0.2, 2`.
- Decision or next step: Created fixed `.set` and `.ini` files for IS, validation, and OOS backtests for all four accepted D1 candidates.

### 2026-06-04 - D1 High/Low Fixed IS/VAL/OOS Backtests

- Goal: Confirm whether the four accepted D1 high/low candidates survive OOS `2018 -> 2026`.
- Source files: `docs/results/EURUSD_D1HighLow_Pass265_*_20260604.xml.htm`, `Pass160`, `Pass227`, and `Pass370` report files.
- Test setup: Fixed backtests for `2000 -> 2012` in-sample, `2012 -> 2018` validation, and `2018 -> 2026` OOS. Optimization disabled.
- Outcome: All four candidates passed IS and validation, but none passed OOS.
- Pass `265`: OOS profit `-31,219.23`, DD `44.82%`, ratio `-0.70`, trades `201`.
- Pass `160`: OOS profit `19,052.29`, DD `33.50%`, ratio `0.57`, trades `484`, profit factor `1.05`. This was the best OOS result but still failed the ratio and DD criteria.
- Pass `227`: OOS profit `-26,360.15`, DD `59.06%`, ratio `-0.45`, trades `963`.
- Pass `370`: OOS profit `-24,128.57`, DD `57.12%`, ratio `-0.42`, trades `903`.
- Decision or next step: The D1 high/low accepted candidates did not generalize to EURUSD OOS. Investigated low-trade candidates that were previously filtered out, since multi-symbol deployment may make single-symbol trade count less important.

### 2026-06-04 - D1 Low-Trade Candidate OOS Follow-Up

- Goal: Evaluate D1 candidates rejected only by single-symbol trade-count thresholds, because the intended FTMO-style deployment may aggregate trades across multiple symbols.
- Candidates tested: passes `71`, `20`, `262`, `251`, `437`, `383`, `68`, and `402`.
- Source files: `docs/results/EURUSD_D1HighLow_Pass*_LowTrade_OOS_2018_2026_20260604.xml.htm`.
- Test setup: OOS-only fixed backtests for `2018 -> 2026`, optimization disabled.
- Outcome: `0` of `8` passed OOS ratio criteria. `3` of `8` had positive OOS profit, `0` had ratio `> 2.0`, and `5` had DD `<= 30%`.
- Best OOS low-trade result: pass `251`, profit `21,004.39`, DD `15.63%`, ratio `1.34`, trades `73`, profit factor `1.37`, Sharpe `8.98`.
- Other positive OOS rows: pass `68`, profit `9,179.68`, DD `15.23%`, ratio `0.60`, trades `119`; pass `20`, profit `670.67`, DD `7.32%`, ratio `0.09`, trades `9`.
- Decision or next step: Relaxing single-symbol trade-count filtering did not reveal a strong EURUSD OOS candidate. Pass `251` is the only low-trade candidate worth noting, but it remains below the OOS ratio threshold and needs cross-symbol validation before it can be considered useful.

### 2026-06-04 - W1 High-Impulse Expanded Basket Genetic Optimization

- Goal: Test whether W1 high/low high-impulse genetic optimization produces useful manifolds across a diverse starter basket before attempting full multi-symbol deployment.
- Intended basket: `EURUSD`, `GBPUSD`, `USDJPY`, `XAUUSD`, `XAGUSD`, `US30`, `US500`, `US100`, and `UK100`.
- Completed symbols: `EURUSD`, `GBPUSD`, `USDJPY`, `XAUUSD`, `US30`, and `US500`.
- Skipped or abandoned symbols: `US100`, `XAGUSD`, and `UK100`.
- Skip reason: `US100` broker history starts at `2014.09.15`, which can cause MT5 to hang indefinitely for `2000`-based tests. `XAGUSD` and `UK100` also showed practical MT5 optimizer hang behavior and were abandoned for this batch.
- Change or experiment: Created shared preset `Profiles/Tester/ImpulseContinuation_W1HighLow_Genetic_HighImpulse.set` and configured symbol-specific genetic optimizer `.ini` files.
- Test setup: W1 high/low logic, `H1` tester timeframe, `2000 -> 2018` total test window, MT5 optimizer forward validation enabled, `g_Risk_Percentage = 1.0` fixed.
- Review criteria: profit `> 0` in both in-sample and validation, profit/DD ratio `> 2.0` in both, DD `<= 30%` in both, in-sample trades `>= 200`, validation trades `>= 100`.
- Outcome by symbol: `EURUSD` had `4` accepted candidates, `GBPUSD` had `2`, `USDJPY` had `9`, `XAUUSD` had many accepted candidates, while `US30` and `US500` had `0` accepted candidates.
- Detailed counts: `EURUSD` had `553` paired rows, `255` positive-profit pairs, `14` ratio-qualified pairs, `12` after DD cap, and `4` accepted. `GBPUSD` had `557` paired rows, `178` positive-profit pairs, `6` ratio-qualified pairs, `6` after DD cap, and `2` accepted. `USDJPY` had `556` paired rows, `265` positive-profit pairs, `20` ratio-qualified pairs, `17` after DD cap, and `9` accepted. `XAUUSD` had `499` paired rows, `410` positive-profit pairs, `209` ratio-qualified pairs, `173` after DD cap, and a large number of accepted candidates. `US30` had `524` paired rows and `0` ratio-qualified pairs. `US500` had `477` paired rows and `0` ratio-qualified pairs.
- Best EURUSD accepted candidate reviewed: pass `758`, IS profit `54,169.72`, IS DD `10.12%`, IS ratio `5.35`, IS trades `216`; validation profit `39,821.47`, validation DD `12.75%`, validation ratio `3.12`, validation trades `127`; parameters `0.40, 96, 6, 1.6, 0.8, 3`.
- Best GBPUSD accepted candidate reviewed: pass `285`, IS profit `56,409.35`, IS DD `19.19%`, IS ratio `2.94`, IS trades `332`; validation profit `39,418.61`, validation DD `13.97%`, validation ratio `2.82`, validation trades `140`; parameters `0.25, 144, 18, 1.6, 1.0, 5`.
- Best USDJPY accepted candidate reviewed: pass `426`, IS profit `118,530.38`, IS DD `20.75%`, IS ratio `5.71`, IS trades `470`; validation profit `104,197.50`, validation DD `18.40%`, validation ratio `5.66`, validation trades `220`; parameters `0.50, 120, 12, 1.3, 0.9, 4`.
- Best XAUUSD accepted candidate reviewed: pass `234`, IS profit `152,442.13`, IS DD `14.34%`, IS ratio `10.63`, IS trades `353`; validation profit `122,257.06`, validation DD `12.43%`, validation ratio `9.83`, validation trades `328`; parameters `0.40, 168, 24, 1.8, 0.7, 4`.
- Cross-symbol finding: No exact same parameter set appeared as an accepted candidate across multiple completed symbols.
- Common region observed among accepted candidates: `g_ATR_Cluster_multiplier` mostly `0.35 -> 0.50`, `g_impulse_lookback_hours` mostly `96 -> 168`, `g_pullback_lookforward_hours` mostly `12 -> 24`, `g_Impulse_ATR_multiplier` mostly `1.3 -> 1.7`, `g_pullback_ATR_multiplier` mostly `0.6 -> 1.0`, and `g_TakeProfitMultiplier` mostly `3` or `5`.
- Decision or next step: W1 high/low works best so far on `XAUUSD` and `USDJPY`, with usable results on `EURUSD` and `GBPUSD`. Indices did not produce accepted candidates in this batch. Next useful step is to search for a narrowed shared parameter region across `EURUSD`, `GBPUSD`, `USDJPY`, and `XAUUSD`, then run fixed OOS tests.

### 2026-06-05 - EURUSD W1 Clustered High-Impulse Genetic Review

- Goal: Review the latest EURUSD W1 clustered impulse-continuation optimizer and forward-test results to identify candidates for fixed OOS testing.
- Source files: `docs/results/EURUSD_W1HighLow_Clustered_Genetic_HighImpulse_2000_2018_FWD_20260604.xml` and `.forward.xml`.
- Test setup: EURUSD, `H1` tester timeframe, W1 high/low clustered signal logic, `2000 -> 2012` in-sample optimization and `2012 -> 2018` optimizer-forward validation.
- Outcome: `761` optimizer rows and `761` forward rows paired by `Pass`; `177` pairs had positive in-sample and forward profit, `20` pairs had profit/DD ratio `> 2.0` in both periods, `19` remained after the `<= 30%` DD cap, `0` met the strict single-symbol trade-count filter, and `11` met the loose trade-count filter.
- Best balanced candidates after ratio and DD filters: passes `686`, `689`, `680`, `748`, and `737`.
- Pass `686`: IS profit `40,854.92`, DD `6.79%`, ratio `6.02`, trades `108`; validation profit `11,646.78`, DD `3.18%`, ratio `3.67`, trades `38`; parameters `3, 0.20, 48, 24, 0.6, 0.4, 1`.
- Pass `689`: IS profit `102,309.18`, DD `12.28%`, ratio `8.33`, trades `108`; validation profit `30,880.97`, DD `8.92%`, ratio `3.46`, trades `38`; parameters `3, 0.20, 48, 24, 0.6, 0.4, 3`.
- Pass `680`: IS profit `40,307.37`, DD `13.62%`, ratio `2.96`, trades `132`; validation profit `49,834.64`, DD `8.71%`, ratio `5.72`, trades `57`; parameters `4, 0.30, 144, 24, 0.6, 0.4, 2`.
- Pass `748`: IS profit `71,112.16`, DD `10.26%`, ratio `6.93`, trades `155`; validation profit `23,393.52`, DD `8.54%`, ratio `2.74`, trades `63`; parameters `3, 0.20, 168, 24, 0.6, 0.4, 2`.
- Pass `737`: IS profit `58,261.28`, DD `4.52%`, ratio `12.90`, trades `155`; validation profit `14,756.80`, DD `5.65%`, ratio `2.61`, trades `63`; parameters `3, 0.20, 168, 24, 0.6, 0.4, 1`.
- Parameter order: `g_MinClusterSize`, `g_ATR_Cluster_multiplier`, `g_impulse_lookback_hours`, `g_pullback_lookforward_hours`, `g_Impulse_ATR_multiplier`, `g_MinPullback_ATR_multiplier`, `g_TakeProfitMultiplier`.
- Decision or next step: The clustered W1 EURUSD run is promising but not accepted because trade count is low on one symbol and OOS has not been tested. Run fixed OOS `2018 -> 2026` tests for passes `686`, `689`, `680`, `748`, and `737`; if any survive, test the same manifold across `GBPUSD`, `USDJPY`, and `XAUUSD`.

### 2026-06-06 - EURUSD D1 Clustered High-Impulse Genetic Review

- Goal: Repeat the clustered impulse-continuation genetic optimizer and forward-test workflow using D1 high/low period logic instead of W1.
- Source note: Result files under `docs/results` are ephemeral and should not be treated as durable references; this entry records the durable metrics and decisions instead of relying on filenames.
- Change or experiment: Added global high/low period input `g_HighLowPeriod`, switched the active project default to `PERIOD_D1`, and ran EURUSD clustered genetic optimization with optimizer-forward validation.
- Test setup: EURUSD, `H1` tester timeframe, D1 high/low clustered signal logic, `2000 -> 2012` in-sample optimization and `2012 -> 2018` optimizer-forward validation.
- Outcome: `1,018` optimizer rows and `1,018` forward rows paired by `Pass`; `457` pairs had positive in-sample and forward profit, `59` pairs had profit/DD ratio `> 2.0` in both periods, `47` remained after the `<= 30%` DD cap, `28` met the strict single-symbol trade-count filter, and `44` met the loose trade-count filter.
- Best strict-filter candidates reviewed: passes `426`, `523`, `696`, `631`, and `1011`.
- Pass `426`: IS profit `307,835.44`, DD `19.76%`, ratio `15.58`, trades `837`; validation profit `134,818.37`, DD `23.39%`, ratio `5.76`, trades `348`; parameters `4, 0.40, 72, 18, 1.4, 0.4, 2`.
- Pass `523`: IS profit `133,202.12`, DD `21.58%`, ratio `6.17`, trades `1,412`; validation profit `79,333.29`, DD `15.98%`, ratio `4.97`, trades `688`; parameters `3, 0.50, 48, 18, 0.8, 0.6, 1`.
- Pass `696`: IS profit `168,894.38`, DD `19.71%`, ratio `8.57`, trades `1,006`; validation profit `75,829.28`, DD `16.66%`, ratio `4.55`, trades `469`; parameters `4, 0.50, 72, 12, 0.8, 0.6, 2`.
- Pass `631`: IS profit `129,156.33`, DD `28.95%`, ratio `4.46`, trades `1,406`; validation profit `119,530.95`, DD `23.16%`, ratio `5.16`, trades `688`; parameters `3, 0.50, 48, 18, 0.8, 0.6, 2`.
- Pass `1011`: IS profit `84,888.31`, DD `12.97%`, ratio `6.55`, trades `841`; validation profit `63,804.34`, DD `16.57%`, ratio `3.85`, trades `413`; parameters `3, 0.50, 48, 6, 0.8, 0.6, 1`.
- Decision or next step: D1 clustered optimization was materially stronger than the W1 clustered run. Set up fixed OOS `2018 -> 2026` tests for all `44` loose-filter candidates rather than only the top strict-filter candidates.

### 2026-06-06 - EURUSD D1 Clustered 44-Candidate OOS Batch

- Goal: Test all `44` loose-filter EURUSD D1 clustered candidates on the `2018 -> 2026` out-of-sample period.
- Source note: Result files under `docs/results` are ephemeral and should not be treated as durable references; this entry records the durable metrics and decisions instead of relying on filenames.
- Test setup: EURUSD, `H1` tester timeframe, D1 high/low clustered signal logic, fixed single-test OOS runs, optimization disabled, `g_Risk_Percentage = 1.0`, `2018.01.01 -> 2026.05.31`.
- OOS acceptance criteria used: profit `> 0`, profit/DD ratio `> 2.0`, and equity DD `<= 30%`.
- Outcome: `44` reports parsed, `29` candidates had positive OOS profit, `4` candidates had OOS profit/DD ratio `> 2.0`, `19` candidates had OOS equity DD `<= 30%`, and `3` candidates met all OOS acceptance criteria.
- Accepted OOS candidate pass `816`: profit `42,649.03`, equity DD `12.93%`, ratio `3.30`, trades `78`, profit factor `1.59`, recovery `2.42`, Sharpe `7.68`; parameters `4, 0.20, 144, 24, 1.8, 1.0, 5`.
- Accepted OOS candidate pass `8`: profit `20,822.93`, equity DD `8.91%`, ratio `2.34`, trades `44`, profit factor `1.52`, recovery `1.87`, Sharpe `29.21`; parameters `3, 0.10, 96, 12, 0.8, 1.0, 4`.
- Accepted OOS candidate pass `707`: profit `55,777.64`, equity DD `26.85%`, ratio `2.08`, trades `790`, profit factor `1.13`, recovery `1.46`, Sharpe `2.49`; parameters `2, 0.50, 168, 18, 0.8, 0.8, 1`.
- Notable near miss pass `537`: profit `149,627.22`, equity DD `33.70%`, ratio `4.44`, trades `646`, profit factor `1.17`; parameters `3, 0.20, 96, 6, 0.6, 0.4, 5`. This had the best OOS profit/DD ratio and profit, but exceeded the `30%` DD cap.
- Parameter order: `g_MinClusterSize`, `g_ATR_Cluster_multiplier`, `g_impulse_lookback_hours`, `g_pullback_lookforward_hours`, `g_Impulse_ATR_multiplier`, `g_MinPullback_ATR_multiplier`, `g_TakeProfitMultiplier`.
- Decision or next step: Passes `816`, `8`, and `707` survived EURUSD OOS. Pass `707` is the most useful robustness candidate because it has much higher trade count; passes `816` and `8` are cleaner on DD/ratio but lower frequency. Next useful step is cross-symbol fixed testing of these three candidates, with pass `537` optionally tracked as a high-return/high-DD near miss.

### 2026-06-06 - Cross-Symbol Fixed Validation For EURUSD D1 Clustered Survivors

- Goal: Validate whether the EURUSD D1 clustered OOS survivors generalize across a compact multi-market basket before considering them robust manifolds.
- Source note: Result files under `docs/results` are ephemeral and should not be treated as durable references; this entry records the durable metrics and decisions instead of relying on filenames.
- Candidates tested: passes `707`, `816`, and `8`.
- Symbol basket: `GBPUSD`, `USDJPY`, `EURJPY`, `XAUUSD`, `US500`, and `US30`.
- Test setup: Fixed single-test runs with optimization disabled, `H1` tester timeframe, D1 high/low clustered signal logic, `g_Risk_Percentage = 1.0`.
- Test segmentation: in-sample `2000.01.01 -> 2012.01.01`, validation `2012.01.01 -> 2018.01.01`, and OOS `2018.01.01 -> 2026.05.31`.
- Coverage: `54` expected reports and `54` parsed reports; no missing pass/symbol/segment combinations.
- Acceptance criteria used per row: profit `> 0`, profit/DD ratio `> 2.0`, and equity DD `<= 30%`.
- Overall outcome: `33` of `54` tests were profitable, `13` had ratio `> 2.0`, `41` had DD `<= 30%`, and `13` met all row-level acceptance criteria.
- Pass `816` aggregate: total profit `285,093.42`, OOS profit `185,893.56`, positive rows `13 / 18`, accepted rows `6 / 18`, OOS-positive symbols `5 / 6`, OOS-accepted symbols `4 / 6`, max DD `34.67%`, total trades `995`.
- Pass `707` aggregate: total profit `105,342.89`, OOS profit `66,764.44`, positive rows `10 / 18`, accepted rows `4 / 18`, OOS-positive symbols `4 / 6`, OOS-accepted symbols `1 / 6`, max DD `61.99%`, total trades `11,182`.
- Pass `8` aggregate: total profit `-41,489.78`, OOS profit `15,677.60`, positive rows `10 / 18`, accepted rows `3 / 18`, OOS-positive symbols `4 / 6`, OOS-accepted symbols `1 / 6`, max DD `39.40%`, total trades `699`.
- Pass `816` symbol notes: strongest broad candidate; OOS was positive on `EURJPY`, `GBPUSD`, `US500`, `USDJPY`, and `XAUUSD`, with `US30` failing OOS. Strongest OOS contributors were `US500`, `XAUUSD`, `EURJPY`, and `USDJPY`.
- Pass `707` symbol notes: very strong on `XAUUSD` across all three segments, but weak as a broad manifold. `XAUUSD` produced IS profit `92,302.20`, validation profit `63,475.15`, OOS profit `107,779.56`, max DD `15.29%`, and all three segments accepted. Other symbols were mixed or poor, especially `EURJPY`, `GBPUSD`, and `US500` across earlier segments.
- Pass `8` symbol notes: too weak overall and negative in aggregate, though it had isolated accepted rows on `XAUUSD` IS, `USDJPY` validation, and `GBPUSD` OOS.
- Decision or next step: Promote pass `816` as the best broad cross-symbol candidate from this batch, but not yet as a clean deployment candidate because aggregate IS was slightly negative, max DD exceeded `30%`, and `US30` failed OOS. Treat pass `707` as an `XAUUSD` specialist candidate rather than a broad manifold. Deprioritize pass `8`. Next useful step is broader fixed-symbol testing and/or aggregate portfolio review for pass `816`, including EURUSD plus the cross-symbol basket.

### 2026-06-06 - ATR Cluster And Stop-Loss Multiplier Split

- Goal: Separate the multiplier used for high/low cluster sizing from the multiplier used for stop-loss and entry distance sizing.
- Change or experiment: Added `g_ATR_StopLoss_multiplier` to `Experts/WeekHighLow/WeekHighLowEA.mq5`.
- Change or experiment: Kept `g_ATR_Cluster_multiplier` on the clustered signal detection path, and switched active order-distance calculation to `lastWeek.weeklyATR * g_ATR_StopLoss_multiplier`.
- Change or experiment: Updated pass `816`, `707`, and `8` fixed presets so `g_ATR_StopLoss_multiplier` initially equals each preset's existing `g_ATR_Cluster_multiplier`, preserving baseline behavior until deliberately changed.
- Expected effect on next test: None, as long as `g_ATR_StopLoss_multiplier == g_ATR_Cluster_multiplier`. The split only creates the ability to test different cluster and stop-loss multipliers later.
- Verification: Compiled `WeekHighLowEA.mq5` with MetaEditor. Result was `0` errors and `1` existing warning in `TradeLogger.mqh` about possible `ulong` to `int` conversion.
- Operational decision: Future assistant sessions should not launch MT5 optimizer or backtest runs unless the user explicitly asks for the specific run. The user will run tests because MT5 must be available and test duration needs to be planned.

### 2026-06-06 - Guarded CSV Trade Logging Re-Enabled

- Goal: Re-enable the existing CSV trade logger without requiring future comment/uncomment code changes.
- Change or experiment: Added `g_EnableTradeCsvLogging` input to `Experts/WeekHighLow/WeekHighLowEA.mq5`, defaulting to `true`.
- Change or experiment: Guarded `DeleteTradeCsv()` and `OpenTradeCsv()` in `OnInit()`, `CloseTradeCsv()` in `OnDeinit()`, and `OnTradeTransactionHelper()` forwarding in `OnTradeTransaction()` behind `g_EnableTradeCsvLogging`.
- Expected behavior: When `g_EnableTradeCsvLogging` is `true`, trade events are written to `all_symbols_oanda_trades.csv` through `TradeLogger.mqh`. When `false`, CSV creation/writing is disabled from EA inputs without editing source comments.
- Verification: Compiled `WeekHighLowEA.mq5` with MetaEditor. Result was `0` errors and `1` existing warning in `TradeLogger.mqh` about possible `ulong` to `int` conversion.

### 2026-06-07 - Closed-PnL FTMO Survivability Analysis

- Goal: Evaluate whether the current pass `816` multi-symbol result can survive FTMO-style challenge rules using the generated trade CSV.
- Source file: `docs/results/all_symbols_oanda_trades.csv`.
- Change or experiment: Added reusable utility `docs/utils/Analyze-FtmoClosedPnlSurvivability.ps1`.
- Method: Run a rolling challenge simulation from each closed trade event, walking forward until profit target, global loss, daily loss, or end of data. The first version used realized closed P/L only, with raw CSV dollar P/L.
- Important limitation: The CSV does not contain intratrade floating equity, so this is a closed-PnL proxy. True FTMO daily loss, global loss, and profit-target events may occur before trades close.
- Raw closed-PnL result with inferred `7` symbols and `700,000` starting balance: `1,209` starts, `1,112` passes, `0` fails, `97` unresolved, median pass duration `1,160.38` days, median closed trades to pass `158`.
- Diagnostic raw closed-PnL result with `100,000` starting balance: failures appeared immediately, with `778` passes, `427` fails, and `8` unresolved. This confirmed that the `0`-failure result at `700,000` came from the large capital assumption, not from absence of losing streaks.
- Refined method: Added `PnlMode NormalizedRisk`, which estimates each closed trade's R-multiple from the original `1%` single-symbol risk and replays it against one communal FTMO account using a fixed percentage of current communal balance per trade.
- Normalized communal-risk result at `100,000` starting balance and `0.25%` risk per trade: `1,052` passes, `80` fails, `77` unresolved, resolved pass rate `92.93%`, median pass duration `722.54` days, median closed trades to pass `91`.
- Normalized communal-risk result at `100,000` starting balance and `0.5%` risk per trade: `1,009` passes, `188` fails, `12` unresolved, resolved pass rate `84.29%`, median pass duration `275.88` days, median closed trades to pass `39`.
- Normalized communal-risk result at `100,000` starting balance and `1.0%` risk per trade: `788` passes, `412` fails, `9` unresolved, resolved pass rate `65.67%`, median pass duration `82.76` days, median closed trades to pass `12`.
- Trade frequency context: The CSV contained `1,209` completed trades across `7` symbols from `2000-01-31` to `2026-05-07`, averaging `0.88` completed trades per week overall and `0.13` per symbol per week.
- Decision or next step: The `1.0%` communal risk setting reaches the target much faster but fails too often. The `0.5%` setting is a more balanced candidate, while `0.25%` appears safer but likely too slow for a practical FTMO challenge. Exact FTMO validation needs equity logging, not only closed-trade CSV analysis.

### 2026-06-07 - Trade CSV Schema Improvements

- Goal: Make future trade CSV analysis easier, especially matching entries to exits and replaying results at different risk percentages.
- Change or experiment: Added `trade_id` to the CSV logger output, using MT5 `DEAL_POSITION_ID`. The existing `ticket` column remains the deal ticket for compatibility.
- Change or experiment: Added `risk_percentage` to the CSV logger output, using the EA input `g_Risk_Percentage` active at the time of the deal event.
- Change or experiment: Fixed the logger's `FileTell()` temporary variable type from `int` to `ulong`.
- Expected behavior: Future CSV files should be easier to group by trade/position and should contain enough information to normalize trade outcomes by the original percentage risk setting.
- Verification: Compiled `WeekHighLowEA.mq5` with MetaEditor. Result was `0` errors and `0` warnings.

### 2026-06-07 - EURUSD D1 Stop-Loss Split Genetic Test Setup

- Goal: Run an overnight EURUSD D1 genetic optimizer-forward test to determine whether separating stop-loss sizing from cluster sizing improves results.
- Config file: `Files/WeekHighLow/EURUSD_D1_StopLossSplit.ini`.
- Preset file: `Profiles/Tester/ImpulseContinuation_D1HighLow_Genetic_StopLossSplit.set`.
- Test setup: EURUSD, `H1` tester timeframe, `2000.01.01 -> 2018.01.01`, genetic optimization enabled, MT5 forward mode enabled.
- Report target: `reports/EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607.xml`.
- Key change: `g_ATR_Cluster_multiplier` remains optimized over `0.1 -> 0.5` in `0.1` steps, while `g_ATR_StopLoss_multiplier` is optimized independently over `0.05 -> 0.5` in `0.05` steps.
- CSV logging: Disabled for this genetic run with `g_EnableTradeCsvLogging=false`.
- Autorun setup: `Files/WeekHighLow/autorun.ps1` now runs only `EURUSD_D1_StopLossSplit.ini` and uses a `1440` minute timeout.
- Verification: Compiled `WeekHighLowEA.mq5` with MetaEditor before setup handoff. Result was `0` errors and `0` warnings.
- Decision or next step: User will run the overnight test manually and provide results in the morning. Assistant should not launch the test.

### 2026-06-08 - EURUSD D1 Stop-Loss Split Genetic Three-Run Review

- Goal: Review three independent EURUSD D1 stop-loss split genetic optimizer-forward runs to determine whether they converge on a useful parameter region.
- Source files: `docs/results/StopLossSplit/EURUSD_D1HighLow_Clustered_Genetic_StopLossSplit_2000_2018_FWD_20260607*.xml` and matching `.forward.xml` files.
- Run notes: RUN1 was the original overnight run. RUN2 was run without clearing tester cache. RUN3 was run after clearing tester cache.
- Parser update: Added `StopLossMult` output to `docs/utils/Analyze-Mt5OptimizerForward.ps1` so `g_ATR_StopLoss_multiplier` is visible in candidate reviews.
- Exported candidate summaries: `docs/results/StopLossSplit/RUN1_loose_candidates.csv`, `RUN2_loose_candidates.csv`, and `RUN3_loose_candidates.csv`.
- RUN1 counts: `3,209` optimizer rows, `3,200` forward rows, `3,200` paired rows, `1,665` positive-profit pairs, `263` ratio-qualified pairs, `219` after DD cap, `120` strict candidates, and `192` loose candidates.
- RUN2 counts: `6,205` optimizer rows, `2,986` forward rows, `2,986` paired rows, `1,617` positive-profit pairs, `378` ratio-qualified pairs, `332` after DD cap, `129` strict candidates, and `285` loose candidates. RUN2 is less clean for convergence review because cache was not cleared and optimizer/forward row counts were mismatched.
- RUN3 counts: `2,968` optimizer rows, `2,968` forward rows, `2,968` paired rows, `1,661` positive-profit pairs, `264` ratio-qualified pairs, `212` after DD cap, `125` strict candidates, and `194` loose candidates.
- RUN1 top candidate: pass `1782`, min ratio `6.227`, IS profit `171,071.66`, IS DD `22.22%`, forward profit `104,161.05`, forward DD `16.73%`, parameters `g_MinClusterSize=3`, `g_ATR_Cluster_multiplier=0.2`, `g_ATR_StopLoss_multiplier=0.25`, `g_impulse_lookback_hours=48`, `g_pullback_lookforward_hours=24`, `g_Impulse_ATR_multiplier=0.8`, `g_MinPullback_ATR_multiplier=1.0`, `g_TakeProfitMultiplier=5`.
- RUN2 top candidate: pass `4939`, min ratio `6.211`, IS profit `146,077.11`, IS DD `14.99%`, forward profit `73,902.26`, forward DD `11.90%`, parameters `g_MinClusterSize=3`, `g_ATR_Cluster_multiplier=0.2`, `g_ATR_StopLoss_multiplier=0.35`, `g_impulse_lookback_hours=48`, `g_pullback_lookforward_hours=18`, `g_Impulse_ATR_multiplier=1.0`, `g_MinPullback_ATR_multiplier=0.6`, `g_TakeProfitMultiplier=2`.
- RUN3 top candidate: pass `696`, min ratio `7.932`, IS profit `202,237.81`, IS DD `14.57%`, forward profit `72,458.11`, forward DD `9.13%`, parameters `g_MinClusterSize=4`, `g_ATR_Cluster_multiplier=0.2`, `g_ATR_StopLoss_multiplier=0.4`, `g_impulse_lookback_hours=168`, `g_pullback_lookforward_hours=18`, `g_Impulse_ATR_multiplier=1.6`, `g_MinPullback_ATR_multiplier=0.4`, `g_TakeProfitMultiplier=3`.
- Convergence finding: The runs did not converge to one exact parameter set, but they did converge on a broad region. All three top candidates used `g_ATR_Cluster_multiplier=0.2`, while the best stop-loss multipliers were wider than cluster size: `0.25`, `0.35`, and `0.4`.
- Additional finding: Top-50 candidates across runs favored `g_ATR_StopLoss_multiplier` values mostly in the `0.25 -> 0.5` region. Very tight stop losses such as `0.05` and `0.10` did not appear in the top regions.
- Decision or next step: The split appears meaningful. Do not treat optimizer-forward results as sufficient; set up fixed OOS tests for representative top candidates from RUN1, RUN2, and RUN3, then evaluate OOS and later cross-symbol behavior.

### 2026-06-07 - Phase-1 Multi-Symbol Basket Decision

- Goal: Lock the initial multi-symbol validation basket using non-performance criteria so later basket changes do not become implicit curve fitting.
- Decision: Use `EURUSD`, `GBPUSD`, `USDJPY`, `EURJPY`, `XAUUSD`, `US500`, `US30`, and `US100` as the phase-1 fixed-manifold validation basket.
- Decision: Do not add `USOIL` or `UKOIL` for phase-1. Oil is useful later but not important enough to change broker/workflow before the strategy proves basic cross-market robustness.
- Special rule: `US100` is important enough to include, but OANDA history starts later than the standard `2000 -> 2026` workflow. Do not use `US100` for optimization or require the `2000 -> 2012` in-sample segment.
- Test setup for `US100`: Skip in-sample, use validation from available history around `2014.09.15 -> 2018.01.01`, and use normal OOS testing from `2018.01.01 -> 2026.05.31`.
- Decision or next step: Treat `US100` as a fixed-manifold validation symbol only. It can strengthen or weaken confidence in a manifold, but it must not be used to discover or tune parameters.

### 2026-06-08 - Stop-Loss Split Strict Candidate OOS Checkpoint

- Goal: Begin OOS review for all strict candidates from the three EURUSD D1 stop-loss split genetic optimizer-forward runs.
- Source directory: `docs/results/results_for_run1_run2_run3`.
- Test setup: EURUSD, `H1` tester timeframe, D1 high/low clustered signal logic, fixed single-test OOS runs, optimization disabled, `2018.01.01 -> 2026.05.31`.
- Candidate source: strict optimizer-forward candidates from RUN1, RUN2, and RUN3, using profit `> 0`, profit/DD ratio `> 2.0`, equity DD `<= 30%`, in-sample trades `>= 200`, and forward trades `>= 100`.
- OOS acceptance criteria used so far: profit `> 0`, profit/DD ratio `> 2.0`, and equity DD `<= 30%`.
- OOS reports parsed: `374`.
- OOS accepted candidates: `73` total, with `39` from RUN1, `24` from RUN2, and `10` from RUN3.
- Failed report cleanup: deleted `301` failed report sets from `docs/results/results_for_run1_run2_run3`, removing `1,505` files including `.xml.htm` reports and sidecar chart images.
- Audit files created: `docs/results/results_for_run1_run2_run3/accepted_oos_candidates.csv` and `docs/results/results_for_run1_run2_run3/deleted_failed_oos_candidates.csv`.
- Best OOS candidate by current ratio ranking: RUN3 pass `1483`, profit `145,503.40`, equity DD `14.83%`, ratio `9.811`, trades `461`, parameters `g_MinClusterSize=2`, `g_ATR_Cluster_multiplier=0.1`, `g_ATR_StopLoss_multiplier=0.25`, `g_impulse_lookback_hours=120`, `g_pullback_lookforward_hours=6`, `g_Impulse_ATR_multiplier=0.4`, `g_MinPullback_ATR_multiplier=0.6`, `g_TakeProfitMultiplier=3`.
- Analysis status: Not complete. The next session should continue reviewing the `73` accepted OOS candidates, including convergence/duplication, trade-count quality, secondary MT5 metrics such as recovery factor, profit factor, Sharpe, and whether candidates should be promoted to fixed multi-symbol validation.
- Metric decision checkpoint: Keep explicit profit/DD as the primary acceptance filter for now because it directly measures return relative to equity drawdown. Use Sharpe, recovery factor, profit factor, and other MT5 report fields as secondary ranking or warning metrics, not replacements for profit/DD.

### 2026-06-09 - Expanded Basket Reliability And Start-Date Probe

- Goal: Confirm whether previously problematic or newly available symbols can be included in the fixed-manifold validation basket, and determine effective start coverage when requesting `2000.01.01 -> 2012.01.01` tests.
- Source directories: `docs/results/test_on_prior_failing_symbols` and `docs/results/start_date_probe`.
- Test setup: Fixed single-test backtests using `RUN2` pass `5456`, `H1` tester timeframe, D1 high/low clustered stop-loss split logic, optimization disabled, and CSV logging disabled.
- Reliability outcome: `XAGUSD`, `US100`, `USOIL`, `UKOIL`, and `UK100` all completed fixed test runs and produced parseable MT5 `.xml.htm` reports.
- Expanded phase-1 basket decision: use `EURUSD`, `GBPUSD`, `USDJPY`, `EURJPY`, `XAUUSD`, `XAGUSD`, `US500`, `US30`, `US100`, `UK100`, `USOIL`, and `UKOIL` for fixed-manifold validation and later FTMO-style portfolio analysis.
- Start-date probe method: Requested `2000.01.01 -> 2012.01.01` for all `12` basket symbols, then parsed first EA trade/order timestamps with `docs/utils/Get-Mt5ReportFirstTradeDate.ps1`.
- Full standard IS coverage by effective first trade/order: `USDJPY` first event `2000.01.03 15:00:00`, `GBPUSD` `2000.01.14 16:00:00`, `EURUSD` `2000.01.19 11:00:00`, and `EURJPY` `2000.01.25 07:00:00`.
- Partial-history IS symbols: `US30` first event `2005.01.27 22:00:00`, `USOIL` `2005.01.27 21:00:00`, `US500` `2005.01.31 02:04:30`, `UKOIL` `2005.04.19 20:00:00`, `XAUUSD` `2006.04.13 17:00:00`, `XAGUSD` `2006.04.28 17:00:00`, and `UK100` `2008.06.03 21:00:00`.
- `US100` result: The `2000 -> 2012` probe produced `0` trade/order events because the test ended before usable history. A follow-up `2000.01.01 -> 2020.01.01` probe produced first trade/order activity at `2014.10.07 15:00:00` with `1,364` trade/order events. Keep `US100` as validation/OOS-only from available history around `2014.09.15` onward.
- Important limitation: Probe dates are first EA trade/order timestamps for one fixed manifold, not broker first-bar timestamps. They should be used as practical strategy workflow availability markers, not as exact historical data start dates.
- Decision or next step: Treat non-FX symbols except `US100` as partial-history IS symbols rather than full `2000 -> 2012` symbols. Do not compare their IS results directly against full-history FX IS results without accounting for shorter coverage.

### 2026-06-09 - Pre-CSV Expanded-Basket Elimination Filters

- Goal: Freeze broad screening filters before running or analyzing the expanded fixed-manifold basket, so the basket is not used as an unrestricted leaderboard before FTMO trade CSV analysis.
- Scope: Apply these filters after fixed MT5 reports are generated for the `12`-symbol basket and before generating trade CSV logs for FTMO rolling-challenge survivability analysis.
- Completeness filter: Eliminate a manifold if any required report is missing or unparseable. `US100` IS is exempt because `US100` is validation/OOS-only.
- Trade-count filters: Eliminate a manifold if total trades across all tested symbols and periods are `< 1500`, or validation plus OOS trades are `< 1000`, or OOS trades are `< 500`.
- Aggregate performance filters: Eliminate a manifold if aggregate validation profit is `<= 0`, aggregate OOS profit is `<= 0`, aggregate validation profit/DD ratio is `< 1.5`, or aggregate OOS profit/DD ratio is `< 1.5`.
- Catastrophic drawdown filter: Eliminate a manifold if any single symbol/period has equity DD `> 60%`.
- Symbol coverage filter: Eliminate a manifold if fewer than `7 / 12` basket symbols are profitable in OOS.
- Market group filter: Eliminate a manifold if OOS is negative in more than one whole market group. Market groups are FX, metals, indices, and energy.
- Concentration filters: Eliminate a manifold if one symbol contributes more than `50%` of aggregate OOS profit, one market group contributes more than `70%` of aggregate OOS profit, or any single-symbol OOS loss consumes more than `30%` of aggregate OOS profit.
- Stability filter: Eliminate a manifold if aggregate OOS profit/DD ratio is less than `40%` of aggregate validation profit/DD ratio.
- Decision: These are broad elimination gates only. Do not pick the final manifold from these MT5 report metrics. Final ranking should be based on trade CSV FTMO survivability analysis, with average/resolved pass rate first and average/median pass time second.

### 2026-06-10 - FTMO-First Evaluation Plan From Expanded-Basket Checkpoint

- Goal: Reframe the expanded-basket analysis around the actual FTMO objective instead of relying too heavily on full-period MT5 report drawdown.
- Current run status: The expanded-basket restartable runner is still in progress and should continue overnight and into tomorrow in case an untested manifold performs materially better.
- Preliminary observation: Early report-level screening showed severe failures on several symbols, especially `USOIL`, with additional drag from `EURJPY`, `UKOIL`, `USDJPY`, `US500`, and `US30` depending on the reduced basket used.
- Important interpretation: Full-period MT5 max drawdown is not the same as FTMO first-passage success. A strategy may hit the `+10%` target before a later full-period drawdown occurs, so report-level DD can be too indirect for the final FTMO decision.
- FTMO objective: Evaluate whether a simulated account reaches `+10%` before `-10%`, while also checking the daily loss rule.
- Planned code change: Modify `TradeLogger.mqh` and EA inputs so trade CSV rows include manifold/test identity, likely `g_TradeCsvManifoldId` and `g_TradeCsvTestId`.
- Planned file behavior: Write one appendable CSV per manifold, creating a new file for a new manifold and appending for existing manifold tests. This avoids depending on the order in which MT5 executes individual symbol/segment tests.
- Planned analysis behavior: Sort manifold CSV rows by `deal_time`, dedupe rerun rows with a stable key such as `manifold_id + test_id + symbol + ticket + trade_id + entry_type + deal_time`, then run rolling FTMO first-passage simulations.
- Ranking metrics: Pass rate is primary, median pass duration is secondary, and average pass duration is tertiary. Unresolved starts should be reported separately.
- Provisional grading: `A` requires pass rate `>= 80%`, median pass duration `<= 60` days, and average pass duration `<= 90` days. `B` requires pass rate `>= 70%`, median `<= 90` days, and average `<= 120` days. `C` requires pass rate `>= 60%`, median `<= 120` days, and average `<= 180` days.
- Decision or next step: Use `B` as the provisional minimum acceptable FTMO grade. Implement the manifold-aware CSV logging and rolling FTMO path analysis after the current overnight expanded-basket run completes or is stopped.

### 2026-06-11 - Expanded-Basket Fixed Report Review Complete

- Goal: Analyze the completed expanded-basket fixed MT5 report batch for all `73` selected stop-loss-split candidate manifolds across the `12`-symbol basket.
- Source files: `reports/expanded_basket/*.xml.htm`, generated from `Files/WeekHighLow/expanded_basket_manifest.csv` by the restartable expanded-basket runner.
- Test coverage: `2,555` manifest tests, `2,555` reports parsed, `73` complete manifolds, and `0` partial/missing manifolds.
- Full-basket result: `0` manifolds survived the frozen pre-CSV report-level filters.
- Full-basket gate counts: `34 / 73` manifolds had positive aggregate validation profit, `44 / 73` had positive aggregate OOS profit, `0 / 73` had validation ratio `>= 1.5`, `0 / 73` had OOS ratio `>= 1.5`, `2 / 73` had max single-report DD `<= 60%`, and `73 / 73` passed the broad trade-count gates.
- Main full-basket failure modes: `USOIL` was catastrophic in validation and OOS, with `0 / 73` profitable reports in both `USOIL VAL` and `USOIL OOS`. `UKOIL VAL/OOS`, `EURJPY IS/OOS`, `USDJPY IS`, `US500 IS/VAL`, and `GBPUSD IS` were also major drags.
- Strong full-basket areas: `EURUSD` and `XAUUSD` were strong across IS/VAL/OOS. `XAGUSD` was generally useful. `USDJPY VAL/OOS`, `US500 OOS`, `USOIL IS`, and `UKOIL IS` were strong in isolated periods but did not generalize across their full symbol/period workflows.
- Reduced-basket result: Removing only `USOIL`, or removing `USOIL`, `EURJPY`, `UKOIL`, and `USDJPY`, still produced `0` report-level survivors.
- Reduced-basket result: Removing oil, `EURJPY`, `USDJPY`, `US500`, and `US30` still produced `0` report-level survivors across the remaining `EURUSD`, `GBPUSD`, `XAUUSD`, `XAGUSD`, `US100`, and `UK100` basket.
- Core four-symbol result: On `EURUSD`, `GBPUSD`, `XAUUSD`, and `XAGUSD`, some manifolds passed the base report-level criteria, but `0` survived the full concentration filters. This core is useful as an FTMO replay shortlist, not as a clean broad-market deployment result.
- Best core candidates: `RUN1_Pass1991` had validation ratio `3.277`, OOS ratio `2.215`, max DD `38.60%`, and `3 / 4` OOS-positive symbols. `RUN1_Pass2794` and `RUN1_Pass3059` each had validation ratio `2.804`, OOS ratio `1.901`, max DD `40.95%`, and `4 / 4` OOS-positive symbols. `RUN2_Pass5578` had validation ratio `2.784`, OOS ratio `1.610`, max DD `33.72%`, and `3 / 4` OOS-positive symbols. `RUN2_Pass5191` had validation ratio `1.858`, OOS ratio `1.503`, max DD `51.21%`, and `3 / 4` OOS-positive symbols.
- Core candidate parameter region: all shortlisted core candidates used `g_MinClusterSize=4`, `g_TakeProfitMultiplier=1`, `g_MinPullback_ATR_multiplier=0.8`, cluster multiplier mostly `0.5`, stop-loss multiplier `0.4 -> 0.5`, impulse lookback `72 -> 144`, pullback lookforward `18 -> 24`, and impulse multiplier `0.6 -> 0.8`.
- FTMO interpretation: Report-level filters are useful for stress testing, but full-period MT5 DD and aggregate report ratios remain indirect for FTMO. Final evaluation should use manifold-aware trade CSV files and rolling first-passage simulation.
- FTMO grading update: Because FTMO has both challenge and verification stages, single-stage pass rate compounds over two target-reaching stages. A `70%` single-stage rate implies only about `49%` two-stage success, while `80%` implies `64%` and `85%` implies `72.25%`. Funded-stage payout does not require another `+10%` target, so funded survival should be evaluated separately rather than as a third identical first-passage stage.
- Revised provisional FTMO target: Use evaluation pass rate `>= 80%` as the minimum viable target, `>= 85%` as preferred, with median pass duration ideally `<= 90` days and average pass duration ideally `<= 120` days. Funded mode should likely use lower risk than evaluation mode and focus on avoiding breach while remaining profitable.
- Decision or next step: Do not promote any `12`-symbol manifold from this batch as robust. Implement manifold-aware CSV logging and rolling FTMO first-passage analysis next, starting with the core shortlist `RUN1_Pass2794`, `RUN1_Pass3059`, `RUN1_Pass1991`, `RUN2_Pass5578`, and `RUN2_Pass5191`.

### 2026-06-11 - Manifold-Aware Trade CSV Logging Implemented

- Goal: Make MT5 fixed-test trade logs suitable for FTMO first-passage analysis by grouping trade events by manifold instead of relying on report execution order.
- Change: Added EA inputs `g_TradeCsvManifoldId` and `g_TradeCsvTestId` to `Experts/WeekHighLow/WeekHighLowEA.mq5`.
- Change: Updated `Experts/WeekHighLow/TradeLogger.mqh` to write `manifold_id` and `test_id` columns and to write one common-files CSV per manifold using `manifold_trades_<manifold_id>.csv`.
- Change: Updated `Files/WeekHighLow/New-ExpandedBasketBatch.ps1` so newly generated expanded-basket presets include the CSV identity inputs with logging disabled by default.
- Change: Updated `Files/WeekHighLow/Run-ExpandedBasketRestartable.ps1` with `-EnableTradeCsvLogging`, which creates a temporary per-test preset that enables logging and injects the current `ManifoldId` and `TestId`.
- Change: Added `-RunExistingReports` to the restartable runner so completed report tests can be rerun intentionally for CSV generation without being skipped by existing reports/progress.
- Change: Added `-ManifoldId` and `-Symbol` filters to the restartable runner so CSV replay can target shortlisted manifolds and core symbols without rerunning the full expanded basket.
- Verification: PowerShell parser checks passed for `Run-ExpandedBasketRestartable.ps1` and `New-ExpandedBasketBatch.ps1`.
- Verification: Compiled `Experts/WeekHighLow/WeekHighLowEA.mq5` with MetaEditor64. Result was `0` errors and `0` warnings.
- Cleanup decision: The generated fixed report artifacts in terminal-data `reports/expanded_basket` are no longer needed for durable analysis and may be deleted. Preserve candidate CSVs, manifest/progress CSVs, expanded-basket `.set` files, and any generated `manifold_trades_*.csv` files.
- Decision or next step: Use the new runner switches to regenerate trade CSVs for shortlisted core manifolds `RUN1_Pass2794`, `RUN1_Pass3059`, `RUN1_Pass1991`, `RUN2_Pass5578`, and `RUN2_Pass5191` on `EURUSD`, `GBPUSD`, `XAUUSD`, and `XAGUSD`, then implement or run rolling FTMO first-passage analysis on the resulting `manifold_trades_*.csv` files.

### 2026-06-11 - Core Manifold FTMO Closed-PnL Replay

- Goal: Evaluate shortlisted core manifolds using rolling FTMO-style first-passage analysis rather than full-period MT5 report metrics.
- Source files: `manifold_trades_RUN1_Pass2794.csv`, `manifold_trades_RUN1_Pass3059.csv`, `manifold_trades_RUN1_Pass1991.csv`, `manifold_trades_RUN2_Pass5578.csv`, and `manifold_trades_RUN2_Pass5191.csv` in the MT5 common files area.
- Scope: Core symbols only: `EURUSD`, `GBPUSD`, `XAUUSD`, and `XAGUSD`.
- Method: Start a replay from every closed trade event, sort all trade events by `deal_time`, and stop each simulation when the account hits `+10%`, `-10%`, a `5%` daily-loss proxy, or end of data.
- Important limitation: Daily loss is calculated from closed P/L only. The CSV does not contain floating equity, so true intratrade daily loss breaches may be missed.
- CSV health: All five manifold CSVs parsed successfully. No malformed `manifold_id` / `test_id` rows remained after fixing string-input `.set` formatting. No duplicate rows were removed.
- Baseline result without entry-hour filtering: `0.25%` risk produced high pass rates but very long duration. `RUN1_Pass1991 @ 0.25%` had pass rate `93.35%` with median pass duration `919.83` days. `RUN2_Pass5191 @ 0.25%` had pass rate `91.51%` with median `552.94` days.
- Baseline result without entry-hour filtering: `RUN2_Pass5191` was the best practical unfiltered candidate. At `0.35%`, pass rate was `85.30%` with median `367.85` days. At `0.40%`, pass rate was `80.16%` with median `294.68` days. At `0.45%`, pass rate was `75.88%` with median `233.02` days.
- Hypothesis tested: Filter entries to the active session by keeping trades whose entry event hour is between `08` and `17` inclusive, while retaining the matching exit event regardless of exit hour.
- Entry-hour filter result: The `08 -> 17` entry filter materially improved pass rates but generally increased pass duration at comparable risk.
- Best `80%+` filtered candidates: `RUN2_Pass5191 @ 0.60%` had pass rate `80.65%`, median `213.75` days, average `294.68` days, `24` daily-loss-proxy failures, and `641` global-loss failures. `RUN1_Pass1991 @ 0.80%` had pass rate `80.63%`, median `219.48` days, average `286.62` days, `0` daily-loss-proxy failures, and `447` global-loss failures.
- Stronger reliability filtered candidates: `RUN2_Pass5191 @ 0.55%` had pass rate `83.67%`, median `243.08` days, average `336.97` days, and `0` daily-loss-proxy failures. `RUN1_Pass1991 @ 0.70%` had pass rate `84.68%`, median `283.68` days, average `362.80` days, and `0` daily-loss-proxy failures.
- Faster but lower-pass-rate filtered candidates: `RUN1_Pass1991 @ 1.00%` had pass rate `75.56%`, median `150.35` days, average `184.99` days, and `35` daily-loss-proxy failures. `RUN1_Pass1991 @ 1.20%` had pass rate `71.38%`, median `98.96` days, average `133.75` days, and `118` daily-loss-proxy failures.
- High-risk sweep conclusion: Risk above `1.0%` reduces pass duration but drops pass rate below the `80%` target and materially increases daily-loss-proxy failures. The best high-risk manifold remains `RUN1_Pass1991`, especially around `1.1% -> 1.2%`, but this is below the preferred reliability threshold.
- Current best balance: `RUN1_Pass1991 @ 0.80%` with the `08 -> 17` entry filter is the best balanced candidate so far because it stays near the `80%` pass-rate threshold, has median pass duration near `220` days, average near `287` days, and has `0` closed-PnL daily-loss-proxy failures.
- Current safer candidate: `RUN1_Pass1991 @ 0.70%` with the `08 -> 17` entry filter has pass rate `84.68%`, median `283.68` days, and `0` daily-loss-proxy failures.
- Current aggressive candidate: `RUN1_Pass1991 @ 0.90%` with the `08 -> 17` entry filter has pass rate `77.38%`, median `178.98` days, average `223.14` days, and `0` daily-loss-proxy failures, but falls below the `80%` target.
- Decision or next step: Treat the `08 -> 17` entry-hour filter as promising. Next useful analysis is to test adjacent session windows and/or symbol-level contribution for `RUN1_Pass1991`, especially around `0.70% -> 0.90%` communal risk.

### 2026-06-12 - Symbol-Specific Behavior Cluster Research Direction

- Goal: Reframe the next robustness search around FTMO challenge plus verification completion speed while preserving the existing fixed-manifold workflow.
- Decision: Keep the previous global fixed-manifold approach documented, but add a parallel research direction where each symbol can earn inclusion by showing multiple profitable and behaviorally distinct parameter families.
- New robustness definition under consideration: A symbol is stronger if it has several validation-profitable behavior clusters, not merely one best manifold. A portfolio unit is `symbol + behavior cluster representative` rather than just `symbol` or one global manifold.
- Proposed selection rule: Choose one random or median representative from each accepted behavior cluster, not the historical best member by default. This avoids leaderboard selection and avoids running multiple clones from the same behavior cluster.
- Proposed behavior distinctness metrics: Use `OverlapCoverage = MatchedTrades / min(TradeCountA, TradeCountB)` and `JaccardOverlap = MatchedTrades / (TradeCountA + TradeCountB - MatchedTrades)` after matching trades by symbol, direction, entry-time tolerance, and possibly price tolerance.
- Initial cluster thresholds: Treat candidates as separate behavior clusters when `OverlapCoverage < 60%` and `JaccardOverlap < 40%`. Use stricter thresholds such as `OverlapCoverage < 40%` and `JaccardOverlap < 25%` if portfolio independence needs to be higher.
- Proposed symbol classification: `0` clusters rejects a symbol, `1` cluster makes it a specialist, `2` clusters makes it a support/minimum-robust symbol, and `3+` clusters makes it a core symbol.
- FTMO objective update: The desired evaluation target is passing challenge `+10%` plus verification `+5%` in under `90` calendar days before daily/global breach. Funded mode should be evaluated separately with lower risk and a steady `1% -> 3%` monthly profit objective on aggregated funded capital.
- Decision or next step: Implement or extend utilities for parameter clustering, trade-overlap clustering, representative selection, and portfolio FTMO replay over selected `symbol + behavior cluster` units.

### 2026-06-14 - FTMO Goal Realignment

- Goal: Realign the project objective around the user's intended FTMO business model rather than treating one strategy as responsible for both challenge passing and funded-account operation.
- Decision: Separate evaluation/challenge mode from funded mode. The challenge strategy may be different from the funded strategy.
- Challenge-mode objective: Use aggressive account-acquisition logic if needed, targeting FTMO `+10%` first-passage before daily/global breach. Preferred pass speed is roughly `20 -> 30` trading days, with `40` trading days treated as the current upper acceptable limit. Calendar days should still be reported because account operations are calendar-based, but weekend market closures mean trading days are the cleaner opportunity measure.
- Challenge-fee economics: A high challenge-failure rate may be acceptable if expected challenge-fee cost per successfully funded account is reasonable. Example framing discussed: a `100K` challenge costing about `GBP 500`; failing `9` attempts and passing on the `10th` costs about `GBP 5,000` in challenge fees for one funded account.
- Funded-mode objective: After funded status, do not continue optimizing for fast `+10%` gains. Use lower-risk operation targeting roughly `1% -> 3%` monthly, with the intention to scale funded capital across additional accounts toward about `1,000,000` total funded capital.
- Analysis implication: Challenge-mode analysis should rank candidates by pass-before-breach probability, pass speed within `40` trading days, expected challenge-fee cost per pass, daily/global breach frequency, and losing-streak distribution. Funded-mode analysis should separately report monthly return distribution, breach probability, payout survival, and survival over `3`, `6`, and `12` months.
- Decision or next step: Preserve the old fixed-manifold and behavior-cluster robustness workflows, but evaluate their candidates separately for challenge mode and funded mode instead of assuming one manifold must satisfy both objectives.

### 2026-06-15 - Funded Symbol-Specific Pivot And USDJPY Validation

- Goal: Continue funded-mode research after the EURUSD-derived fixed-global manifold failed to validate as a `6 -> 12` symbol portfolio.
- Corrected cross-symbol finding: Including IS performance materially weakened the previous EURUSD-derived cross-symbol interpretation. For the reviewed EURUSD-derived funded passes, only `EURUSD` was accepted across `IS + VAL + OOS`; no candidate passed as a credible multi-symbol fixed funded manifold.
- Decision: Abandon the assumption that one EURUSD-derived parameter manifold should work across `6 -> 12` symbols. Do not abandon the high/low strategy yet; pivot to symbol-specific or cluster-specific funded validation.
- Funded portfolio target update: Treat `EURUSD + 2 -> 4` independently validated symbols as the practical target. Minimum viable funded portfolio is `2 -> 3` robust symbols; good target is `4 -> 5`; stretch target is `6`.
- XAUUSD setup: Created `Profiles/Tester/ImpulseContinuation_XAUUSD_Funded_Genetic.set` and `Files/WeekHighLow/XAUUSD_Funded_Genetic.ini` for a gold-specific funded genetic run over `2000.01.01 -> 2018.01.01` with real ticks.
- XAUUSD outcome: OANDA tester reported `XAUUSD: ticks data begins from 2025.01.02 00:00`, matching the earlier metals tick-history limitation seen on `XAGUSD`. Metals are paused on this OANDA data feed unless using another model/feed or accepting non-real-tick testing.
- USDJPY setup: Created `Profiles/Tester/ImpulseContinuation_USDJPY_Funded_Genetic.set` and `Files/WeekHighLow/USDJPY_Funded_Genetic.ini` for a USDJPY-specific funded genetic run over `2000.01.01 -> 2018.01.01` with optimizer forward validation.
- USDJPY genetic source files: `reports/USDJPY_D1StopLossSplit_Funded_Genetic_2000_2018_FWD_20260615.xml` and `.forward.xml`.
- USDJPY genetic outcome: `4,746` paired rows, `2,912` positive IS+forward pairs, `1,475` ratio-qualified pairs, `1,454` after drawdown cap, `103` strict candidates, and `1,292` loose candidates.
- USDJPY OOS setup: Created fixed OOS presets/configs for passes `3363`, `3401`, `2650`, `3563`, `1583`, `2185`, `1811`, and `2402`, plus `Files/WeekHighLow/Run-USDJPY-FundedOos.ps1`.
- USDJPY OOS report location: `reports/usdjpy_funded_oos`. The OOS configs were updated to write into this dedicated folder instead of the shared `reports` root.
- USDJPY OOS test setup: Fixed single-test runs, optimization disabled, `2018.01.01 -> 2026.06.01`, funded acceptance criteria of profit `> 0`, profit/DD ratio `> 2.0`, and equity DD `<= 30%`.
- USDJPY OOS outcome: `8` reports parsed, `7` profitable, `3` ratio-qualified, `6` under DD cap, and `3` accepted.
- USDJPY accepted OOS candidates: pass `1811` had OOS profit `61,547.28`, DD `13.16%`, ratio `4.677`, `157` trades, PF `1.38`; pass `2402` had OOS profit `52,548.93`, DD `15.02%`, ratio `3.499`, `195` trades, PF `1.25`; pass `3363` had OOS profit `66,346.10`, DD `22.49%`, ratio `2.950`, `132` trades, PF `1.45`.
- USDJPY best candidate: pass `1811`, because it had the strongest OOS ratio and also passed IS and forward cleanly: IS ratio `7.90` with DD `14.56%`, forward ratio `6.04` with DD `12.67%`, and OOS ratio `4.677` with DD `13.16%`.
- USDJPY expanded OOS follow-up: Because the genetic run produced many candidates and OOS tests were quick, added `Files/WeekHighLow/Run-USDJPY-FundedTop20Oos.ps1` to test the top `20` optimizer-forward candidates by funded ratio, skipping existing reports in `reports/usdjpy_funded_oos` by default.
- Runner fix: Corrected the OOS runner process-wait logic in `Run-EURUSD-FundedOos.ps1`, `Run-USDJPY-FundedOos.ps1`, and `Run-USDJPY-FundedTop20Oos.ps1`. The previous `Wait-Process` usage mislabeled completed MT5 runs as `TimedOut`; the scripts now use `$process.WaitForExit(...)`.
- USDJPY expanded OOS result: The folder contained `26` total USDJPY OOS reports after the top-20 follow-up, including the original `8`-candidate shortlist plus the expanded top-20 set. Across all `26`, `14` were profitable and `4` were accepted. Within the top-20 subset, `20` reports were parsed, `8` were profitable, and `2` were accepted.
- USDJPY additional accepted candidate: pass `2698` was newly accepted from the expanded top-20 follow-up, with OOS profit `53,065.45`, DD `19.47%`, ratio `2.725`, `138` trades, and PF `1.45`. It also passed IS and forward: IS ratio `7.30`, DD `12.41%`, `210` trades; forward ratio `8.96`, DD `10.28%`, `97` trades.
- USDJPY accepted set after expansion: passes `1811`, `2402`, `3363`, and `2698` all passed the full `IS + forward + OOS` funded screen. Pass `1811` remains the lead candidate; the expanded top-20 run strengthened USDJPY confidence but did not change the best pass.
- Current funded status: `EURUSD` is provisionally validated; `USDJPY` is provisionally validated. Both still need later robustness checks such as shifted walk-forward windows, parameter-neighborhood stability, cost stress, monthly return distribution, and Monte Carlo/trade-skip stress.
- Decision or next step: Need at least one more robust symbol for a minimum viable funded portfolio, preferably `2 -> 3` more. Since OANDA real-tick metals are blocked historically, next FX candidate should be `GBPUSD`, followed by `EURJPY` only if GBPUSD is weak or inconclusive.

### 2026-06-18 - EURUSD-Generated Cross-Symbol Promotion Workflow

- Goal: Update the funded research workflow after reviewing the latest experiment direction.
- Decision: Use the EURUSD genetic backtest as the candidate generator rather than independently discovering each symbol first.
- Workflow: Select top `N` EURUSD genetic candidates, run those candidates across all target symbols in in-sample plus validation, define `S*` as the successful cross-symbol subset, run only `S*` in OOS, and keep `S^`, the subset of `S*` that also passes OOS.
- Trade-count decision: Do not eliminate individual candidates only because their trade count is below `100`. Low-trade candidates can remain if they contribute to a useful final subset.
- Portfolio-frequency rule: Evaluate trade frequency using the aggregate trade count of `S^`, not a per-candidate minimum-trade rule.
- Main concern: EURUSD-generated candidates may still be EURUSD-specific. Cross-symbol `IS + VAL` plus OOS filtering reduces this risk but does not eliminate survivor-luck or selection-bias risk.
- Validation adjustment: Treat `S^` as a candidate portfolio, not as proven robust. Audit whether `S^` has multiple surviving candidates, distributed profit, distributed trade count, and no single symbol or candidate dominating profit or drawdown.
- FTMO adjustment: Full-period OOS report profit is not enough for challenge mode. Promoted candidates still need rolling first-passage analysis for target-before-breach probability, pass speed, daily/global breach behavior, expected challenge-fee cost, and losing-streak risk.
- Funded adjustment: Funded-mode promotion should depend on monthly return distribution, payout survival, and breach probability over `3`, `6`, and `12` months, not only aggregate OOS profit.
- Robustness adjustment: Promising `S^` portfolios should later be stress-tested with cost/spread assumptions, trade-skip or Monte Carlo perturbations, and shifted windows.
- Decision or next step: Apply this workflow to the newly available results from yesterday's experiment, then judge whether `S^` has enough aggregate trade count, enough distribution across symbols/candidates, and enough path-dependent FTMO/funded quality for the next analysis step.

### 2026-06-18 - EURUSD FTMO Genetic Cross-Symbol IS+VAL Review

- Goal: Test whether EURUSD-generated FTMO candidate manifolds can transfer broadly enough across the FTMO symbol universe to justify OOS testing and later FTMO challenge/funded analysis.
- Source folder: `reports/ftmo_eurusd_d1_stoploss_split_genetic_20260617`.
- Genetic source files: `EURUSD_D1StopLossSplit_FTMO_Genetic_2000_2018_FWD_20260617.xml` and `.forward.xml`.
- Source runner: `Files/WeekHighLow/Run-EURUSD-FTMO-Genetic.ps1`.
- Genetic parse result: `5,105` optimizer rows, `5,105` forward rows, `3,039` positive IS+forward pairs, `907` ratio-qualified pairs, and `884` candidates after drawdown cap when no trade-count filter was applied.
- Profit-floor rule applied: kept candidates with IS profit `>= 25,000`, forward profit `>= 20,000`, and combined IS+forward profit `>= 50,000`, without eliminating candidates for fewer than `100` trades.
- Profit-floor result: `548` candidates remained from `884` ratio/DD-qualified candidates.
- Cross-symbol runner added: `Files/WeekHighLow/Run-FTMO-EURUSDGeneticCrossSymbolIsValRestartable.ps1`.
- Cross-symbol test scope: top `20` profit-floor EURUSD-generated manifolds across `43` symbols and `2` segments, IS `2000.01.01 -> 2012.01.01` and VAL `2012.01.01 -> 2018.01.01`.
- Symbol universe: `28` FX pairs, `9` metals, `4` FTMO-style `.cash` indices, and `2` FTMO-style `.cash` oil symbols.
- Symbol corrections made during setup: use `XPDUSD` instead of `XPDEUR`, use `XCUUSD` instead of `XCUAUD`, and use `.cash` suffixes for FTMO index/oil symbols such as `US500.cash` and `UKOIL.cash`.
- Current-manifest run status: `1,720 / 1,720` expected reports completed and existed. Older progress rows from a pre-correction manifest were ignored during analysis.
- Parsed analysis files created in the source folder: `cross_symbol_is_val_parsed_reports.csv`, `cross_symbol_is_val_manifold_summary.csv`, `cross_symbol_is_val_symbol_summary.csv`, `cross_symbol_is_val_symbol_segment_summary.csv`, `cross_symbol_is_val_group_summary.csv`, `cross_symbol_is_val_Sstar_full_universe.csv`, and `cross_symbol_is_val_diagnostic_focus_candidates.csv`.
- Row-level cross-symbol result: `1,720` reports parsed, `321` profitable rows, `116` rows with profit and ratio `> 2`, `1,317` rows with DD `<= 30%`, and `114` rows accepted by profit, ratio `> 2`, and DD `<= 30%`.
- Full-universe promotion result: `0 / 20` manifolds had positive aggregate IS and positive aggregate VAL across all `43` symbols. The agreed full-universe `S*` is empty.
- Main failure mode: FX aggregate performance was strongly negative at about `-19.93M`, with especially severe losses on `GBPNZD`, `GBPCAD`, `EURCHF`, `EURGBP`, `AUDCAD`, `AUDJPY`, `NZDCAD`, `CHFJPY`, and `NZDCHF`.
- Data/coverage finding: all `.cash` indices and `.cash` oil symbols produced `0` trades in this run. Several non-USD metal crosses also produced `0` trades: `XAUEUR`, `XAUAUD`, `XAGEUR`, `XAGAUD`, and `XCUUSD`.
- Best symbols by aggregate IS+VAL behavior were `EURUSD`, `NZDJPY`, and `XAUUSD`. `EURUSD` was accepted in all `40 / 40` rows, `NZDJPY` was accepted in `14 / 40`, and `XAUUSD` was positive but weak by acceptance count with `4 / 40` accepted and no VAL accepted rows.
- Diagnostic-only reduced-symbol result: on just `EURUSD`, `NZDJPY`, and `XAUUSD`, passes `1640`, `3697`, `3242`, `3422`, and `3674` had positive aggregate IS/VAL profit and aggregate ratio `> 2` in both segments. These do not satisfy the agreed full-universe `S*` gate.
- Decision: Under the current FTMO objective and full-universe transferability workflow, this EURUSD-generated D1 stop-loss-split high/low strategy is not suitable for FTMO. Do not promote this batch to full-universe OOS or FTMO challenge/funded simulations.
- Next step: Stop spending compute on this strategy for FTMO unless a new hypothesis materially changes the signal logic, symbol universe, data source, or selection objective. Any future review of the diagnostic `EURUSD/NZDJPY/XAUUSD` subset should be treated as a separate specialist-symbol experiment, not evidence that the strategy is FTMO-suitable.

### 2026-06-20 - OANDA EURUSD/XAUUSD Same-Manifold Personal-Account Study

- Goal: Reframe the strategy away from FTMO and toward a personal OANDA account using `EURUSD` and `XAUUSD` with the same parameter manifold. The benchmark is to outperform an S&P500-style long-horizon return from `2000 -> 2026`, roughly `100,000 -> 800,000` for a `700%` total-return reference.
- Source folder: `reports/oanda_eurusd_xauusd_same_manifold_20260619`.
- Genetic setup files: `Files/WeekHighLow/OANDA_EURUSD_Genetic_20260619.ini`, `Files/WeekHighLow/Run-OANDA-EURUSD-Genetic-20260619.ps1`, and `Profiles/Tester/ImpulseContinuation_OANDA_EURUSD_Genetic_20260619.set`.
- Genetic test setup: OANDA live server, `EURUSD`, `H1`, real ticks, `2000.01.01 -> 2018.01.01`, optimizer forward validation enabled, D1 high/low clustered stop-loss-split logic, `g_Risk_Percentage = 1.0`, CSV logging disabled.
- Genetic parameter change: `g_ATR_Period` was optimized with start `14`, step `7`, max `49` instead of being fixed at `14`.
- Genetic parse result: `5,935` optimizer rows, `5,935` forward rows, `5,935` paired rows, `3,685` positive IS+forward pairs, `1,261` ratio-qualified pairs, `1,211` after DD cap, `188` strict trade candidates, and `1,043` loose trade candidates.
- Genetic candidate exports: `EURUSD_D1StopLossSplit_OANDA_Genetic_2000_2018_FWD_20260619_loose_candidates.csv` and `EURUSD_D1StopLossSplit_OANDA_Genetic_2000_2018_FWD_20260619_loose_candidates_with_atr.csv`.
- Top genetic candidates by total IS+forward profit included pass `2551` with total profit `712,713.53`, pass `2012` with `672,364.63`, pass `1780` with `519,508.75`, pass `2575` with `503,053.81`, and pass `2577` with `481,829.14`.
- Top genetic candidates by minimum IS/forward profit-DD ratio included pass `2843` with min ratio `10.717`, pass `2069` with `10.611`, pass `2828` with `10.297`, pass `4744` with `8.917`, pass `4141` with `8.700`, pass `2276` with `8.302`, and pass `533` with `8.262`.
- Fixed-test runner added: `Files/WeekHighLow/Run-OANDA-EURUSD-XAUUSD-SameManifoldFixed-20260619.ps1`.
- Fixed-test shortlist: passes `2843`, `2069`, `4744`, `533`, `2551`, and `2012`.
- Fixed-test scope: `EURUSD` OOS `2018.01.01 -> 2026.06.01`, plus `XAUUSD` IS `2000.01.01 -> 2012.01.01`, validation `2012.01.01 -> 2018.01.01`, and OOS `2018.01.01 -> 2026.06.01`, using the same manifold on both symbols.
- Fixed-test result: `24 / 24` reports completed and parsed. All `24` reports were profitable, `20` had profit/DD ratio `> 2`, `20` were under the DD cap, and `19` were accepted by profit, ratio, and DD.
- Fixed-test analysis files: `fixed_same_manifold_analyzer_reports.csv`, `fixed_same_manifold_parsed_reports.csv`, and `fixed_same_manifold_pass_summary.csv`.
- Fixed-test best total-profit candidate: pass `2012` had total fixed-test profit `456,252.83`, with `EURUSD` OOS profit `170,956.26`, `XAUUSD` IS profit `135,339.72`, `XAUUSD` validation profit `52,877.45`, `XAUUSD` OOS profit `97,079.40`, max DD `28.15%`, min ratio `1.878`, and `3 / 4` accepted rows.
- Fixed-test cleanest balanced candidate: pass `2551` had total fixed-test profit `351,485.49`, with `EURUSD` OOS profit `96,947.48`, `XAUUSD` IS profit `84,487.89`, `XAUUSD` validation profit `84,855.49`, `XAUUSD` OOS profit `85,194.63`, max DD `17.98%`, min ratio `4.719`, and `4 / 4` accepted rows.
- Additional clean candidate: pass `2069` had total fixed-test profit `311,980.07`, max DD `27.25%`, min ratio `2.970`, and `4 / 4` accepted rows.
- Portfolio CSV replay runner added: `Files/WeekHighLow/Run-OANDA-SameManifoldPortfolioCsv-20260619.ps1`.
- Portfolio CSV replay scope: full-period `2000.01.01 -> 2026.06.01` for `EURUSD` and `XAUUSD`, generating one pass-level CSV per manifold in the MT5 common files directory.
- Portfolio CSV files: `manifold_trades_OANDA_SameManifold_Pass2551_FullPortfolio.csv` and `manifold_trades_OANDA_SameManifold_Pass2012_FullPortfolio.csv`.
- Portfolio CSV replay status: `4 / 4` MT5 runs completed, all reports existed, and both pass-level CSVs were created.
- Portfolio analysis files: `portfolio_closed_pnl_summary.csv`, `portfolio_normalized_risk_summary.csv`, `portfolio_normalized_risk_sweep_summary.csv`, and `portfolio_normalized_oos_2018_2026_summary.csv`.
- Raw closed-PnL full-period result: pass `2012` ended at `1,742,123.96` from `100,000`, total return `1,642.12%`, CAGR `11.65%`, max closed DD `23.81%`, `1,340` closed trades, profit factor `1.49`; pass `2551` ended at `1,705,764.52`, total return `1,605.76%`, CAGR `11.37%`, max closed DD `21.30%`, `1,218` closed trades, profit factor `1.51`.
- Raw closed-PnL symbol contribution: pass `2012` produced `EURUSD` net `1,399,517.88` over `1,036` closed trades and `XAUUSD` net `242,606.08` over `304` closed trades; pass `2551` produced `EURUSD` net `1,385,085.33` over `895` closed trades and `XAUUSD` net `220,679.19` over `323` closed trades.
- Normalized shared-account replay method: Convert each closed trade into an approximate R-multiple from its original `1%` isolated-symbol risk, sort `EURUSD + XAUUSD` closed trades by `deal_time`, and replay them on one shared `100,000` account at selected risk percentages.
- Normalized full-period result at `0.50%` risk: pass `2012` ended at `744,101.43`, return `644.10%`, CAGR `8.04%`, max closed DD `12.62%`; pass `2551` ended at `714,155.26`, return `614.16%`, CAGR `7.75%`, max closed DD `11.24%`.
- Normalized full-period result at `0.55%` risk: pass `2012` ended at `905,734.13`, return `805.73%`, CAGR `8.87%`, max closed DD `13.81%`; pass `2551` ended at `866,022.48`, return `766.02%`, CAGR `8.54%`, max closed DD `12.30%`.
- Normalized full-period result at `0.75%` risk: pass `2012` ended at `1,973,471.69`, return `1,873.47%`, CAGR `12.18%`, max closed DD `18.39%`; pass `2551` ended at `1,859,970.45`, return `1,759.97%`, CAGR `11.74%`, max closed DD `16.41%`.
- Normalized full-period result at `1.00%` risk: pass `2012` ended at `5,137,439.43`, return `5,037.44%`, CAGR `16.40%`, max closed DD `23.81%`; pass `2551` ended at `4,762,359.61`, return `4,662.36%`, CAGR `15.80%`, max closed DD `21.30%`.
- Normalized `2018 -> 2026` OOS-only result at `1.00%` risk: pass `2012` ended at `164,032.78`, return `64.03%`, CAGR `8.05%`, max closed DD `19.64%`, `212` closed trades; pass `2551` ended at `136,585.79`, return `36.59%`, CAGR `3.80%`, max closed DD `19.83%`, `210` closed trades.
- Decision: Pass `2012` is the current lead candidate for the OANDA personal-account same-manifold objective because it has stronger full-period normalized return and stronger `2018 -> 2026` OOS-only behavior. Pass `2551` remains the smoother backup with lower full-period closed DD but weaker OOS-only CAGR.
- Important limitation: The normalized replay is a closed-PnL proxy and does not include intratrade floating equity. The full-period result includes the EURUSD discovery period, so it should not be treated as fully out-of-sample proof.
- Execution-stress runner added: `Files/WeekHighLow/Run-OANDA-Pass2012-ExecutionStress-20260620.ps1`.
- Execution-stress setup: pass `2012`, full-period `2000.01.01 -> 2026.06.01`, `EURUSD + XAUUSD`, CSV logging enabled, using MT5 tester `ExecutionMode` scenarios `RandomDelay = -1`, `Delay1000ms = 1000`, and `Delay3000ms = 3000`.
- Execution-stress status: `6 / 6` MT5 tests completed, all reports existed, and all three scenario CSVs were created: `manifold_trades_OANDA_Pass2012_ExecStress_RandomDelay.csv`, `manifold_trades_OANDA_Pass2012_ExecStress_Delay1000ms.csv`, and `manifold_trades_OANDA_Pass2012_ExecStress_Delay3000ms.csv`.
- Execution-stress analysis file: `pass2012_execution_stress_normalized_summary.csv`.
- Execution-stress result: All three scenarios produced identical normalized shared-account metrics to the baseline replay. At `0.55%` risk, each scenario ended at `905,734.13`, return `805.73%`, CAGR `8.87%`, and max closed DD `13.81%`. At `1.00%` risk, each ended at `5,137,439.43`, return `5,037.44%`, CAGR `16.40%`, and max closed DD `23.81%`.
- Execution-stress interpretation: MT5 `ExecutionMode` delay did not change economic fills for this pending-order EA in these backtests. This should not be treated as a successful spread/slippage robustness test.
- R-haircut stress script added and run: `Files/WeekHighLow/Analyze-OANDA-Pass2012-RHaircutStress-20260620.ps1`.
- R-haircut stress method: Convert each closed trade into an approximate R-multiple from the original `1%` isolated-symbol risk, then replay the combined `EURUSD + XAUUSD` trade stream while subtracting a fixed R penalty from every closed trade. This is a deliberately conservative proxy for execution cost/slippage/spread degradation.
- R-haircut output files: `pass2012_trade_r_multiples.csv`, `pass2012_r_haircut_stress_summary.csv`, and per-risk/per-haircut equity curves in `reports/oanda_eurusd_xauusd_same_manifold_20260619`.
- R-haircut full-period result at `0.55%` risk: no haircut ended at `905,734.13`, `0.05R` haircut ended at `626,901.09`, `0.10R` ended at `433,863.80`, `0.20R` ended at `207,744.93`, and `0.30R` ended at `99,433.23`.
- R-haircut full-period result at `1.00%` risk: no haircut ended at `5,137,439.43`, `0.05R` haircut ended at `2,633,419.32`, `0.10R` ended at `1,349,424.15`, `0.20R` ended at `353,973.13`, and `0.30R` ended at `92,728.02`.
- R-haircut OOS-only `2018 -> 2026` result at `1.00%` risk: no haircut ended at `164,032.78`, `0.05R` ended at `147,566.01`, `0.10R` ended at `132,745.29`, `0.20R` ended at `107,402.83`, and `0.30R` ended at `86,880.09`.
- User execution-cost interpretation: For OANDA pending-order execution, a constant `0.10R` degradation on every trade is not realistic outside major news events such as NFP. A `0.05R` haircut is closer to an upper-normal stress when risking `1%` per trade. Real execution variation is not one-way; some fills may be worse and some may be better, e.g. a loss might be `-$105` or `-$95` when nominal risk is `$100`, and a win might be lower or higher than expected.
- Decision: Treat `0.10R` as an extreme/major-news stress, not as the normal OANDA operating assumption. Under the more realistic `0.05R` upper-normal haircut, pass `2012` at `1.00%` risk still materially beats the S&P-style benchmark, ending at `2,633,419.32` from `100,000` with CAGR `13.44%` and max closed DD `25.67%`.
- Random execution-noise Monte Carlo script added and run: `Files/WeekHighLow/Analyze-OANDA-Pass2012-ExecutionNoiseMonteCarlo-20260620.ps1`.
- Random execution-noise Monte Carlo method: Use pass `2012` closed-trade R-multiples, replay the combined `EURUSD + XAUUSD` chronological trade stream, and add random per-trade execution noise instead of a one-way constant haircut.
- Monte Carlo setup: `1,000` iterations per scenario/risk/window, seed `2012`, windows `2000 -> 2026` and `2018 -> 2026`, risk levels `0.55%` and `1.00%`, benchmark balance `800,000` from `100,000` starting balance.
- Monte Carlo scenarios: `BalancedNoise` used `70%` unchanged, `14%` `+0.02R`, `14%` `-0.02R`, and `2%` `-0.10R`; `ConservativeNoise` used `60%` unchanged, `15%` `+0.02R`, `20%` `-0.02R`, and `5%` `-0.10R`; `NewsHeavyNoise` used `50%` unchanged, `15%` `+0.02R`, `25%` `-0.03R`, and `10%` `-0.10R`.
- Monte Carlo output files: `pass2012_execution_noise_mc_scenarios.csv`, `pass2012_execution_noise_mc_iterations.csv`, and `pass2012_execution_noise_mc_summary.csv`.
- Monte Carlo full-period result at `0.55%` risk: `BalancedNoise` median ending balance `892,491.95`, p05 `887,098.02`, benchmark beat rate `100%`; `ConservativeNoise` median `866,494.12`, p05 `859,188.62`, beat rate `100%`; `NewsHeavyNoise` median `814,160.22`, p05 `805,053.43`, beat rate `99.1%`.
- Monte Carlo full-period result at `1.00%` risk: `BalancedNoise` median ending balance `5,002,609.58`, p05 `4,948,156.77`, benchmark beat rate `100%`; `ConservativeNoise` median `4,744,069.78`, p05 `4,675,969.80`, beat rate `100%`; `NewsHeavyNoise` median `4,228,064.61`, p05 `4,147,848.76`, beat rate `100%`.
- Monte Carlo OOS-only `2018 -> 2026` result at `1.00%` risk: `BalancedNoise` median ending balance `163,345.26`, p05 `162,548.41`, profitable iterations `100%`; `ConservativeNoise` median `161,955.36`, p05 `160,988.43`, profitable `100%`; `NewsHeavyNoise` median `159,093.16`, p05 `157,829.76`, profitable `100%`.
- Updated interpretation: The random execution-noise model better matches observed OANDA behavior than a constant haircut. Under this model, pass `2012` remains robust, especially at `1.00%` risk. Even at `0.55%` risk, the full-period benchmark is beaten in nearly all Monte Carlo iterations, including `99.1%` under the news-heavy scenario.
- Shifted-window runner added and run: `Files/WeekHighLow/Run-OANDA-Pass2012-ShiftedWindows-20260620.ps1`.
- Shifted-window setup: pass `2012`, same fixed manifold on `EURUSD + XAUUSD`, real ticks, fixed tests over windows `2003.01.01 -> 2010.01.01`, `2010.01.01 -> 2017.01.01`, and `2017.01.01 -> 2026.06.01`.
- Shifted-window status: `6 / 6` reports completed and parsed.
- Shifted-window analysis files: `pass2012_shifted_windows_analyzer_reports.csv`, `pass2012_shifted_windows_parsed_reports.csv`, `pass2012_shifted_windows_summary_by_window.csv`, and `pass2012_shifted_windows_summary_by_symbol.csv`.
- Shifted-window `EURUSD` results: `2003 -> 2010` profit `226,142.72`, DD `24.69%`, ratio `9.159`, `458` trades; `2010 -> 2017` profit `126,936.02`, DD `23.19%`, ratio `5.474`, `417` trades; `2017 -> 2026` profit `225,899.78`, DD `24.38%`, ratio `9.266`, `594` trades. All three rows accepted.
- Shifted-window `XAUUSD` results: `2003 -> 2010` profit `119,371.07`, DD `13.12%`, ratio `9.098`, `133` trades; `2010 -> 2017` profit `68,216.18`, DD `20.08%`, ratio `3.397`, `211` trades; `2017 -> 2026` profit `106,848.86`, DD `24.02%`, ratio `4.448`, `296` trades. All three rows accepted.
- Shifted-window aggregate by window: `2003 -> 2010` total profit `345,513.79`, max DD `24.69%`, min ratio `9.098`, `591` trades; `2010 -> 2017` total profit `195,152.20`, max DD `23.19%`, min ratio `3.397`, `628` trades; `2017 -> 2026` total profit `332,748.64`, max DD `24.38%`, min ratio `4.448`, `890` trades.
- Shifted-window interpretation: This is a strong robustness result. Pass `2012` was profitable and accepted across both symbols and all three shifted windows, including the middle `2010 -> 2017` regime. This materially reduces the concern that the edge came from only one favorable era.
- Floating/equity drawdown review script added and run: `Files/WeekHighLow/Review-OANDA-Pass2012-FloatingDrawdown-20260620.ps1`.
- Floating/equity drawdown review scope: all relevant pass `2012` MT5 reports in `reports/oanda_eurusd_xauusd_same_manifold_20260619`, excluding execution-stress duplicates by default, with warning threshold set at `30%` equity DD.
- Floating/equity drawdown output files: `pass2012_floating_equity_drawdown_review.csv` and `pass2012_floating_equity_drawdown_summary.csv`.
- Floating/equity drawdown result: No reviewed pass `2012` report exceeded the `30%` equity DD warning threshold.
- Worst report by equity DD: `XAUUSD` validation fixed segment had equity DD `28.15%`, balance DD `26.56%`, floating premium `1.59%`, profit `52,877.45`, `214` trades, and profit/equity-DD ratio `1.878`.
- Worst shifted-window equity DD: `EURUSD 2003 -> 2010` had equity DD `24.69%`, balance DD `23.80%`, profit `226,142.72`, and ratio `9.159`.
- Full-portfolio equity DD: `XAUUSD FULL_2000_2026` had equity DD `23.25%`, balance DD `20.97%`, floating premium `2.28%`, and profit `242,606.08`; `EURUSD FULL_2000_2026` had equity DD `21.87%`, balance DD `20.91%`, floating premium `0.96%`, and profit `1,399,517.88`.
- Summary by scope: fixed segments had max equity DD `28.15%`; shifted windows had max equity DD `24.69%`; full-portfolio reports had max equity DD `23.25%`; warning reports `0` in every scope.
- Decision: Pass `2012` passed the floating/equity drawdown review under the current `30%` warning threshold. It remains the lead candidate and now has positive evidence across genetic/forward review, fixed EURUSD/XAUUSD transfer, normalized portfolio replay, random execution-noise Monte Carlo, shifted-window robustness, and MT5 equity-drawdown review.
- Live `10K` risk-sizing script added and run: `Files/WeekHighLow/Analyze-OANDA-Pass2012-LiveRiskSizing-20260620.ps1`.
- Live risk-sizing method: Use pass `2012` closed-trade R-multiples from the existing full-period `EURUSD + XAUUSD` trade CSV, replay on a `10,000` starting balance, and compare risk levels `0.25%`, `0.50%`, `0.75%`, and `1.00%`. The benchmark for the `10K` account is `80,000`, matching the rough S&P-style `700%` total-return reference.
- Live risk-sizing output files: `pass2012_live_risk_sizing_baseline_10k.csv`, `pass2012_live_risk_sizing_noise_mc_iterations_10k.csv`, and `pass2012_live_risk_sizing_noise_mc_summary_10k.csv`.
- Live risk-sizing baseline full-period result: `0.25%` risk ended at `27,536.21`, CAGR `3.98%`, max closed DD `6.50%`, max one-trade loss `-92.31`, did not beat `80K`; `0.50%` risk ended at `74,410.14`, CAGR `8.04%`, max closed DD `12.62%`, max one-trade loss `-454.80`, narrowly did not beat `80K`; `0.75%` risk ended at `197,347.17`, CAGR `12.18%`, max closed DD `18.39%`, max one-trade loss `-1,665.12`, beat `80K`; `1.00%` risk ended at `513,743.94`, CAGR `16.40%`, max closed DD `23.81%`, max one-trade loss `-5,416.17`, beat `80K`.
- Live risk-sizing OOS-only `2018 -> 2026` baseline result: `0.25%` risk ended at `11,367.06`, CAGR `2.02%`, max closed DD `5.23%`; `0.50%` ended at `12,882.93`, CAGR `4.04%`, max closed DD `10.25%`; `0.75%` ended at `14,558.15`, CAGR `6.05%`, max closed DD `15.05%`; `1.00%` ended at `16,403.28`, CAGR `8.05%`, max closed DD `19.64%`.
- Live risk-sizing Monte Carlo full-period result: At `0.75%` risk, `BalancedNoise`, `ConservativeNoise`, and `NewsHeavyNoise` all beat the `80K` benchmark in `100%` of iterations. News-heavy median ending balance at `0.75%` was `170,652.70`. At `1.00%` risk, all scenarios also beat the benchmark in `100%` of iterations, with news-heavy median ending balance `423,436.84`.
- Risk-sizing interpretation: `0.50%` is a conservative live start but does not reliably clear the `80K` benchmark in the full-period baseline. `0.75%` is the lowest tested risk that clears the benchmark robustly, including under news-heavy random execution noise. `1.00%` is historically supported and much stronger, but has materially larger closed drawdown and worst-trade loss.
- Decision or next step: For a real `10K` OANDA account, the practical starting range is `0.50% -> 0.75%` risk per trade, with `0.75%` as the benchmark-beating target setting and `1.00%` reserved for a more aggressive profile after live/demo execution behavior is confirmed. Remaining operational work: tiny live/demo forward test and news-event pause policy before real capital deployment.

### 2026-06-21 - Official Name For OANDA Lead Candidate

- Goal: Give the winning OANDA personal-account candidate a stable name for future documentation, presets, logs, and discussions.
- Decision: The official name is `OANDA-EURXAU-P2012`.
- Short spoken name: `OANDA P2012`.
- File-safe prefix: `OANDA_EURXAU_P2012`.
- Source identity: original optimizer pass `2012` from the OANDA EURUSD D1 stop-loss-split genetic run, validated as the same-manifold `EURUSD + XAUUSD` candidate.
- Decision or next step: Use `OANDA-EURXAU-P2012` in future docs when referring to the current lead OANDA personal-account deployment candidate.

### 2026-06-21 - Optimizable High/Low Period Selector

- Goal: Make the high/low period selectable by the MT5 genetic optimizer without relying on raw `ENUM_TIMEFRAMES` values.
- Change: Added `g_HighLowPeriodOptimizationIndex` to the EA and indicator, while preserving fixed `g_HighLowPeriod` behavior when the selector is `-1`.
- Change: Added shared mapping helpers so optimizer index `0 -> 5` resolves to `H4`, `H6`, `H8`, `H12`, `D1`, and `W1`.
- Change: Updated shared period and signal logic to use `g_ActiveHighLowPeriod` instead of reading `g_HighLowPeriod` directly.
- Test setup: Compile verification only; no MT5 optimizer or backtest run was launched.
- Outcome: `WeekHighLowEA.mq5` compiled with `0` errors and `0` warnings. `WeekHighLowIndicator.mq5` compiled with `0` errors and the existing `no indicator plot defined` warning.
- Decision or next step: New genetic discovery presets can use `g_HighLowPeriodOptimizationIndex=4||0||1||5||Y`; existing fixed presets can keep selector `-1` or omit it to preserve fixed-period behavior.

### 2026-06-22 - EURUSD H12-Max Period Optimization Genetic Review

- Goal: Review the latest EURUSD genetic period-optimization run where the highest selectable high/low period was `H12`.
- Source folder: terminal-data `reports/period_opt_h12max_isval_20260621`.
- Source files: `EURUSD_PeriodOpt_H12Max_ISVAL_2000_2018_FWD_20260621.xml`, matching `.forward.xml`, `period_opt_h12max_all_paired_with_period.csv`, `period_opt_h12max_period_summary.csv`, `period_opt_h12max_loose_candidates.csv`, `period_opt_h12max_cross_symbol_shortlist_top25.csv`, and `period_opt_h12max_challenge_profit_shortlist_top50.csv`.
- Test setup: EURUSD, `H1` tester timeframe, genetic optimizer-forward test over `2000.01.01 -> 2018.01.01`, with high/low period selector range `0 -> 3` covering `H4`, `H6`, `H8`, and `H12`.
- Overall outcome: `4,091` optimizer/forward paired rows, `1,485` positive IS+forward pairs, and `82` rows passing the profit/DD screen of positive IS and forward profit, IS and forward ratio `>= 2`, and IS and forward DD `<= 30%`.
- Period summary: `H4` had `777` paired rows, `50` positive pairs, `10` ratio/DD passes, and best combined profit `182,305.69`; `H6` had `614` paired rows, `186` positive pairs, `20` ratio/DD passes, and best combined profit `182,573.12`; `H8` had `591` paired rows, `193` positive pairs, `17` ratio/DD passes, and best combined profit `252,382.34`; `H12` had `2,109` paired rows, `1,056` positive pairs, `35` ratio/DD passes, and best combined profit `723,170.47`.
- Interpretation: `H12` produced the largest and most profitable search space, but the highest raw-profit H12 rows often had weak forward balance or excessive drawdown. The best practical shortlist should not be selected by raw combined profit alone.
- Notable candidate `2866`: `H8`, IS profit `149,147.35`, forward profit `103,234.99`, combined profit `252,382.34`, min ratio `3.659`, total trades `3,485`, IS DD `31.98%`, and forward DD `28.21%`. This is the strongest high-trade candidate, but it slightly exceeds the `30%` IS DD cap.
- Notable candidate `970`: `H12`, IS profit `64,493.19`, forward profit `72,381.38`, combined profit `136,874.57`, min ratio `3.206`, total trades `797`, max DD `22.32%`.
- Notable candidate `2873`: `H12`, IS profit `45,257.91`, forward profit `43,602.46`, combined profit `88,860.37`, min ratio `4.098`, total trades `546`, max DD `11.04%`. This was the best clean ratio candidate with meaningful trade count.
- Notable candidate `3400`: `H12`, IS profit `74,696.23`, forward profit `47,253.58`, combined profit `121,949.81`, min ratio `3.812`, total trades `365`, max DD `19.60%`.
- Notable candidate `2551`: `H12`, IS profit `25,866.55`, forward profit `21,356.82`, combined profit `47,223.37`, min ratio `6.138`, max DD `4.13%`, but only `44` IS trades and `22` forward trades, making it too thin as a primary candidate.
- Decision or next step: Do not promote from optimizer-forward results alone. If continuing this branch, create fixed OOS tests for a small shortlist including `2866`, `970`, `2873`, and `3400`, with optional higher-trade H12 candidates such as `1430` and `2190` tracked despite drawdown warnings.

### 2026-06-23 - OANDA-EURXAU-P2012 FX28 IS+VAL Transfer Test

- Goal: Test whether the current lead OANDA personal-account manifold `OANDA-EURXAU-P2012` transfers across the standard `28` FX-pair universe before considering wider portfolio use or session-filter follow-up.
- Source folder: terminal-data `reports/oanda_pass2012_fx28_isval_20260623`.
- Setup script: `Files/WeekHighLow/Run-OANDA-Pass2012-FX28-IsVal-20260623.ps1`.
- Preset snapshot: `ImpulseContinuation_OANDA_EURXAU_P2012_FX28_ISVAL.set`.
- Test setup: Fixed single-test MT5 reports, optimization disabled, `H1` tester timeframe, P2012 parameters, `g_Risk_Percentage=1.0`, `IS` segment `2000.01.01 -> 2012.01.01`, and `VAL` segment `2012.01.01 -> 2018.01.01`.
- Scope: `28` FX symbols and `2` segments, producing `56` expected tests.
- Run status: `56 / 56` tests completed, `56 / 56` reports parsed, `0` timeouts, and `0` failed reports.
- CSV status: No `manifold_trades_OANDA_EURXAU_P2012_FX28_ISVAL.csv` was found after this run, so the completed batch was report-only and cannot be used for entry-hour filtering without a CSV replay rerun.
- Analysis files created: `oanda_pass2012_fx28_isval_parsed_reports.csv` and `oanda_pass2012_fx28_isval_symbol_summary.csv` in the source folder.
- Acceptance screen used: profit `> 0`, profit/DD ratio `>= 2.0`, and equity DD `<= 30%` per report row.
- Overall result: `56` report rows parsed, `4` rows accepted, `28` complete symbols, only `1` symbol accepted in both `IS + VAL`, only `1` symbol profitable in both `IS + VAL`, only `1` symbol ratio-qualified in both `IS + VAL`, and only `3` symbols under the `30%` DD cap in both periods.
- Only full IS+VAL accepted symbol: `EURUSD`, with IS profit `605,671.94`, IS DD `19.63%`, IS ratio `30.854`, IS trades `731`, VAL profit `66,448.71`, VAL DD `21.46%`, VAL ratio `3.096`, VAL trades `336`, and total profit `672,120.65`.
- Other accepted individual rows: `USDJPY VAL` profit `85,582.91`, DD `22.93%`, ratio `3.732`, trades `311`; `GBPJPY VAL` profit `45,469.63`, DD `17.86%`, ratio `2.546`, trades `319`.
- Notable non-promoted symbols: `USDJPY` had strong validation profit but failed IS with IS profit `-28,728.95`, IS ratio `-0.528`, and max DD `54.46%`; `GBPJPY` had strong validation profit but failed IS with IS profit `-83,508.78`, IS ratio `-0.941`, and max DD `88.79%`; `GBPUSD` had VAL profit `15,434.78` but failed IS and ratio quality; `NZDJPY` had small VAL profit but failed IS and ratio quality.
- Major failures by total profit included `GBPNZD`, `AUDJPY`, `GBPCAD`, `EURCHF`, `AUDNZD`, `EURNZD`, `AUDCAD`, `NZDUSD`, `NZDCAD`, and `GBPAUD`.
- Interpretation: P2012 does not transfer across FX28. It remains an `EURUSD + XAUUSD` personal-account candidate rather than a broad FX manifold.
- Decision or next step: Do not promote P2012 as a general FX strategy. If testing the session-filter hypothesis, rerun a smaller CSV-enabled batch first, likely `USDJPY`, `GBPJPY`, `GBPUSD`, and `NZDJPY`, with `VAL` only as the cheapest first pass before spending time on full IS+VAL CSV replay.

### 2026-06-23 - OANDA-EURXAU-P2012 FX28 Entry-Hour Filter Review

- Goal: Test whether entry-hour filtering can rescue weak FX symbols for the P2012 fixed manifold, using trade CSV rows from the FX28 IS+VAL rerun.
- Source trade CSV: common-files `manifold_trades_OANDA_EURXAU_P2012_FX28_ISVAL.csv`.
- Source report folder: terminal-data `reports/oanda_pass2012_fx28_isval_20260623`.
- CSV-enabled rerun status: Progress log contained a second full completed run for `56 / 56` tests, and the trade CSV was generated successfully.
- CSV health: `50,141` raw CSV rows, `50,141` rows after stable-key dedupe, `25,065` paired closed trades, `11` unmatched entry rows ignored, and `0` unmatched exit rows. Trade rows existed for `27 / 28` FX symbols; `CADCHF` had no trade rows.
- Analysis method: Pair entry and exit rows by `test_id + trade_id`; use the `IN` row hour as trade start hour; keep matching exits for allowed entries; calculate per-symbol/per-segment closed-trade net, profit factor, closed drawdown, return/DD, and an accepted proxy of net `> 0`, return/DD `>= 2.0`, and closed DD `<= 30%`.
- Analysis files created for `08 -> 17`: `oanda_pass2012_fx28_isval_entry_hour_08_17_symbol_segment.csv`, `oanda_pass2012_fx28_isval_entry_hour_08_17_symbol_summary.csv`, and `oanda_pass2012_fx28_isval_entry_hour_stats.csv`.
- `08 -> 17` result: IS profitable rows improved from `1 / 27` to `2 / 27`; VAL profitable rows improved from `8 / 27` to `9 / 27`; IS accepted-proxy rows stayed `1 / 27`; VAL accepted-proxy rows stayed `3 / 27`; symbols profitable in both IS+VAL stayed `1`; symbols accepted in both IS+VAL stayed `1`.
- `08 -> 17` aggregate effect: IS aggregate net improved from `-1,038,845.36` to `-516,419.35`; VAL aggregate net improved from `-641,325.95` to `-198,818.11`; `25` symbols improved total net and `2` worsened. The filter reduced damage but did not rescue broad FX transferability.
- `08 -> 17` notable result: `USDJPY` improved from IS `-28,728.95` and VAL `85,582.91` to filtered IS `-660.95` and filtered VAL `97,833.44`, making it a close but still not profitable-both candidate.
- Analysis files created for `12 -> 17`: `oanda_pass2012_fx28_isval_entry_hour_12_17_symbol_segment.csv` and `oanda_pass2012_fx28_isval_entry_hour_12_17_symbol_summary.csv`.
- `12 -> 17` result: IS profitable rows improved from `1 / 27` to `3 / 27`; VAL profitable rows improved from `8 / 27` to `9 / 27`; symbols profitable in both IS+VAL improved from `1` to `2`; symbols accepted in both IS+VAL stayed `1`.
- `12 -> 17` aggregate effect: IS aggregate net improved from `-1,038,845.36` to `-339,210.59`; VAL aggregate net improved from `-641,325.95` to `-106,442.21`; `25` symbols improved total net and `2` worsened.
- `12 -> 17` accepted symbol: `EURUSD` remained accepted, with filtered IS net `371,472.51`, IS trades `354`, IS PF `1.639`, IS closed DD `26.04%`, IS return/DD `14.268`, filtered VAL net `58,820.35`, VAL trades `152`, VAL PF `1.549`, VAL closed DD `15.77%`, and VAL return/DD `3.731`.
- `12 -> 17` near-miss symbol: `USDJPY` became profitable in both IS+VAL, with filtered IS net `13,242.88`, IS trades `377`, IS PF `1.061`, IS closed DD `22.68%`, IS return/DD `0.584`, filtered VAL net `77,583.15`, VAL trades `149`, VAL PF `1.594`, VAL closed DD `12.67%`, and VAL return/DD `6.123`. It is not accepted because IS return/DD is too weak.
- Other filtered VAL-positive rows under `12 -> 17`: `GBPUSD`, `EURGBP`, `USDCAD`, `GBPCHF`, `AUDUSD`, `CHFJPY`, and `GBPJPY` had positive filtered VAL net, but did not pass both IS+VAL.
- Interpretation: Session filtering is directionally useful and materially reduces losses, but it does not make P2012 a broad FX strategy. The only robust P2012 markets remain `EURUSD` and the previously validated `XAUUSD`; `USDJPY` is a session-filter near miss worth isolated follow-up, not a promoted symbol.
- Decision or next step: Do not promote FX28. If continuing this branch, focus narrowly on `USDJPY` with adjacent windows such as `11 -> 17`, `12 -> 18`, `12 -> 20`, and exclude-only bad-hour tests, then require OOS before considering it alongside `EURUSD + XAUUSD`.
