# MQL5 Strategy Project Notes

This directory captures working knowledge for the active MQL5 strategy work and the legacy WeekHighLow research so future sessions can quickly recover project context.

## Current Direction

As of `2026-07-15`, the day/week high-low strategy is abandoned for new development.

The active strategy implementation is the Three Day Trend Signal strategy, originally coded as a PineScript indicator:

```text
C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\Common\Files\3 Day Trend Signal with ATR Candle Filter.txt
```

The MQL5 implementation should be built incrementally in `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5`. Momentum-circle market order execution has been added for genetic testing.

Current implementation state:

- ATR momentum candle markers are implemented.
- Relative volume markers are implemented using tick volume.
- The three-day trend filter is not implemented yet.
- Final long/short signal triangles are not implemented yet.
- Optional market order placement is implemented for newly drawn ATR momentum markers for genetic testing.
- Trade sizing uses fixed starting-balance risk, defaulting to `g_StartingBalance=100000.0` and `g_RiskPercentOfBalance=1.0`, rather than fixed lots.

See `three-day-trend-signal.md` for the active strategy details.

The active research direction is now the Ephemeral Manifold Generator. The goal is no longer to find a forever manifold. The goal is to build and empirically optimize a repeatable per-symbol pipeline that discovers short-lived manifolds. Baseline hyperparameters are rolling `36`-month IS, `3`-month validation, deterministic selection of exactly one frozen manifold, and OOS measurement over a `3`-month horizon. These are generator hyperparameters to test, not settled optimal values. See `ephemeral-manifold-generator.md`.

## Primary Files

- `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5`: Active EA for the new strategy. It currently draws ATR momentum and relative-volume markers, and can place risk-sized market orders from newly drawn momentum markers.
- `docs/three-day-trend-signal.md`: Active strategy notes and implementation sequence.

Legacy WeekHighLow files, retained for reference unless explicitly revisited:

- `Experts/WeekHighLow/WeekHighLowEA.mq5`: Expert Advisor that warms up historical bars, detects signals on new closed bars, and places pending orders.
- `Indicators/WeekHighLow/WeekHighLowIndicator.mq5`: Chart indicator that draws levels and signal markers.
- `Include/WeekHighLows/`: Shared data structures, period detection, level detection, signal logic, circular buffers, and drawing helpers.
- `Experts/WeekHighLow/EA_Utils.mqh`: EA order placement, lot sizing, comments, and strategy helper functions.
- `Experts/WeekHighLow/TradeLogger.mqh`: CSV trade logging support, currently compiled in but inactive from the EA.

## Legacy WeekHighLow Strategy Intent

The notes below describe the abandoned WeekHighLow strategy and historical research context. Do not treat them as the default current work.

The project appears to track previous period highs and lows, measure impulse and pullback behavior around those levels, detect continuation-style setups, and place pending breakout orders around the detected level.

The current code creates levels from the active high/low period. By default this is `PERIOD_D1`, but `g_HighLowPeriodOptimizationIndex` can make the genetic optimizer choose among `H4`, `H6`, `H8`, `H12`, `D1`, and `W1`.

High/low period selector mapping:

| `g_HighLowPeriodOptimizationIndex` | Active period |
| ---: | --- |
| `-1` | Use fixed `g_HighLowPeriod` |
| `0` | `PERIOD_H4` |
| `1` | `PERIOD_H6` |
| `2` | `PERIOD_H8` |
| `3` | `PERIOD_H12` |
| `4` | `PERIOD_D1` |
| `5` | `PERIOD_W1` |

## Legacy FTMO/OANDA Research Context

The practical goal is to develop an EA configuration that can help pass an FTMO-style challenge.

Goal realignment set on `2026-06-14`: the project now separates FTMO evaluation mode from funded-account mode. The evaluation/challenge strategy does not need to be the same as the funded strategy.

Evaluation mode is an account-acquisition engine. As of `2026-06-21`, challenge strategy search should optimize single-stage pass rate first, not fastest pass speed. The current hard promotion gate is `>= 75%` single-stage pass rate, with `>= 85%` preferred. Speed remains a secondary sanity check, consistency-rule diagnostics should be reported, and both trading days and calendar days should be included.

Funded mode is a capital-preservation and extraction engine. After funded status, the target is not another fast `+10%` first-passage objective. The intended funded-account goal is lower-risk survival and steady extraction of roughly `1% -> 3%` monthly, eventually scaled across additional accounts toward about `1,000,000` in funded capital.

This goal realignment does not delete the older robustness goals. The fixed-manifold and symbol-specific behavior-cluster workflows remain useful, but their outputs should be evaluated separately for challenge mode and funded mode.

The intended deployment is multi-symbol: a single parameter manifold should eventually be tested across multiple symbols and symbol types, including FX, metals, and indices. If the same manifold performs acceptably across a diverse subset of markets, that is treated as stronger evidence of robustness than a single-symbol result.

New research extension: a symbol-specific behavior-cluster workflow is also being considered. Instead of requiring one global manifold to work across all symbols, each symbol may earn inclusion by showing multiple distinct profitable behavior clusters. A live portfolio would then be built from `symbol + behavior cluster` strategy units, with one random or median representative chosen from each accepted cluster. This is documented in `behavior-clusters.md` and does not delete or replace the older fixed-manifold workflow.

Current rolling research direction: the project should test whether a per-symbol generator can repeatedly discover short-lived profitable manifolds. There is no cross-symbol transfer requirement. Each symbol is optimized, validated, selected, frozen, and evaluated independently. Each monthly window selects at most one manifold per symbol; diversification comes from symbols, not multiple manifolds on one symbol. The generator and selection process are the product, not any one selected manifold.

For future assistant sessions, start with `session-start.md` instead of reading every markdown file. It lists the current lightweight context files and identifies large historical files that should only be read with targeted searches.

## Current OANDA Personal-Account Plan

As of `2026-06-20`, the OANDA personal-account track produced the lead candidate below. As of `2026-06-21`, FTMO challenge requirements are active again as a separate pass-rate-first research track. The OANDA plan remains useful for personal-account deployment but should not constrain FTMO challenge strategy generation.

The OANDA sub-goal is a personal account starting around `10,000`, trading `EURUSD` and `XAUUSD` with the same fixed manifold, and attempting to outperform a rough S&P500-style benchmark of `10,000 -> 80,000` over a long horizon.

Current lead candidate:

- Official name: `OANDA-EURXAU-P2012`.
- Short name: `OANDA P2012`.
- File-safe prefix: `OANDA_EURXAU_P2012`.
- Source identity: `Pass 2012` from the OANDA EURUSD D1 stop-loss-split genetic run in `reports/oanda_eurusd_xauusd_same_manifold_20260619`.
- Fixed parameters are preserved in `Profiles/Tester/ImpulseContinuation_OANDA_SameManifold_Pass2012.set` and copied into the experiment report folder.
- Evidence so far: passed EURUSD/XAUUSD fixed transfer tests, normalized portfolio replay, random execution-noise Monte Carlo, shifted-window validation, and MT5 floating/equity drawdown review.
- Practical risk-sizing result for a `10,000` account: `0.50%` is a conservative live start, `0.75%` is the lowest tested risk that robustly clears the `80,000` full-period benchmark, and `1.00%` is aggressive but historically supported after live/demo execution behavior is confirmed.

Remaining live-readiness plan:

- Run a tiny live or demo forward test on OANDA using `OANDA-EURXAU-P2012` and both `EURUSD` and `XAUUSD`.
- Confirm pending-order fills, spread behavior, lot sizing, margin use, symbol properties, and CSV logging outside the tester.
- Create final deployment presets for `EURUSD` and `XAUUSD`, including selected `g_Risk_Percentage`, CSV identity fields, and any live-only inputs.
- Check minimum-lot and lot-step feasibility on a `10,000` account, especially for `XAUUSD`, so requested percentage risk is actually achievable.
- Decide a news-event pause policy for NFP, CPI, FOMC, and major rate decisions before risking meaningful live capital.
- Review and ideally implement duplicate pending-order / existing-position guards before real deployment, because the current EA can otherwise stack repeated exposure from the same signal.

Operational status: these remaining items are deployment safety checks, not new strategy discovery. Do not start new broad optimizations for this OANDA track unless `OANDA-EURXAU-P2012` fails live/demo execution validation or a specific new hypothesis is defined.

Current per-symbol generator workflow:

- Run each symbol independently.
- Use the process version's IS optimization window.
- Apply fixed IS filters.
- Validate survivors on the process version's validation window.
- Apply fixed validation filters.
- Rank validation survivors with a deterministic scoring algorithm.
- Select exactly one frozen manifold per symbol per monthly window.
- Evaluate OOS decay over the process version's deployment/decay horizons without modifying the manifold.
- Score the generator process across monthly deployment dates, including `no selection` windows.

Low trade count remains a risk, but the trade-count rule must be part of the fixed IS filters, fixed validation filters, or deterministic scoring algorithm before OOS is measured.

Current main uncertainty: whether a fixed generator process can repeatedly select short-lived symbol-specific manifolds that survive long enough to pass FTMO challenge and verification stages without becoming optimizer noise chasing.

Validation safeguards for the generator:

- Require filters and scoring to be fixed before OOS measurement.
- Record skipped windows where no candidate survives validation.
- Check whether portfolio performance is spread across symbols instead of dominated by one symbol.
- Check whether one selected manifold contributes too much of aggregate return or drawdown in a deployment month.
- Treat enough aggregate trades as necessary but not sufficient; trades must also be distributed across symbols and deployment windows.
- Do not treat full-period OOS report profitability as equivalent to FTMO challenge passability. Challenge mode must be judged with rolling first-passage analysis: target before daily/global breach and within the desired time window.
- For funded mode, judge monthly return distribution, payout survival, and breach probability over `3`, `6`, and `12` months. Full-period OOS profit alone is not enough.
- Stress promising generator versions with cost/spread assumptions, trade-skip or Monte Carlo tests, and shifted windows before treating them as robust.

## Legacy Fixed-Manifold Test Plan

The fixed `2000 -> 2012`, `2012 -> 2018`, and `2018 -> 2026` split below belongs to the older fixed-manifold workflow. The active generator workflow uses rolling monthly `36`-month IS, `3`-month validation, and `3`-month OOS horizons.

- `2000 -> 2012`: In-sample period, tested by the MT5 optimizer.
- `2012 -> 2018`: Validation period, tested by MT5 optimizer forward testing.
- `2018 -> 2026`: Out-of-sample period, tested by a separate MT5 backtest.

Operational rule: Do not launch MT5 optimizer or backtest runs from an assistant session unless the user explicitly asks for that run. The user controls when tests are run because MT5 availability and test duration need to be planned. The assistant may prepare code, presets, `.ini` files, parsing commands, and analysis.

Current phase-1 multi-symbol validation basket:

- `EURUSD`
- `GBPUSD`
- `USDJPY`
- `EURJPY`
- `XAUUSD`
- `XAGUSD`
- `US500`
- `US30`
- `US100`
- `UK100`
- `USOIL`
- `UKOIL`

The basket includes FX, metals, US indices, a non-US equity index, and energy. These symbols should be used for fixed-manifold validation and portfolio/FTMO-style review, not for discovering or tuning parameters unless explicitly starting a new research phase.

Effective first trade/order dates from the `2000.01.01 -> 2012.01.01` start-date probe using fixed `RUN2` pass `5456`:

| Symbol | First trade/order in probe | Availability handling |
| --- | --- | --- |
| `USDJPY` | `2000.01.03 15:00:00` | Full standard IS usable |
| `GBPUSD` | `2000.01.14 16:00:00` | Full standard IS usable |
| `EURUSD` | `2000.01.19 11:00:00` | Full standard IS usable |
| `EURJPY` | `2000.01.25 07:00:00` | Full standard IS usable |
| `US30` | `2005.01.27 22:00:00` | Partial-history IS |
| `USOIL` | `2005.01.27 21:00:00` | Partial-history IS |
| `US500` | `2005.01.31 02:04:30` | Partial-history IS |
| `UKOIL` | `2005.04.19 20:00:00` | Partial-history IS |
| `XAUUSD` | `2006.04.13 17:00:00` | Partial-history IS |
| `XAGUSD` | `2006.04.28 17:00:00` | Partial-history IS |
| `UK100` | `2008.06.03 21:00:00` | Partial-history IS |
| `US100` | `2014.10.07 15:00:00` in `2000 -> 2020` probe | Validation/OOS only from available history |

These probe dates are first EA trade/order events for one fixed manifold, not guaranteed broker first-bar timestamps. They are sufficient for deciding whether a symbol should be treated as full-history or partial-history in this strategy workflow.

`US100` has a special history-availability exemption. It should not be used as a base optimization symbol and should not be penalized for missing the full `2000 -> 2012` in-sample window. The `2000 -> 2020` probe produced first trade/order activity at `2014.10.07 15:00:00`. For fixed-manifold validation, skip `US100` in-sample, use validation from available history around `2014.09.15 -> 2018.01.01`, and use normal OOS testing from `2018.01.01 -> 2026.05.31`.

Legacy backtest acceptance criteria:

- In-sample profit must be greater than `0`.
- Validation profit must be greater than `0`.
- Out-of-sample profit must be greater than `0`.
- Equity drawdown must be less than `20%` in every test period.

Legacy ratio-based review criteria:

- Profit must be greater than `0` in every period.
- Profit-to-drawdown ratio should be greater than `2.0` in every period.
- Raw equity drawdown should remain capped, currently using `30%` as a diagnostic cap.
- Trade count was evaluated at the subset/portfolio level. For the active generator, trade-count handling must be fixed in IS filters, validation filters, or deterministic scoring before OOS is measured.

Legacy pre-CSV expanded-basket elimination filters:

- These were frozen for the earlier full fixed-manifold expanded-basket workflow and do not define the active generator process.
- Apply these only after the full fixed-manifold basket reports are generated, before spending time on trade CSV generation and FTMO rolling-challenge analysis.
- Eliminate a manifold if any required report is missing or unparseable. `US100` IS is exempt because `US100` is validation/OOS-only.
- Eliminate a manifold if total trades across all tested symbols and periods are `< 1500`.
- Eliminate a manifold if validation plus OOS trades are `< 1000`.
- Eliminate a manifold if OOS trades are `< 500`.
- Eliminate a manifold if aggregate validation profit is `<= 0` or aggregate OOS profit is `<= 0`.
- Eliminate a manifold if aggregate validation profit/DD ratio is `< 1.5` or aggregate OOS profit/DD ratio is `< 1.5`.
- Eliminate a manifold if any single symbol/period has equity DD `> 60%`.
- Eliminate a manifold if fewer than `7 / 12` basket symbols are profitable in OOS.
- Eliminate a manifold if OOS is negative in more than one whole market group: FX, metals, indices, or energy.
- Eliminate a manifold if one symbol contributes more than `50%` of aggregate OOS profit, or one market group contributes more than `70%` of aggregate OOS profit.
- Eliminate a manifold if any single-symbol OOS loss consumes more than `30%` of aggregate OOS profit.
- Eliminate a manifold if aggregate OOS profit/DD ratio is less than `40%` of aggregate validation profit/DD ratio.
- These filters are broad screening gates, not the final ranking criteria. Final ranking should come from trade CSV FTMO survivability analysis using pass rate first and pass time second.

FTMO-first evaluation plan:

- Treat fixed MT5 reports as candidate discovery and stress-test artifacts, not as the final FTMO decision tool.
- The primary FTMO question is path-dependent: does a rolling simulated account reach `+10%` before `-10%`, while respecting the daily loss rule.
- Full-period report drawdown can reject a strategy that would have passed an FTMO-style challenge before a later drawdown occurred, so report-level DD should remain a sanity check rather than the final ranking metric.
- As of `2026-06-21`, rank challenge-mode candidates by single-stage pass rate first, not fastest pass speed. Use `>= 75%` as the hard promotion gate and `>= 85%` as the preferred threshold.
- Because challenge mode is allowed to be an account-acquisition engine, also estimate expected challenge-fee cost per pass, losing-streak risk over `10` attempts, daily/global breach frequency, unresolved starts, and consistency-rule warnings.
- Evaluate funded mode separately at lower risk, targeting `1% -> 3%` monthly with low breach probability and payout survival.
- Modify the CSV trade logger to write enough identity metadata to analyze each manifold independently: `manifold_id`, `test_id`, existing symbol/deal/trade fields, timestamps, P/L, and risk percentage.
- Write one CSV per manifold, appending rows as symbol/segment tests complete. Analysis should sort by `deal_time`, so MT5 test execution order does not matter.
- FTMO rolling analysis should deduplicate rerun rows using a stable key such as `manifold_id + test_id + symbol + ticket + trade_id + entry_type + deal_time`.
- Rank manifolds by pass rate first, median pass duration second, and average pass duration third.
- New challenge requirement source: `ftmo-challenge-requirements.md`. Evaluation-mode risk and trade frequency should be judged against `+10%` challenge followed by `+5%` verification before daily/global breach, with pass rate prioritized over raw speed. Funded-mode evaluation is separate and should target lower-risk `1% -> 3%` monthly profitability on aggregated funded capital.

Immediate next workflow:

- Define fixed IS filters.
- Define fixed validation filters.
- Define the deterministic scoring algorithm that selects exactly one manifold per symbol.
- Define the initial generator hyperparameter grid, including IS duration, validation duration, OOS deployment duration, rolling step size, validation survivor count, filters, thresholds, and ranking algorithms.
- Choose the initial symbol universe for the first full generator run.
- Prepare or revise runner scripts so they execute the per-symbol monthly generator process.
- Record OOS metrics by decay slice and cumulative horizon without using OOS to tune the same process version.

Active rolling-manifold workflow:

- Run MT5 genetic optimisation separately per symbol over the process version's IS window.
- Validate surviving candidates on the process version's validation window for the same symbol.
- Select exactly one frozen manifold per symbol using deterministic validation scoring.
- Advance the entire IS/VAL/OOS structure by the process version's rolling step size.
- Evaluate frozen OOS decay over the process version's OOS deployment/decay horizons.
- Treat the final score as generator performance across monthly deployment dates, not the best individual selected manifold.

Provisional FTMO grading:

| Grade | Pass rate | Median pass duration | Average pass duration |
| --- | ---: | ---: | ---: |
| `A` | `>= 90%` | preferred `<= 90 trading days` | secondary |
| `B` | `>= 85%` | warning if `> 90 trading days` | secondary |
| `C` | `>= 75%` | strong warning if `> 120 trading days` | secondary |
| Reject | `< 75%` | or severe breach/consistency risk | secondary |

Use `C` as the provisional minimum viable FTMO grade and `B` as the preferred minimum. Challenge and verification pass rates compound, while funded-stage payout does not require another `+10%` first-passage target. Also report unresolved starts separately because unresolved simulations tie up capital/time even if they do not fail.

## Documentation Files

- `architecture.md`: How the EA, indicator, and include files fit together.
- `session-start.md`: Lightweight session bootstrap file explaining which docs to read first and which large historical files to avoid by default.
- `ephemeral-manifold-generator.md`: Active research process for per-symbol monthly rolling discovery of disposable short-lived manifolds.
- `three-day-trend-signal.md`: Active strategy notes, marker mapping, and implementation sequence.
- `signal-flow.md`: Current signal and order placement flow.
- `ftmo-challenge-requirements.md`: Current pass-rate-first requirements for challenge-stage strategy generation and replay.
- `behavior-clusters.md`: Proposed symbol-specific parameter-family and trade-behavior cluster workflow for finding distinct strategy units.
- `discovery-findings.md`: Important findings, risks, and mismatches found during discovery.
- `open-questions.md`: Decisions that need clarification before larger changes.
- `experiment-log.md`: Legacy mixed running log of experiments and outcomes. Do not update it unless explicitly asked.
- `rolling-manifold-experiment-log.md`: Dedicated log for rolling short-horizon manifold rotation research.
- `ftmo-challenge-experiment-log.md`: Dedicated log for FTMO challenge-stage pass-rate-first research.
- `ftmo-funded-experiment-log.md`: Dedicated log for FTMO funded-stage survival, payout, and monthly-return research.
- `utils/README.md`: Reusable PowerShell utilities for parsing MT5 optimizer/forward XML files and fixed OOS `.xml.htm` reports.

## Discovery Date

- Discovery pass performed: 2026-06-03
