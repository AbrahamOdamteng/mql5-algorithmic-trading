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

## Documentation Files

- `architecture.md`: How the EA, indicator, and include files fit together.
- `signal-flow.md`: Current signal and order placement flow.
- `discovery-findings.md`: Important findings, risks, and mismatches found during discovery.
- `open-questions.md`: Decisions that need clarification before larger changes.
- `experiment-log.md`: Running log of experiments and outcomes. Do not update it unless explicitly asked.

## Discovery Date

- Discovery pass performed: 2026-06-03
