# Rolling Manifold Experiment Log

This file records experiments, code changes, tests, and observed outcomes for the rolling short-horizon manifold research branch.

Use this log for workflows that optimize on rolling historical windows, select temporary manifolds, validate them across non-EURUSD symbols, and deploy them only for limited forward horizons such as `N` weeks or `N` closed trades.

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

- Research branch: rolling short-horizon manifold rotation
- Discovery symbol: `EURUSD`
- Initial discovery window: rolling `5` years
- Candidate source: top `X` EURUSD genetic manifolds, using quality filters rather than raw profit alone
- Discovery-window cross-symbol role: weak non-EURUSD sanity filter only
- Validation-window cross-symbol role: real promotion gate
- Deployment horizon: unresolved; test `N` weeks, `N` closed trades, and hybrid limits
- Final score: stitched walk-forward sequence, including skipped windows where no manifold qualifies
- Challenge-stage relationship: intended to support FTMO pass-rate-first account-acquisition research
- Canonical requirements file: `ftmo-challenge-requirements.md`

## Entries

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
