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
