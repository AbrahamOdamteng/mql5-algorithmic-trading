# Week High Low Project Notes

This directory captures working knowledge for the WeekHighLow EA and indicator so future sessions can quickly recover project context.

## Primary Files

- `Experts/WeekHighLow/WeekHighLowEA.mq5`: Expert Advisor that warms up historical bars, detects signals on new closed bars, and places pending orders.
- `Indicators/WeekHighLow/WeekHighLowIndicator.mq5`: Chart indicator that draws levels and signal markers.
- `Include/WeekHighLows/`: Shared data structures, period detection, level detection, signal logic, circular buffers, and drawing helpers.
- `Experts/WeekHighLow/EA_Utils.mqh`: EA order placement, lot sizing, comments, and strategy helper functions.
- `Experts/WeekHighLow/TradeLogger.mqh`: CSV trade logging support, currently compiled in but inactive from the EA.

## Strategy Intent As Discovered

The project appears to track previous period highs and lows, measure impulse and pullback behavior around those levels, detect continuation-style setups, and place pending breakout orders around the detected level.

The current code creates levels on weekly boundaries using `PERIOD_W1`.

## Current Goal

The practical goal is to develop an EA configuration that can help pass an FTMO-style challenge.

Goal realignment set on `2026-06-14`: the project now separates FTMO evaluation mode from funded-account mode. The evaluation/challenge strategy does not need to be the same as the funded strategy.

Evaluation mode is an account-acquisition engine. It may accept a high challenge-failure rate if the expected challenge-fee cost per successfully funded account remains economically reasonable. The practical challenge target is to reach the FTMO `+10%` target before daily/global breach, preferably in roughly `20 -> 30` trading days and with `40` trading days treated as the current upper acceptable limit. This is not a strict calendar-day target; weekend market closures mean both trading days and calendar days should be reported.

Funded mode is a capital-preservation and extraction engine. After funded status, the target is not another fast `+10%` first-passage objective. The intended funded-account goal is lower-risk survival and steady extraction of roughly `1% -> 3%` monthly, eventually scaled across additional accounts toward about `1,000,000` in funded capital.

This goal realignment does not delete the older robustness goals. The fixed-manifold and symbol-specific behavior-cluster workflows remain useful, but their outputs should be evaluated separately for challenge mode and funded mode.

The intended deployment is multi-symbol: a single parameter manifold should eventually be tested across multiple symbols and symbol types, including FX, metals, and indices. If the same manifold performs acceptably across a diverse subset of markets, that is treated as stronger evidence of robustness than a single-symbol result.

New research extension: a symbol-specific behavior-cluster workflow is also being considered. Instead of requiring one global manifold to work across all symbols, each symbol may earn inclusion by showing multiple distinct profitable behavior clusters. A live portfolio would then be built from `symbol + behavior cluster` strategy units, with one random or median representative chosen from each accepted cluster. This is documented in `behavior-clusters.md` and does not delete or replace the older fixed-manifold workflow.

Current cross-symbol candidate-promotion workflow:

- Use the EURUSD genetic backtest as the candidate generator.
- Select the top `N` EURUSD candidates for fixed cross-symbol screening.
- Run those top `N` candidates across the target symbol basket in in-sample plus validation.
- Define `S*` as the subset that succeeds across the cross-symbol in-sample plus validation screen.
- Run only `S*` in OOS.
- Define `S^` as the subset of `S*` that also passes OOS.
- Keep only `S^` for portfolio-level review and later FTMO/funded analysis.

Low trade count on one candidate should not automatically reject it. Do not eliminate individual candidates only because they have fewer than `100` trades. Evaluate trade frequency using the aggregate trade count of the final OOS-passing subset `S^`.

## Test Plan

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

Backtest acceptance criteria:

- In-sample profit must be greater than `0`.
- Validation profit must be greater than `0`.
- Out-of-sample profit must be greater than `0`.
- Equity drawdown must be less than `20%` in every test period.

Current ratio-based review criteria:

- Profit must be greater than `0` in every period.
- Profit-to-drawdown ratio should be greater than `2.0` in every period.
- Raw equity drawdown should remain capped, currently using `30%` as a diagnostic cap.
- Trade count should be evaluated at the subset/portfolio level. Individual candidates are not eliminated only because they have fewer than `100` trades; the aggregate trade count of the final OOS-passing subset `S^` is the relevant frequency gate.

Legacy pre-CSV expanded-basket elimination filters:

- These were frozen for the earlier full fixed-manifold expanded-basket workflow. The current EURUSD-generated `S*` -> `S^` workflow uses aggregate trade count on `S^` instead of per-candidate trade-count elimination.
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
- As of `2026-06-14`, rank challenge-mode candidates by `+10%` first-passage before breach, with preferred pass speed around `20 -> 30` trading days and an upper acceptable limit of `40` trading days. Report calendar days as a secondary operational metric.
- Because challenge mode is allowed to be an account-acquisition engine, also estimate expected challenge-fee cost per funded account and losing-streak risk, not only pass rate.
- Evaluate funded mode separately at lower risk, targeting `1% -> 3%` monthly with low breach probability and payout survival.
- Modify the CSV trade logger to write enough identity metadata to analyze each manifold independently: `manifold_id`, `test_id`, existing symbol/deal/trade fields, timestamps, P/L, and risk percentage.
- Write one CSV per manifold, appending rows as symbol/segment tests complete. Analysis should sort by `deal_time`, so MT5 test execution order does not matter.
- FTMO rolling analysis should deduplicate rerun rows using a stable key such as `manifold_id + test_id + symbol + ticket + trade_id + entry_type + deal_time`.
- Rank manifolds by pass rate first, median pass duration second, and average pass duration third.
- New speed target: challenge plus verification should complete within `90` calendar days. Evaluation-mode risk and trade frequency should be judged against `+10%` challenge followed by `+5%` verification before daily/global breach. Funded-mode evaluation is separate and should target lower-risk `1% -> 3%` monthly profitability on aggregated funded capital.

Immediate next workflow:

- Review the latest EURUSD genetic backtest results and select top `N` candidates.
- Generate fixed-test presets/configs for those top `N` candidates across the target symbol basket.
- Run cross-symbol in-sample plus validation first, then form `S*` from successful candidates.
- Run OOS only for `S*`, then form `S^` from OOS-passing candidates.
- Evaluate aggregate trade count and portfolio suitability on `S^`, not by applying a per-candidate `< 100` trade elimination rule.

Provisional FTMO grading:

| Grade | Pass rate | Median pass duration | Average pass duration |
| --- | ---: | ---: | ---: |
| `A` | `>= 90%` | `<= 90 days` | `<= 120 days` |
| `B` | `>= 85%` | `<= 120 days` | `<= 150 days` |
| `C` | `>= 80%` | `<= 180 days` | `<= 240 days` |
| Reject | `< 80%` | or too slow | or too slow |

Use `C` as the provisional minimum viable FTMO grade and `B` as the preferred minimum. Challenge and verification pass rates compound, while funded-stage payout does not require another `+10%` first-passage target. Also report unresolved starts separately because unresolved simulations tie up capital/time even if they do not fail.

## Documentation Files

- `architecture.md`: How the EA, indicator, and include files fit together.
- `signal-flow.md`: Current signal and order placement flow.
- `behavior-clusters.md`: Proposed symbol-specific parameter-family and trade-behavior cluster workflow for finding distinct strategy units.
- `discovery-findings.md`: Important findings, risks, and mismatches found during discovery.
- `open-questions.md`: Decisions that need clarification before larger changes.
- `experiment-log.md`: Running log of experiments and outcomes. Do not update it unless explicitly asked.
- `utils/README.md`: Reusable PowerShell utilities for parsing MT5 optimizer/forward XML files and fixed OOS `.xml.htm` reports.

## Discovery Date

- Discovery pass performed: 2026-06-03
