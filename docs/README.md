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

## Test Plan

- `2000 -> 2012`: In-sample period, tested by the MT5 optimizer.
- `2012 -> 2018`: Validation period, tested by MT5 optimizer forward testing.
- `2018 -> 2026`: Out-of-sample period, tested by a separate MT5 backtest.

Backtest acceptance criteria:

- In-sample profit must be greater than `0`.
- Validation profit must be greater than `0`.
- Out-of-sample profit must be greater than `0`.
- Equity drawdown must be less than `20%` in every test period.

## Documentation Files

- `architecture.md`: How the EA, indicator, and include files fit together.
- `signal-flow.md`: Current signal and order placement flow.
- `discovery-findings.md`: Important findings, risks, and mismatches found during discovery.
- `open-questions.md`: Decisions that need clarification before larger changes.
- `experiment-log.md`: Running log of experiments and outcomes. Do not update it unless explicitly asked.

## Discovery Date

- Discovery pass performed: 2026-06-03
