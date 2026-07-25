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

## Prepared EURUSD Baseline Runner

`Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1` is the prepared restartable runner for the first EURUSD baseline generator process.

Default process version:

- Symbol: `EURUSD`.
- Timeframe: `H1`.
- IS: `36` months.
- Validation: `3` months.
- OOS: `3` months.
- Primary deployment horizon: first `3` OOS months.
- Alpha-decay diagnostics beyond the first `3` OOS months are disabled for this process version.
- Step size: `1` month.
- First OOS start: `2020.07.01`.
- Last OOS start: `2025.05.01`.
- Total windows: `59`.

Validation selection rule:

- The optimizer candidates are ranked by IS score and the top `25` are run through validation by default.
- Validation does not apply a pass/fail filter that can select nothing.
- Every completed validation report is ranked by deterministic validation score.
- Exactly one candidate is selected for OOS whenever validation reports exist for the window.
- If all validation candidates lose money, the least-bad ranked candidate is still selected. This preserves the research rule that the generator must make one deployment decision per window.

Default run command:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ThreeDayTrendSignal\Run-TDTS-EURUSD-EphemeralGenerator.ps1
```

Restart behavior:

- Rerun the same command to resume.
- Existing optimizer XML files are skipped.
- Existing validation and OOS fixed-test reports are skipped.
- If the run is stopped during an optimizer, that monthly optimizer is rerun because no complete optimizer XML exists.
- If the run is stopped during a fixed test, only the missing report is rerun.
- Unprofitable OOS results are recorded and the runner continues to later windows. OOS profitability is not a stop condition.

Useful throttle options:

- `-MaxWindows 1` limits the session to one monthly window.
- `-MaxFixedTests 10` limits fixed validation/OOS tests in the current session.
- `-StartAtWindow 25` starts scanning from a later monthly window while still respecting existing reports.

Current limitation: the runner records fixed-report metrics such as return, equity drawdown, profit factor, trade count, and win rate. Daily-loss breaches, `+5%` reached, `+10%` reached, and `-10% reached first` require trade-level or equity-path replay and are not solved by fixed MT5 report summaries alone.
