# Ephemeral Manifold Generator Research

This is the active research direction as of `2026-07-20`.

## Goal

Stop searching for a forever manifold. Build a repeatable generator that discovers short-lived, symbol-specific profitable manifolds.

The generator is the product. Individual manifolds are disposable outputs.

The research pipeline itself has parameters that must be optimized empirically. These are generator hyperparameters, not EA parameters.

## Core Hypothesis

- Every symbol can have its own temporary behaviours.
- Manifolds are ephemeral and should not be expected to work indefinitely.
- A manifold does not need to work across multiple symbols.
- A manifold only needs to survive long enough to help pass FTMO challenge and verification stages, then support funded-account profitability if it remains useful.
- Robustness should be measured by repeated regeneration across rolling deployment dates, not by indefinite survival of one parameter set.

## Unit Under Test

The unit being tested is the full research pipeline:

```text
Historical Data
    ->
Genetic Optimiser
    ->
IS Filters
    ->
Validation
    ->
Selection Algorithm
    ->
One Selected Manifold
    ->
Rolling OOS Evaluation
```

Do not treat any one selected manifold as the product.

Do not treat the EA parameter set as the product. The EA is the substrate being searched; the generator process is the product being optimized.

## Generator Hyperparameters

Generator hyperparameters include, but are not limited to:

- IS duration, such as `2y`, `3y`, `4y`, `5y`, or `6y`.
- Validation duration, such as `3m`, `6m`, `9m`, or `12m`.
- OOS deployment duration.
- Rolling step size.
- Number of validation survivors.
- Candidate ranking algorithm.
- Validation thresholds.
- IS filtering rules.
- Validation filtering rules.

These must be evaluated as properties of the full research pipeline, not as standalone knobs.

Example hypotheses to test:

- `3y` IS may outperform `5y` IS because older data may no longer represent current market behaviour.
- `3m` validation may outperform `6m` validation because the target is short-lived manifold discovery, not long-term strategy confirmation.
- Shorter deployment horizons may produce higher FTMO pass probability if manifold decay is fast.
- More frequent portfolio regeneration may outperform longer static deployment if transaction costs, compute cost, and operational complexity remain acceptable.

The project should eventually answer empirically:

- What IS duration gives the highest probability of discovering useful short-lived manifolds?
- What validation duration best predicts near-forward profitability?
- How long should a selected manifold remain deployed?
- How often should the portfolio be regenerated?
- How should validation candidates be ranked?
- How many candidates should survive validation before final selection?

## Process Versions

Each tested generator configuration must be treated as a named process version.

For each process version, define before OOS evaluation:

- IS duration.
- Validation duration.
- OOS deployment horizon or decay horizons.
- Rolling step size.
- IS filters.
- Validation filters.
- Candidate ranking algorithm.
- Validation-survivor handling.
- Portfolio construction rule.
- Risk and FTMO replay settings.

OOS results from one process version may be used to design a later process version, but never to retune or reinterpret the same version's already-measured OOS results.

## Per-Symbol Process

Run the process independently for each symbol.

Baseline window lengths for the current process version:

- IS: `36` months.
- VAL: `3` months.
- Step size: `1` month.

These are starting hyperparameters, not settled optimal values.

For each symbol and monthly window:

1. Run MT5 genetic optimisation on the process version's IS period.
2. Apply fixed IS filters.
3. Run surviving candidates on the process version's validation period.
4. Apply fixed validation filters.
5. Rank validation survivors with a deterministic scoring algorithm.
6. Select exactly one manifold from the ranked survivors.
7. Freeze that manifold.
8. Run the OOS period without modifying the manifold.
9. Record all required metrics.
10. Never change the research process based on OOS results.

If no candidate survives validation, record the window as `no selection`. Do not relax filters after seeing the failed window or OOS context.

## Rolling Window

Advance the entire IS, VAL, and OOS structure by the process version's rolling step size.

The baseline step size is `1` month.

Example:

| Run | IS | VAL | OOS starts |
| --- | --- | --- | --- |
| `1` | `Jan2000-Dec2002` | `Jan2003-Mar2003` | `Apr2003` |
| `2` | `Feb2000-Jan2003` | `Feb2003-Apr2003` | `May2003` |

Reason: live trading could begin in any month. Monthly rolling tests measure sensitivity to deployment start date.

## Baseline OOS Structure

The selected manifold remains completely frozen across all OOS slices.

The baseline process version measures the selected manifold over this forward slice:

| Period | Horizon |
| --- | --- |
| `OOS-1` | Months `1-3`, days `0-90` |

Also record cumulative performance for days `0-90`.

Interpretation:

- `OOS-1` is the likely live deployment period.
- The empirical replacement cadence should come from measured forward performance, not from assumptions about how long a manifold should last.

## Required OOS Metrics

Record these for the OOS slice and cumulative horizon:

- Return.
- Max drawdown.
- Profit factor.
- Trade count.
- Win rate.
- Daily loss breaches.
- Whether `+5%` was reached.
- Whether `+10%` was reached.
- Whether `-10%` was reached first.

For FTMO analysis, the path-dependent replay rules in `ftmo-challenge-requirements.md` still apply. Fixed MT5 report profit is not enough.

## Portfolio Rule

Each symbol earns at most one selected manifold per monthly window.

Do not deploy multiple manifolds on the same symbol in the same deployment period.

Diversification comes from different symbols, not from stacking similar parameter sets on one symbol.

Example portfolio construction:

- `EURUSD` -> one selected manifold.
- `GBPUSD` -> one selected manifold.
- `USDJPY` -> one selected manifold.
- `XAUUSD` -> one selected manifold.
- `US500` -> one selected manifold.
- `NAS100` -> one selected manifold.

## OOS Discipline

OOS results are for measurement only.

Do not change filters, scoring, symbols, risk, window lengths, or acceptance rules based on OOS results from the same research process. Any process revision must be defined prospectively as a new version before evaluating its OOS.

An OOS run may be unprofitable. That is recorded as data and must not stop the runner or prevent later rolling windows from executing. The generator process is being evaluated across all deployment dates, including failed OOS deployments.

## Open Implementation Detail

The deterministic scoring algorithm must be fixed before the first full run of this process. It should rank validation survivors only, select one manifold per symbol, and avoid using OOS information directly or indirectly.

## Next Planned Process: Grouped Perturbation Selection

Do not switch to this process until forward-validation selection and trade-frequency handling are reviewed. The prior EMA-filtered `24`-month IS, `48`-month validation, `1`-month OOS, `1`-month step run completed but failed promotion because the old process only validated the top `25` IS candidates; W0001 selected a candidate with roughly `63%` validation DD.

Completed non-perturbation diagnostic before perturbation:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ATRMomentumRelVolEMAFilter\Run-MRV-EURUSD-ForwardValidationGenerator.ps1
```

This run used MT5 optimizer `ForwardMode=1` to produce both IS and VAL candidates under process `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m`, with `24` months IS, `24` months validation, `1` month OOS, and `1` month rolling step. It was intentionally non-perturbation.

Result: net OOS `+7,344.13`, `2 / 4` profitable windows, `1 / 4` zero-trade window, `22` OOS trades, and worst OOS DD `2.74%`. Selected validation DDs were low at `10.36%`, `8.35%`, `9.86%`, and `2.90%`, so the forward-validation approach fixed the obvious high-validation-DD candidate-selection flaw. It is still only an improved diagnostic, not a promoted process, because the sample is tiny, W0004 produced no OOS trades, and `g_RiskPercentOfBalance` was still optimized.

Score-gated reselection update from `2026-08-03`: the forward-validation runner was extended to read MT5 `Back Result` and `Forward Result` columns and then select one OOS candidate after fixed score gates. The tested rules remain diagnostics only because they reuse the same four EURUSD windows.

| Score gate and ranking | Net OOS | Profitable windows | Zero-trade windows | OOS trades | Worst OOS DD |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Back >= 90`, `Forward >= 90`, highest validation trades | `+6,134.56` | `2 / 4` | `1 / 4` | `13` | `1.81%` |
| `Back >= 90`, `Forward >= 90`, highest validation DD | `+5,601.09` | `2 / 4` | `1 / 4` | `10` | `1.81%` |
| `Back >= 90`, `Forward >= 90`, highest validation profit | `+5,184.96` | `2 / 4` | `1 / 4` | `8` | `1.39%` |
| `Back >= 80`, `Forward >= 80`, highest validation profit | `+3,915.11` | `2 / 4` | `0 / 4` | `9` | `1.39%` |
| `Back >= 90`, `Forward >= 90`, lowest validation trades | `+1,399.06` | `2 / 4` | `1 / 4` | `14` | `2.21%` |
| `Back >= 90`, `Forward >= 90`, lowest validation DD | `+1,207.59` | `2 / 4` | `1 / 4` | `13` | `0.71%` |
| `Back >= 90`, `Forward >= 90`, highest validation PF | `-493.73` | `1 / 4` | `1 / 4` | `12` | `3.07%` |

The `80/80` lowest-DD test selected the same candidates as `90/90` lowest-DD. The current lead among score-gated modes is `90/90` highest validation trades. Zero-trade windows are acceptable in principle for a multi-symbol deployment, but portfolio-level trade frequency must be judged across symbols rather than from EURUSD alone.

After forward-validation selection and trade-frequency handling are reviewed, the next planned process should add local parameter-neighborhood robustness before OOS selection. The goal is to avoid promoting optimizer spike candidates that only work at one exact parameter point.

Planned workflow:

1. Run IS genetic optimization as normal.
2. Run fixed validation tests for the selected IS candidates.
3. Keep successful validation candidates according to the prospectively chosen validation rule.
4. Group validation survivors by normalized parameter similarity.
5. Select the medoid of each group, meaning the real candidate with the smallest average distance to other group members.
6. Perturb only each group medoid using fixed single backtests, not MT5 genetic optimization.
7. Score perturbation robustness on validation data only.
8. Select one robust group medoid for OOS.
9. Run OOS once with the selected frozen manifold; OOS remains measurement only.

Perturbation should be implemented as explicit fixed tests with `Optimization=0`. Do not use the genetic optimizer for perturbation because it will search toward the best performers instead of testing the intended local neighborhood.

Initial perturbation rule:

- Use one-parameter-at-a-time `-10%` and `+10%` variants for optimized strategy inputs.
- For small integer inputs, round sensibly and use at least `+/- 1` where a `10%` move would not change the value.
- Do not perturb operational inputs such as magic number, deviation, drawing controls, starting balance, or `g_EnableTrading`.
- Treat risk percentage as a separate risk-sensitivity test, not part of manifold perturbation.
- Enforce valid parameter relationships such as fast EMA remaining below slow EMA.

Initial perturbation pass rule:

- At least `70%` of perturbation variants must be profitable on validation.
- Median perturbation profit must be greater than `0`.
- Median perturbation profit-to-drawdown ratio must be greater than `0`.
- Reject catastrophic variants, initially defined as drawdown greater than `30%` or greater than `1.5x` the medoid's validation drawdown, whichever rule is chosen for that process version.

Initial grouping rule:

- Normalize each optimized parameter by its optimizer search range.
- Use average absolute normalized parameter distance for candidate-to-candidate distance.
- Start with a grouping threshold near `0.10` average normalized distance.
- Prefer groups with at least `2` members, but allow singleton groups when too few validation survivors exist.

Initial group ranking rule:

1. Highest perturbation profitable rate.
2. Highest median perturbation ratio.
3. Highest medoid validation ratio.
4. Highest medoid validation profit.
5. Lowest medoid validation drawdown.
6. Larger group size.

Preferred first grouped-perturbation process version:

- IS: `24` months.
- Validation: `24` months.
- OOS measurement: `3` months.
- Rolling step: `1` month.

Prepared runner for this process:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ATRMomentumRelVolEMAFilter\Run-MRV-EURUSD-ForwardPerturbationGenerator.ps1
```

The runner uses MT5 built-in forward testing for validation by running a `48`-month optimizer range with `ForwardMode=1`, so the first `24` months are IS and the second `24` months are validation. It then applies hard IS/VAL gates, groups validation survivors by normalized parameter distance, perturbs group medoids with fixed `Optimization=0` tests on the validation period, selects a perturbation-robust medoid, and runs a single frozen `3`-month OOS test.

Reasoning: `24` months of IS keeps optimization recent, `24` months of validation is long enough to punish fragile regions without becoming a decade-long stale-regime filter, `3` months of OOS gives the edge more time to express itself than `1` month, and the `1`-month rolling step still tests deployment-date sensitivity.

Comparison process versions worth testing later:

- `24m IS / 12m VAL / 3m OOS / 1m step`.
- `24m IS / 48m VAL / 3m OOS / 1m step`.
- `36m IS / 12m VAL / 3m OOS / 1m step`.
- `36m IS / 24m VAL / 3m OOS / 1m step`.

The `IS -> perturb -> OOS` design should not be the default because perturbing on the same data used for optimization only proves a broad in-sample hill. Validation still provides the separate question: whether the parameter region survives data it was not optimized on.

## Prepared EURUSD Baseline Runner

`Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1` is the prepared restartable runner for the first EURUSD baseline generator process.

Default process version:

- Symbol: `EURUSD`.
- Timeframe: `H1`.
- IS: `36` months.
- Validation: `3` months.
- OOS: `3` months.
- Primary deployment horizon: the full `3` OOS months.
- Alpha-decay diagnostics are disabled for this process version; the runner records one OOS report for the selected manifold.
- Step size: `1` month.
- First OOS start: `2020.07.01`.
- Last OOS start: `2025.05.01`.
- Total windows: `59`.

Validation selection rule:

- The optimizer candidates are ranked by IS score and the top `25` are run through validation by default.
- Validation usually does not apply a pass/fail filter that can select nothing, except for explicitly named abstention modes such as `PositiveLowestTradesHardGates`, `PositiveLowestTradesQualityFloor`, and `PositiveLowestTradesFinalMonth`.
- Every completed validation report is ranked by the selected deterministic validation mode. The default is `Score`; supported modes are `Score`, `Profit`, `Trades`, `LowestTrades`, `PositiveLowestTrades`, `PositiveLowestTradesThenDD`, `PositiveLowestTradesHardGates`, `PositiveLowestTradesQualityFloor`, `PositiveLowestTradesFinalMonth`, `PositiveBestRatio`, `PositiveHighestPF`, `PositiveTradeBand`, `LowestDD`, and `HighestDD`.
- Exactly one candidate is selected for OOS whenever validation reports exist for the window, except abstention modes can record no selection when their fixed gates are not met.
- If all validation candidates lose money, most modes still select the least-bad ranked candidate. This preserves the research rule that the generator must make one deployment decision per window unless the process version explicitly defines abstention gates.

Current reselection finding from the first six EURUSD windows:

- `PositiveLowestTrades` is the current lead mode.
- It requires profitable validation candidates, then selects the lowest validation trade count with deterministic tie-breakers.
- First six OOS windows produced net `+9,214.41`, `3 / 6` profitable windows, worst DD `22.65%`, and `465` trades.
- `PositiveLowestTradesFinalMonth` requires positive 3-month validation and positive final validation month, then selects the lowest validation trade count. It produced net `+7,881.33`, `3 / 6` profitable windows, worst DD `25.62%`, and `493` trades, so it is close but not better than the current lead.
- `PositiveLowestTradesHardGates` with validation profit `> 0`, PF `>= 1.10`, DD `<= 15%`, and trades `>= 40` produced net `+1,223.10`, `2 / 6` profitable windows, worst DD `22.65%`, and `474` trades, so it is not better than the current lead.
- `PositiveLowestTradesQualityFloor` with validation profit `> 0`, ratio `>= 0.50`, and PF `>= 1.10` produced net `-6,558.80`, `2 / 6` profitable windows, worst DD `25.62%`, and `491` trades, so it is worse than the current lead.
- The process is still not robust enough to promote because OOS starts `2020.10.01`, `2020.11.01`, and `2020.12.01` were all negative across the main tested modes. The shared failure pattern suggests the next tests should be process-level hypotheses rather than more simple validation ranking variants.
- Recommended next tests: compare 1-month versus 3-month OOS deployment on the same selected candidates; test an explicit abstention/regime filter; vary validation/deployment window structure; complete and test the missing daily trend filter/final signal logic; or repeat the generator on another symbol to check whether the pattern is EURUSD-specific.

Default run command:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ThreeDayTrendSignal\Run-TDTS-EURUSD-EphemeralGenerator.ps1
```

Restart behavior:

- Rerun the same command to resume.
- Existing optimizer XML files are skipped.
- Existing validation and OOS fixed-test reports are skipped.
- Generated optimizer and validation reports are kept for later reselection experiments.
- To reuse completed IS/VAL work but choose OOS manifolds differently, rerun with `-ValidationSelectionMode Profit`, `-ValidationSelectionMode Trades`, `-ValidationSelectionMode LowestTrades`, `-ValidationSelectionMode PositiveLowestTrades`, `-ValidationSelectionMode PositiveLowestTradesThenDD`, `-ValidationSelectionMode PositiveLowestTradesHardGates`, `-ValidationSelectionMode PositiveLowestTradesQualityFloor`, `-ValidationSelectionMode PositiveLowestTradesFinalMonth`, `-ValidationSelectionMode PositiveBestRatio`, `-ValidationSelectionMode PositiveHighestPF`, `-ValidationSelectionMode PositiveTradeBand`, `-ValidationSelectionMode LowestDD`, or `-ValidationSelectionMode HighestDD`.
- Mode-specific CSV artifacts are written, such as `selected_candidate_Trades.csv`, `validation_results_ranked_Trades.csv`, and `oos_results_Trades.csv`, so alternate selection runs can be compared later. `PositiveTradeBand` artifacts include the band, for example `oos_summary_PositiveTradeBand_60_120.csv`. `PositiveLowestTradesHardGates` artifacts include the gate suffix, for example `oos_summary_PositiveLowestTradesHardGates_PF1_1_DD15_T40.csv`. `PositiveLowestTradesQualityFloor` artifacts include the floor suffix, for example `oos_summary_PositiveLowestTradesQualityFloor_R0_5_PF1_1.csv`. `PositiveLowestTradesFinalMonth` artifacts include the final-month threshold, for example `oos_summary_PositiveLowestTradesFinalMonth_P0.csv`.
- If the run is stopped during an optimizer, that monthly optimizer is rerun because no complete optimizer XML exists.
- If the run is stopped during a fixed test, only the missing report is rerun.
- Unprofitable OOS results are recorded and the runner continues to later windows. OOS profitability is not a stop condition.

Useful throttle options:

- `-MaxWindows 1` limits the session to one monthly window.
- `-MaxFixedTests 10` limits fixed validation/OOS tests in the current session.
- `-StartAtWindow 25` starts scanning from a later monthly window while still respecting existing reports.

Current limitation: the runner records fixed-report metrics such as return, equity drawdown, profit factor, trade count, and win rate. Daily-loss breaches, `+5%` reached, `+10%` reached, and `-10% reached first` require trade-level or equity-path replay and are not solved by fixed MT5 report summaries alone.
