# Rolling Manifold Experiment Log

This file records experiments, code changes, tests, and observed outcomes for rolling short-horizon manifold research.

Use this log for workflows that optimize on rolling historical windows, select temporary manifolds, and evaluate their limited forward lifespan.

Do not use this file for the older indefinite fixed-manifold research, OANDA personal-account deployment notes, or funded-stage monthly-survival work unless the experiment directly supports rolling-manifold evaluation.

## Format

Each entry should include:

- Date
- Goal
- Change or experiment
- Test setup
- Outcome
- Decision or next step

## Current Requirements Snapshot

- Research branch: Ephemeral Manifold Generator.
- Canonical process file: `ephemeral-manifold-generator.md`.
- Run each symbol independently.
- Generator hyperparameters: IS duration, validation duration, OOS deployment duration, rolling step size, validation survivor count, IS filters, validation filters, thresholds, and ranking algorithm.
- Baseline IS window: rolling `5` years.
- Baseline validation window: next `6` months.
- Baseline step size: `1` month.
- Cross-symbol transfer requirement: none.
- Selection: deterministic scoring over validation survivors, exactly one manifold per symbol per monthly window.
- No-survivor behavior: record `no selection`; do not relax filters after seeing the failed window.
- OOS structure: frozen manifold measured over `OOS-1` days `0-90`, `OOS-2` days `91-180`, `OOS-3` days `181-270`, and `OOS-4` days `271-360`.
- Cumulative OOS horizons: `0-90`, `0-180`, `0-270`, and `0-360` days.
- Portfolio rule: never deploy multiple manifolds on the same symbol in the same deployment period.
- Final score: generator performance across monthly deployment dates, including skipped windows.
- Challenge-stage relationship: intended to support FTMO challenge and verification pass-rate-first account acquisition, then funded-account profitability if manifolds remain useful.
- OOS discipline: do not change the same process version based on OOS results.
- Canonical FTMO requirements file: `ftmo-challenge-requirements.md`.

## Entries

### 2026-07-20 - Research Direction Reset To Ephemeral Generator

- Goal: Stop searching for a forever manifold and define the generator as the product.
- Change or experiment: Added `docs/ephemeral-manifold-generator.md` as the canonical process definition and updated lightweight context docs to treat older EURUSD-discovery plus cross-symbol-promotion tests as historical diagnostics.
- Test setup: Documentation-only change; no MT5 tests run.
- Outcome: Future rolling research should run per symbol with `5`-year IS, `6`-month validation, deterministic selection of one frozen manifold, monthly window advancement, and OOS decay measurement through `360` days.
- Decision or next step: Define the deterministic validation scoring algorithm and fixed IS/validation filters before launching the first full generator run.

### 2026-07-20 - Generator Hyperparameters Defined As Research Target

- Goal: Make the research pipeline itself the object of optimisation, separate from EA parameters.
- Change or experiment: Documented generator hyperparameters including IS duration, validation duration, OOS deployment duration, rolling step size, validation survivor count, candidate ranking algorithm, validation thresholds, IS filters, and validation filters.
- Test setup: Documentation-only change; no MT5 tests run.
- Outcome: The baseline `5y` IS, `6m` validation, and `1m` step are now treated as one process version to compare empirically against alternatives such as `3y` IS or `3m` validation.
- Decision or next step: Define named process versions and compare whole-pipeline performance rather than changing individual settings based on OOS from the same version.

### 2026-07-20 - EURUSD Baseline Overnight Runner Prepared

- Goal: Prepare a restartable overnight run for the active EURUSD ephemeral-generator baseline.
- Change or experiment: Added `Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1` and generated `Files/ThreeDayTrendSignal/tdts_ephemeral_optimizer_current.ini` with `PrepareOnly`.
- Test setup: Symbol `EURUSD`; timeframe `H1`; IS `5` years; validation `6` months; OOS `12` months; primary OOS horizon `3` months; rolling step `1` month; first OOS start `2005.07.01`; last OOS start `2025.05.01`; `239` monthly windows.
- Selection rule: The runner ranks optimizer candidates by IS score, validates the top `25`, ranks all completed validation reports by deterministic validation score, and selects exactly one OOS candidate per window. No validation pass/fail filter can produce zero OOS candidates when validation reports exist.
- OOS structure: Runs `OOS_0_90`, `OOS_91_180`, `OOS_181_270`, `OOS_271_360`, `OOS_0_180`, `OOS_0_270`, and `OOS_0_360` fixed tests for the selected manifold.
- OOS discipline: Unprofitable OOS runs are recorded as failed deployment data and must not stop later rolling windows from running.
- Outcome: PowerShell parser check passed. `PrepareOnly` dry run created `239` windows and did not launch MT5.
- Decision or next step: Start the overnight run with `powershell -ExecutionPolicy Bypass -File .\Files\ThreeDayTrendSignal\Run-TDTS-EURUSD-EphemeralGenerator.ps1`; rerun the same command after any pause or stop to resume.

### 2026-07-20 - TDTS RM 2018 5Y/1Y/1Y First Corrected Cycle

- Goal: Test the Three Day Trend Signal momentum-circle EA under the short-lived rolling-manifold hypothesis instead of the old long-lived fixed-manifold workflow.
- Change or experiment: Updated `Files/ThreeDayTrendSignal/Run-TDTS-WalkForwardRestartable.ps1` so it can run a EURUSD genetic optimizer over a rolling discovery window, select candidates from optimizer-only IS results, validate candidate-symbol pairs over a one-year slice, then run OOS only for pairs that pass both IS and validation.
- Test setup: Experiment `tdts_rm_2018_5y_1y_1y`; discovery symbol `EURUSD`; optimization `2012.01.01 -> 2017.01.01`; validation `2017.01.01 -> 2018.01.01`; OOS/deployment `2018.01.01 -> 2019.01.01`; FX28 symbol universe; `TopN=25`; fixed-balance sizing with `g_StartingBalance=100000.0` and `g_RiskPercentOfBalance=1.0`.
- Outcome: `25` EURUSD optimizer candidates selected, `1400` IS/VAL fixed tests completed, `234` IS/VAL rows accepted, `21` candidate-symbol pairs promoted to OOS, `9` OOS rows were profitable, and `1` OOS row met the acceptance gate.
- Accepted OOS strategy unit: `TDTS_Pass262` on `EURUSD`, with OOS profit `15,178.89`, equity DD `7.28%`, ratio `2.085`, `48` trades, and profit factor `1.45`. Parameters: `g_ATR_Period=49`, `g_ATR_Multiplier=2.5`, `g_ContiguousCandles=1`, `g_StopLossATRMultiple=1.75`, `g_TakeProfitSLMultiple=3.25`.
- `TDTS_Pass262` path: IS profit `114,683.84`, DD `15.20%`, ratio `7.545`, `350` trades; validation profit `30,421.41`, DD `5.82%`, ratio `5.227`, `45` trades; OOS profit `15,178.89`, DD `7.28%`, ratio `2.085`, `48` trades.
- Portfolio-level diagnostic: trading all `21` promoted pairs would have lost `-19,411.34` in aggregate OOS; positive OOS rows summed to `72,278.11`, while negative OOS rows summed to `-91,689.45`.
- Interpretation: The short-lived workflow is not a blanket failure because it found one accepted OOS unit, but the promotion gate is too permissive for trading every promoted pair. The result supports continuing rolling-cycle tests while tightening selection or portfolio construction rules.
- Decision or next step: Run the next cycle as `2013.01.01 -> 2018.01.01` optimization, `2018.01.01 -> 2019.01.01` validation, and `2019.01.01 -> 2020.01.01` OOS. Do not treat the earlier long `2018 -> 2026` TDTS OOS run as the rolling-manifold result; it is only a long-lived-manifold diagnostic.

### 2026-07-14 - RM_2012Q2 Strict Reuse-Optimizer Calibration Result

- Goal: Reuse the completed `RM_2012Q1` EURUSD optimizer result while testing stricter validation rules and a longer validation window.
- Test setup: Cycle `RM_2012Q2_STRICT_REUSE_OPT`; reused optimizer XML from `RM_2012Q1`; optimization window `2007.01.01 -> 2012.01.01`; validation window `2012.01.01 -> 2012.04.01`; intended deployment window `2012.04.01 -> 2012.07.01`; `TopCandidateCount=25`; `MaxCandidatesAfterSanity=10`; stricter default validation requiring EURUSD and at least `2` validation-passing symbols.
- Outcome: The optimizer was not rerun. Optimization-window sanity tests were rerun for the new cycle. `10` candidates survived as `M_sane`. `32` validation tests completed. No final manifold passed validation under the stricter rules, so no deployment test was run.
- Main validation finding: No candidate had EURUSD accepted by the validation criteria. Some EURUSD rows were profitable but below the ratio threshold, for example pass `965` had EURUSD validation profit `4,703.00`, DD `5.80%`, ratio `0.811`, trades `7`; pass `1434` had EURUSD validation profit `4,702.02`, DD `7.05%`, ratio `0.667`, trades `7`; pass `3342` had EURUSD validation profit `879.84`, DD `3.86%`, ratio `0.228`, trades `5`.
- Best accepted non-EURUSD validation row: pass `3342` on `USDJPY`, profit `3,759.02`, DD `1.67%`, ratio `2.251`, trades `5`. It was rejected because EURUSD did not pass and only one symbol passed.
- Interpretation: The stricter rule prevented weak promotion, but the current EURUSD optimizer result did not produce a validation-qualified multi-symbol candidate over `2012.01.01 -> 2012.04.01`.
- Decision or next step: Treat this as another failed calibration cycle, but not a failure of the rolling-manifold concept. Next useful tests are to adjust validation acceptance thresholds, validation length, or candidate-selection/sanity rules before running a larger walk-forward sequence.

### 2026-07-14 - RM_2012Q1 First Rolling Cycle Result

- Goal: Run the first complete rolling short-horizon manifold cycle and inspect whether the optimize -> sanity -> validation -> deploy workflow produces a useful forward deployment.
- Test setup: Cycle `RM_2012Q1`; optimization `2007.01.01 -> 2012.01.01`; validation `2012.01.01 -> 2012.02.01`; deployment `2012.02.01 -> 2012.05.01`; discovery symbol `EURUSD`; default FX28 symbol universe; `TopCandidateCount=25`; `MaxCandidatesAfterSanity=10`; fixed-test timeout `30` minutes.
- Outcome: EURUSD genetic optimization completed, `25` candidates formed `M*`, `700` optimization-window sanity tests completed, `10` candidates survived as `M_sane`, `32` validation tests completed, and `1` deployment test completed with CSV logging enabled.
- Selected manifold under the original permissive rules: `m^ = RM_2012Q1_Pass4030`.
- Selected symbol group under the original permissive rules: `S^ = USDJPY` only.
- `m^` parameters: `g_MinClusterSize=8`, `g_ATR_Cluster_multiplier=0.4`, `g_ATR_StopLoss_multiplier=0.3`, `g_impulse_lookback_hours=120`, `g_pullback_lookforward_hours=24`, `g_Impulse_ATR_multiplier=0.4`, `g_MinPullback_ATR_multiplier=0.6`, `g_TakeProfitMultiplier=2`.
- EURUSD optimizer-period result for `m^`: profit `128,803.66`, equity DD `5.32%`, ratio `24.193`, trades `129`, profit factor `2.46`.
- Optimization-window sanity symbols accepted for `m^`: `EURUSD`, `USDJPY`, `EURJPY`, and `GBPCHF`.
- Validation result for `m^`: only `USDJPY` passed, with profit `4,009.86`, DD `0.59%`, ratio `6.796`, and only `2` trades. `EURUSD` failed validation with profit `-1,005.96` and `1` trade.
- Deployment result for `S^m^`: `USDJPY` deployment profit `-3,029.06`, DD `4.15%`, ratio `-0.73`, trades `3`, accepted `false`.
- Interpretation: The first cycle was too permissive and too thin. A one-symbol, two-trade validation pass should not be promoted, especially when the discovery symbol fails validation.
- Decision or next step: Treat `RM_2012Q1` as a failed diagnostic cycle. Tighten future validation promotion rules to require the discovery symbol to pass validation and require at least `2` validation-passing symbols before deployment. Prefer a longer validation slice than `1` month.

### 2026-07-14 - Validation Promotion Defaults Tightened

- Goal: Prevent weak promotion like `RM_2012Q1`, where only one symbol passed validation and EURUSD failed validation.
- Change or experiment: Updated `Run-RollingManifoldCycle.ps1` so validation requires the discovery symbol by default and requires at least `2` validation-passing symbols by default.
- Change or experiment: Added `-AllowValidationWithoutDiscoverySymbol` as an explicit diagnostic opt-out for cases where EURUSD should not be required in `S^`.
- Test setup: Code and documentation change only; no MT5 tests run.
- Outcome: Future rolling cycles should reject one-symbol, non-EURUSD-only validation survivors by default.
- Decision or next step: Next recommended cycle should use a longer validation slice, such as `2012.01.01 -> 2012.04.01`, followed by deployment `2012.04.01 -> 2012.07.01`.

### 2026-07-14 - Empty Accepted-Row Summary Fix

- Goal: Fix a strict-mode aggregation error after the validation stage completed in `RM_2012Q1`.
- Change or experiment: Replaced `Measure-Object` summary access with explicit helper functions that tolerate empty accepted-row groups.
- Test setup: PowerShell parser check and dry resume using existing `RM_2012Q1` optimizer, sanity, and validation reports with `-SkipOptimizationRun -SkipFixedRuns`.
- Outcome: Parser check passed. The dry resume selected final `m^ = RM_2012Q1_Pass4030`, selected `S^ = USDJPY`, created `1` deployment test, and stopped cleanly because the deployment report was not present yet.
- Decision or next step: Rerun the normal cycle command to execute the deployment test with CSV logging enabled.

### 2026-07-14 - Validation Manifest List Conversion Fix

- Goal: Fix a PowerShell type error after the sanity stage completed in `RM_2012Q1`.
- Change or experiment: Updated `Run-RollingManifoldCycle.ps1` to return and convert generic lists with explicit `.ToArray()` calls, including validation manifest generation.
- Test setup: PowerShell parser check and dry resume using existing `RM_2012Q1` optimizer and sanity reports with `-SkipOptimizationRun -SkipFixedRuns`.
- Outcome: Parser check passed. The dry resume generated `32` validation manifest tests and stopped cleanly because validation reports were not present yet.
- Decision or next step: Rerun the normal cycle command to resume from the completed sanity stage and start validation tests.

### 2026-07-14 - One-Cycle Rolling Manifold Runner Added

- Goal: Create a configurable script that performs one loop of the rolling-manifold algorithm.
- Change or experiment: Added `Files/WeekHighLow/Run-RollingManifoldCycle.ps1`.
- Change or experiment: The script accepts optimization, validation, and deployment date windows; runs or reuses a EURUSD genetic optimizer result; selects `M*`; tests `M*` across the configured symbol universe during the optimization window as a weak sanity filter; carries surviving manifolds into validation; selects final `m^` after validation; selects `S^`; and runs deployment with CSV logging enabled only for `S^m^`.
- Test setup: PowerShell parser validation only; no MT5 tests run.
- Outcome: Parser check passed for the new script. The runner is intended to be restartable: if only part of a fixed-test stage is complete, it stops before report-based selection and can be rerun to resume.
- Decision or next step: Review and tune the default filters before launching a full cycle: `TopCandidateCount`, sanity ratio/DD gates, validation ratio/DD gates, minimum passing-symbol counts, and date-window lengths.

### 2026-07-14 - Rolling Manifold Log Created

- Goal: Split rolling short-horizon manifold experiments into a dedicated log so future sessions do not need to read the large legacy experiment log for current context.
- Change or experiment: Created `docs/rolling-manifold-experiment-log.md` as the canonical log for the new rolling-manifold branch.
- Test setup: Documentation-only change; no MT5 tests run.
- Outcome: Rolling-manifold work now has a focused experiment log separate from `experiment-log.md`, `ftmo-challenge-experiment-log.md`, and `ftmo-funded-experiment-log.md`.
- Decision or next step: Use this file for future rolling-window optimization, validation-slice, deployment-horizon, and stitched walk-forward results.
