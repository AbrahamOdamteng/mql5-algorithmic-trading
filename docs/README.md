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

The intended deployment is multi-symbol: a single parameter manifold should eventually be tested across multiple symbols and symbol types, including FX, metals, and indices. If the same manifold performs acceptably across a diverse subset of markets, that is treated as stronger evidence of robustness than a single-symbol result.

The workflow is still sequential:

- First, make the manifold work on one symbol.
- Then, apply the same manifold to other symbols.
- Finally, evaluate aggregate portfolio behavior across the symbol set.

Low trade count on one symbol should not automatically reject a manifold if the manifold is intended for multi-symbol deployment. Instead, mark it as needing cross-symbol validation. A low-trade single-symbol result is still weak evidence by itself.

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
- Trade count should be evaluated in context. For a single-symbol test, low trade count weakens confidence. For the intended multi-symbol deployment, aggregate trade count across symbols is more important than per-symbol trade count alone.

Pre-CSV expanded-basket elimination filters:

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

## Documentation Files

- `architecture.md`: How the EA, indicator, and include files fit together.
- `signal-flow.md`: Current signal and order placement flow.
- `discovery-findings.md`: Important findings, risks, and mismatches found during discovery.
- `open-questions.md`: Decisions that need clarification before larger changes.
- `experiment-log.md`: Running log of experiments and outcomes. Do not update it unless explicitly asked.
- `utils/README.md`: Reusable PowerShell utilities for parsing MT5 optimizer/forward XML files and fixed OOS `.xml.htm` reports.

## Discovery Date

- Discovery pass performed: 2026-06-03
