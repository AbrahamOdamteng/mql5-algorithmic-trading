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
- Baseline IS window: rolling `36` months.
- Baseline validation window: next `3` months.
- Baseline step size: `1` month.
- Cross-symbol transfer requirement: none.
- Selection: deterministic scoring over validation survivors, exactly one manifold per symbol per monthly window.
- Current best tested reselection mode for the first `6` EURUSD windows remains `PositiveLowestTrades`: profitable validation candidates only, lowest validation trade count first, deterministic tie-breakers.
- No-survivor behavior: record `no selection`; do not relax filters after seeing the failed window.
- OOS structure: frozen manifold measured once over days `0-90`.
- Cumulative OOS horizon: `0-90` days.
- Portfolio rule: never deploy multiple manifolds on the same symbol in the same deployment period.
- Final score: generator performance across monthly deployment dates, including skipped windows.
- Challenge-stage relationship: intended to support FTMO challenge and verification pass-rate-first account acquisition, then funded-account profitability if manifolds remain useful.
- OOS discipline: do not change the same process version based on OOS results.
- Canonical FTMO requirements file: `ftmo-challenge-requirements.md`.

## Entries

### 2026-08-04 - MRV EMA Forward-Validation Score-Gated Six-Window Extension

- Goal: Extend the completed EURUSD EMA forward-validation diagnostic from four monthly OOS windows to six, while preserving the same non-perturbation `24m IS / 24m VAL / 1m OOS / 1m step` process.
- Change or experiment: Added score-gated forward-selection modes to `Files/ATRMomentumRelVolEMAFilter/Run-MRV-EURUSD-ForwardPerturbationGenerator.ps1` and wrapper defaults in `Run-MRV-EURUSD-ForwardValidationGenerator.ps1`. Important parser fix: MT5 forward spreadsheets expose score columns as `Back Result` and `Forward Result`, not plain `Result`.
- Selection rule under test: `BackForwardScoreThenHighestTrades`, requiring `BackScore >= 90` and `ForwardScore >= 90`, then selecting the candidate with the highest validation trade count. Tie-breakers are validation profit descending, validation DD ascending, forward score descending, back score descending, and pass ascending.
- Test setup: Process ID `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m`; symbol `EURUSD`; timeframe `H1`; MT5 optimizer `ForwardMode=1`; each window uses `24` months IS/back, `24` months forward validation, `1` month OOS, and `1` month step. W0005 OOS was `2025.05.01 -> 2025.06.01`; W0006 OOS was `2025.06.01 -> 2025.07.01`.
- Prior four-window clean result for this same rule: W0001 selected `MRV_EMA_Pass3285` and produced `+5,218.80`, DD `1.81%`, `6` trades; W0002 selected `MRV_EMA_Pass9045` and produced `-402.31`, DD `0.55%`, `4` trades; W0003 selected `MRV_EMA_Pass2532` and produced `+1,318.07`, DD `0.60%`, `3` trades; W0004 selected `MRV_EMA_Pass3569` and produced `0.00`, DD `0.00%`, `0` trades.
- W0005 outcome: No OOS selection. `207` candidates passed normal IS/VAL gates. `99` had `BackScore >= 90`, `6` had `ForwardScore >= 90`, and `0` passed both score gates.
- W0006 outcome: Selected `MRV_EMA_Pass2975` with `BackScore=99.48`, `ForwardScore=98.55`, validation profit `15,372.43`, validation DD `3.45%`, validation ratio `4.455`, and `93` validation trades. OOS result was `+1,518.76`, DD `1.25%`, ratio `1.215`, and `3` trades.
- Clean six-window aggregate: net OOS `+7,653.32`; selected windows `5 / 6`; profitable selected windows `3`; losing selected windows `1`; zero-trade selected windows `1`; no-selection windows `1`; OOS trades `16`; worst OOS DD `1.81%`.
- Window table for the clean six-window `90/90` highest-validation-trades rule:

| Window | OOS period | Status | Pass | Back score | Forward score | Validation trades | OOS profit | OOS DD | OOS trades |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| W0001 | `2025.01.01 -> 2025.02.01` | Selected | `3285` | `98.61` | `94.03` | `190` | `+5,218.80` | `1.81%` | `6` |
| W0002 | `2025.02.01 -> 2025.03.01` | Selected | `9045` | `99.98` | `97.02` | `153` | `-402.31` | `0.55%` | `4` |
| W0003 | `2025.03.01 -> 2025.04.01` | Selected | `2532` | `92.59` | `93.00` | `55` | `+1,318.07` | `0.60%` | `3` |
| W0004 | `2025.04.01 -> 2025.05.01` | Selected | `3569` | `98.20` | `91.33` | `270` | `0.00` | `0.00%` | `0` |
| W0005 | `2025.05.01 -> 2025.06.01` | No selection | - | - | - | - | - | - | - |
| W0006 | `2025.06.01 -> 2025.07.01` | Selected | `2975` | `99.48` | `98.55` | `93` | `+1,518.76` | `1.25%` | `3` |

- Interpretation: The six-window extension improved the score-gated highest-trades diagnostic from net `+6,134.56` over four windows to net `+7,653.32` over six calendar deployment starts. The abstention in W0005 is acceptable in the intended multi-symbol framing, but it shows the `90/90` score gate can be strict. Results are still tiny-sample and EURUSD-only; do not promote without multi-symbol testing, fixed-risk review because `g_RiskPercentOfBalance` remains optimized, and more deployment windows.
- Decision or next step: Treat `90/90` highest validation trades as the current lead MRV EMA forward-selection diagnostic. Next useful work is to test the same process on additional symbols, or to proceed to grouped validation-survivor perturbation after trade-frequency handling and fixed-risk assumptions are reviewed.

### 2026-07-31 - MRV EMA-Filtered Variant Three-Window 2025 Diagnostic

- Goal: Test whether the experimental ATR momentum plus relative-volume EMA-filtered EA can improve the throwaway-manifold generator process without replacing the current TDTS baseline.
- Change or experiment: Created separate EA `Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5` and matching compiled `ATRMomentumRelVolEMAFilterEA.ex5`. The EA preserves ATR momentum plus relative-volume square detection, draws slow EMA in blue and fast EMA in red, gates square-marker trades by current bid/ask plus fast/slow EMA direction, uses the slow EMA from the closed signal candle as stop loss, uses `g_TakeProfitSLMultiple` for TP, and skips trades when slow-EMA stop distance exceeds `ATR * g_MaxStopLossATRMultiple`.
- Change or experiment: Created optimizer preset `Profiles/Tester/ATRMomentumRelVolEMAFilter_WalkForward_Current.set`, tester config `Files/ATRMomentumRelVolEMAFilter/MRV_EMA_EURUSD_Genetic_20260731.ini`, and restartable generator runner `Files/ATRMomentumRelVolEMAFilter/Run-MRV-EURUSD-EphemeralGenerator.ps1`. Existing TDTS EA, presets, and runner were not changed.
- Verification: MetaEditor64 compiled `ATRMomentumRelVolEMAFilterEA.mq5` with `0 errors, 0 warnings`. Visual chart check by user confirmed the EA display looked correct before optimizer runs. `PrepareOnly` confirmed the runner generated the intended 2025 windows and pointed generated configs at `ATRMomentumRelVolEMAFilter\ATRMomentumRelVolEMAFilterEA.ex5`.
- Test setup: Symbol `EURUSD`; timeframe `H1`; process ID `mrv_ema_eg_eurusd_2025_is36m_val3m_oos3m_step1m`; IS `36` months; validation `3` months; OOS `3` months; step `1` month; top `25` optimizer candidates validated per window; one selected manifold per window. Windows: W0001 IS `2021.10.01 -> 2024.10.01`, VAL `2024.10.01 -> 2025.01.01`, OOS `2025.01.01 -> 2025.04.01`; W0002 IS `2021.11.01 -> 2024.11.01`, VAL `2024.11.01 -> 2025.02.01`, OOS `2025.02.01 -> 2025.05.01`; W0003 IS `2021.12.01 -> 2024.12.01`, VAL `2024.12.01 -> 2025.03.01`, OOS `2025.03.01 -> 2025.06.01`.
- Operational note: MT5 optimizer logs were filled with `incorrect input parameters` errors because the genetic optimizer produced invalid EMA combinations where `g_SlowEMALength <= g_FastEMALength`; the EA correctly rejects those combinations with `INIT_PARAMETERS_INCORRECT`, but this wastes optimizer attempts and creates noisy logs.
- Initial selector result: `PositiveLowestTrades` selected W0001 `MRV_EMA_Pass2003`, W0002 `MRV_EMA_Pass4980`, and W0003 `MRV_EMA_Pass1030`. OOS net was `-29,416.24`, `2 / 3` profitable windows, worst DD `37.38%`, and `56` trades. The main failure was W0001: validation selected a `3`-trade profitable candidate that lost `-34,769.00` OOS.
- Selection-mode comparison: `PositiveBestRatio` was the best practical completed mode, with net OOS `+50,327.77`, `3 / 3` profitable windows, worst DD `25.23%`, and `85` trades. Selected passes: W0001 `209`, W0002 `2228`, W0003 `1030`. Window OOS results were `+49,517.90`, `+408.27`, and `+401.60`, so profit was heavily concentrated in W0001 while W0002 and W0003 were barely positive.
- Selection-mode comparison: `HighestDD` had the highest net OOS at `+69,145.13`, but it is not a promotion candidate because it had only `2 / 3` profitable windows, worst DD `68.73%`, and selected W0003 `MRV_EMA_Pass2436` despite negative validation profit. Selected passes: W0001 `1131`, W0002 `2651`, W0003 `2436`.
- Selection-mode comparison: Weak or failed modes included `LowestDD` and `LowestTrades` at net `-21,804.74`, `2 / 3`, worst DD `40.12%`, `49` trades; `PositiveLowestTrades` and `PositiveLowestTradesThenDD` at net `-29,416.24`, `2 / 3`, worst DD `37.38%`, `56` trades; `PositiveLowestTradesQualityFloor_R0_5_PF1_1` at net `-32,834.63`, `2 / 3`, worst DD `55.77%`, `115` trades; `PositiveHighestPF` at net `-34,015.46`, `2 / 3`, worst DD `68.73%`, `131` trades; `Trades` at net `-73,240.04`, `1 / 3`, worst DD `68.24%`, `248` trades; and both `Profit` and `Score` at net `-98,641.29`, `1 / 3`, worst DD `68.73%`, `184` trades.
- Incomplete modes: No top-level summary CSVs were found for `PositiveLowestTradesHardGates`, `PositiveLowestTradesFinalMonth`, or `PositiveTradeBand` in this run folder after the all-mode command. Treat the completed-mode comparison above as the session result unless those modes are rerun and verified later.
- Interpretation: This EMA-filtered variant is very selection-rule sensitive and overfit-prone. The only practical lead, `PositiveBestRatio`, depends almost entirely on one strong OOS window and still has `25.23%` OOS drawdown. Several validation criteria selected candidates with excellent validation metrics that collapsed catastrophically OOS, especially W0001 `Pass1131` and W0002 `Pass2497`.
- Decision or next step: Treat the MRV EMA-filtered EA and current process as a failed diagnostic, not a promotable strategy. Do not continue broad selector tinkering as the next priority. If revisited, materially constrain or simplify the search space first, especially EMA ranges and invalid EMA combinations, and define prospective safety gates before measuring new OOS.

### 2026-07-26 - TDTS RelVol Square-Only EA And Six-Window Reselection Results

- Goal: Bring the MQL5 EA closer to the PineScript by adding relative-volume confirmation and test whether alternate validation-to-OOS selection rules improve the first six EURUSD ephemeral-generator windows.
- Change or experiment: Added relative-volume inputs to `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5`: `g_RelVolLength`, `g_RelVolCandles`, and `g_RelVolThreshold`. Relative volume uses tick volume and same-intraday-slot lookback, matching PineScript structure as closely as practical in MT5.
- Change or experiment: Updated marker behavior: blue circle means bullish ATR momentum only, red circle means bearish ATR momentum only, orange diamond means RelVol only, aqua square means bullish ATR momentum plus RelVol, and purple square means bearish ATR momentum plus RelVol.
- Change or experiment: Changed trade execution so the EA places market orders only from square markers, meaning ATR momentum and RelVol must occur together. Blue/red momentum-only circles and orange RelVol-only diamonds are visual only. Historical markers drawn during `OnInit()` still do not trade.
- Change or experiment: Updated `Profiles/Tester/ThreeDayTrendSignal_EURUSD_Genetic_20260718.set` so RelVol parameters are optimizer-enabled: `g_RelVolLength=20||5||5||50||Y`, `g_RelVolCandles=1||1||1||5||Y`, and `g_RelVolThreshold=1.5||0.5||0.1||3.0||Y`.
- Change or experiment: Updated `Run-TDTS-EURUSD-EphemeralGenerator.ps1` so optimized RelVol parameters are copied into validation and OOS fixed-test `.set` files, and so older manifests missing RelVol columns are tolerated with defaults `20`, `1`, and `1.5`.
- Change or experiment: Added validation reselection modes: `Score`, `Profit`, `Trades`, `LowestTrades`, `PositiveLowestTrades`, `PositiveLowestTradesThenDD`, `PositiveLowestTradesHardGates`, `PositiveLowestTradesQualityFloor`, `PositiveLowestTradesFinalMonth`, `PositiveBestRatio`, `PositiveHighestPF`, `PositiveTradeBand`, `LowestDD`, and `HighestDD`. Reruns keep generated optimizer/validation reports and write mode-specific CSV artifacts; `PositiveTradeBand` artifacts include the band suffix, for example `PositiveTradeBand_60_120`, `PositiveLowestTradesHardGates` artifacts include the gate suffix, for example `PositiveLowestTradesHardGates_PF1_1_DD15_T40`, `PositiveLowestTradesQualityFloor` artifacts include the floor suffix, for example `PositiveLowestTradesQualityFloor_R0_5_PF1_1`, and `PositiveLowestTradesFinalMonth` artifacts include the final-month threshold, for example `PositiveLowestTradesFinalMonth_P0`.
- Test setup: Symbol `EURUSD`; timeframe `H1`; process ID `tdts_eg_eurusd_2017_is36m_val3m_oos3m_step1m`; `36` months IS, `3` months validation, `3` months OOS, `1` month step; first six OOS starts `2020.07.01` through `2020.12.01`; top `25` IS candidates validated per window; one selected OOS manifold per window.
- Verification: MetaEditor compiled `ThreeDayTrendSignalEA.mq5` with `0 errors, 0 warnings` after RelVol and square-only trade changes. PowerShell `PrepareOnly` checks passed for new runner modes.
- Outcome: The first six-window baseline was negative for the original `Score` mode and most simple modes. The consistently weak region was OOS windows starting `2020.10.01`, `2020.11.01`, and `2020.12.01`.
- Selection-mode comparison: `Score` had `2 / 6` profitable windows, net OOS `-50,043.11`, worst DD `35.55%`, `614` trades. `Trades` had `3 / 6`, net `-21,527.08`, worst DD `50.19%`, `1,052` trades. `Profit` had `3 / 6`, net `-37,516.09`, worst DD `50.19%`, `761` trades. `LowestDD` had `1 / 6`, net `-62,487.57`, worst DD `35.22%`, `653` trades. `HighestDD` had `2 / 6`, net `-19,481.66`, worst DD `50.19%`, `822` trades. `LowestTrades` had `2 / 6`, net `-8,257.98`, worst DD `22.65%`, `397` trades. `PositiveLowestTrades` had `3 / 6`, net `9,214.41`, worst DD `22.65%`, `465` trades. `PositiveLowestTradesThenDD` had `3 / 6`, net `7,636.04`, worst DD `22.65%`, `467` trades. `PositiveBestRatio` had `1 / 6`, net `-63,224.19`, worst DD `35.55%`, `663` trades. `PositiveHighestPF` had `3 / 6`, net `-26,275.75`, worst DD `30.15%`, `629` trades. `PositiveTradeBand` with `60-120` validation trades had `2 / 6`, net `-17,980.39`, worst DD `25.62%`, `579` trades.
- Current best mode: `PositiveLowestTrades`. Window OOS results were W0001 `+19,244.30`, W0002 `+12,425.36`, W0003 `+13,866.84`, W0004 `-12,055.36`, W0005 `-14,141.12`, and W0006 `-10,125.61`, for net `+9,214.41`.
- Additional selection-mode comparison: `PositiveLowestTradesFinalMonth`, requiring positive 3-month validation and positive final validation month, selected W0001 `TDTS_Pass3202`, W0002 `TDTS_Pass2954`, W0003 `TDTS_Pass2703`, W0004 `TDTS_Pass3346`, W0005 `TDTS_Pass3133`, and W0006 `TDTS_Pass2865`. OOS results were W0001 `+19,244.30`, W0002 `+12,425.36`, W0003 `+13,866.84`, W0004 `-12,055.36`, W0005 `-14,141.12`, and W0006 `-11,458.69`, for net `+7,881.33`, `3 / 6` profitable windows, worst DD `25.62%`, and `493` trades. This needed `120` final-month validation fixed tests and no additional OOS tests.
- Additional selection-mode comparison: `PositiveLowestTradesHardGates`, using validation profit `> 0`, PF `>= 1.10`, DD `<= 15%`, and trades `>= 40`, selected W0001 `TDTS_Pass3202`, W0002 `TDTS_Pass2954`, W0003 `TDTS_Pass2736`, W0004 `TDTS_Pass3346`, W0005 `TDTS_Pass3133`, and W0006 `TDTS_Pass1983`. OOS results were W0001 `+19,244.30`, W0002 `+12,425.36`, W0003 `-573.29`, W0004 `-12,055.36`, W0005 `-14,141.12`, and W0006 `-3,676.79`, for net `+1,223.10`, `2 / 6` profitable windows, worst DD `22.65%`, and `474` trades. One missing W0006 OOS fixed test was run to complete this comparison.
- Additional selection-mode comparison: `PositiveLowestTradesQualityFloor`, using validation profit `> 0`, ratio `>= 0.50`, and PF `>= 1.10`, selected W0001 `TDTS_Pass3202`, W0002 `TDTS_Pass2954`, W0003 `TDTS_Pass2736`, W0004 `TDTS_Pass3346`, W0005 `TDTS_Pass3133`, and W0006 `TDTS_Pass2865`. OOS results were W0001 `+19,244.30`, W0002 `+12,425.36`, W0003 `-573.29`, W0004 `-12,055.36`, W0005 `-14,141.12`, and W0006 `-11,458.69`, for net `-6,558.80`, `2 / 6` profitable windows, worst DD `25.62%`, and `491` trades. No MT5 fixed tests were needed because all selected OOS reports already existed.
- Interpretation: Requiring positive validation profit and selecting the lowest-trade candidate materially improved robustness and contained drawdown relative to other tested modes. However, even the best mode still failed the final three overlapping OOS windows, so the process is not yet robust enough to promote. The repeated late-window failure suggests a regime issue or that the `3`-month validation selection does not predict the next `3` months reliably in that period.
- Session-end interpretation: The simple selection variants have the same practical outcome pattern: W0001-W0002 are good, W0003 is usually good or near flat, and W0004-W0006 are weak. The exact selector changes matter less than the shared failure cluster. Next useful tests should move to process-level hypotheses: 1-month OOS deployment versus 3-month OOS, explicit abstention/regime filters, different validation/deployment windows, completing the daily trend/final signal logic in the EA, or testing another symbol to see if this is EURUSD-specific.
- Decision or next step: Treat `PositiveLowestTrades` as the current lead validation-to-OOS selection rule for this process version, but stop prioritizing more simple selection-filter variants. Next useful tests should be process-level: compare 1-month versus 3-month OOS deployment, test explicit abstention/regime filters, change validation/deployment window structure, complete the daily trend/final signal implementation, or run the generator on another symbol. Do not discard existing reports; they are needed for deployment-horizon and reselection diagnostics without rerunning IS/VAL.

### 2026-07-25 - Validation Reselection Modes Added

- Goal: Preserve generated optimizer and validation reports so alternate VAL-to-OOS selection criteria can be tested later without rerunning completed IS/VAL work.
- Change or experiment: Added `-ValidationSelectionMode` to `Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1`, initially supporting `Score`, `Profit`, `Trades`, `LowestTrades`, `PositiveLowestTrades`, `PositiveLowestTradesThenDD`, `PositiveBestRatio`, `PositiveHighestPF`, `PositiveTradeBand`, `LowestDD`, and `HighestDD`. Later work added `PositiveLowestTradesHardGates`.
- Test setup: Ran `PrepareOnly` with `-ValidationSelectionMode Trades`; no MT5 optimizer or fixed tests run.
- Outcome: The runner parsed successfully and generated the current optimizer config while reporting the selected validation mode. Mode-specific CSV artifacts are written for selection and OOS results so alternate reruns can be compared.
- Decision or next step: After a baseline run completes, rerun with a different `-ValidationSelectionMode` to reuse existing optimizer and validation reports and test a different selected OOS manifold.

### 2026-07-25 - EURUSD Generator Window Lengths Shortened

- Goal: Revise the active EURUSD ephemeral-generator process to use shorter discovery, validation, and deployment windows.
- Change or experiment: Updated `Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1` defaults to `36` months IS, `3` months validation, and a single `3` months OOS report, with the process ID `tdts_eg_eurusd_2017_is36m_val3m_oos3m_step1m`.
- Test setup: Documentation and runner preparation only; no MT5 optimizer or fixed tests run.
- Outcome: `PrepareOnly` generated the first optimizer config for `2017.04.01 -> 2020.04.01` and confirmed `59` monthly windows from `2020.07.01 -> 2025.05.01`.
- Decision or next step: Run the active EURUSD generator with the normal runner command when ready; rerun the same command to resume from generated reports.

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
- Test setup: Symbol `EURUSD`; timeframe `H1`; IS `5` years; validation `6` months; OOS `12` months; primary OOS horizon `3` months; rolling step `1` month; first OOS start `2020.07.01`; last OOS start `2025.05.01`; `59` monthly windows. The first IS window is `2015.01.01 -> 2020.01.01`.
- Selection rule: The runner ranks optimizer candidates by IS score, validates the top `25`, ranks all completed validation reports by deterministic validation score, and selects exactly one OOS candidate per window. No validation pass/fail filter can produce zero OOS candidates when validation reports exist.
- OOS structure: Runs `OOS_0_90`, `OOS_91_180`, `OOS_181_270`, `OOS_271_360`, `OOS_0_180`, `OOS_0_270`, and `OOS_0_360` fixed tests for the selected manifold.
- OOS discipline: Unprofitable OOS runs are recorded as failed deployment data and must not stop later rolling windows from running.
- Outcome: PowerShell parser check passed. `PrepareOnly` dry run created `59` windows and did not launch MT5.
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
