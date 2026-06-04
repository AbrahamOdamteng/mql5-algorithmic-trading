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
