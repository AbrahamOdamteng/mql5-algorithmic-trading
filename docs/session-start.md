# Session Start Context

Read this file first at the start of a new assistant session.

Do not echo file contents back to the user. After reading the required files, just confirm understanding unless the user asks for a summary.

## Required Reading For Current Work

Read these files first:

- `docs/README.md`
- `docs/three-day-trend-signal.md`
- `docs/open-questions.md`

For FTMO challenge or funded-account analysis, also read:

- `docs/ftmo-challenge-requirements.md`

For legacy rolling-manifold work, also read:

- `docs/behavior-clusters.md`
- `docs/rolling-manifold-experiment-log.md`

For code changes to the EA, indicator, signal logic, or logging, also read the relevant lightweight architecture files:

- `docs/architecture.md`
- `docs/signal-flow.md`
- `docs/discovery-findings.md`

For PowerShell utility work, also read:

- `docs/utils/README.md`

## Large Files To Avoid By Default

Do not read these whole files by default because they are large or historical:

- `docs/experiment-log.md`

Only read `docs/experiment-log.md` if the user asks about legacy experiments, OANDA `OANDA-EURXAU-P2012`, old optimizer results, or historical decisions that are not captured in the current lightweight files. Prefer targeted `grep` searches or line-range reads instead of reading the whole file.

## Experiment Logs By Topic

Use the focused log that matches the task:

- Rolling short-horizon manifolds: `docs/rolling-manifold-experiment-log.md`
- FTMO challenge-stage pass-rate-first research: `docs/ftmo-challenge-experiment-log.md`
- FTMO funded-stage survival and payout research: `docs/ftmo-funded-experiment-log.md`
- Legacy mixed WeekHighLow and OANDA history: `docs/experiment-log.md`

## Current Main Research Direction

The current active strategy direction is the Three Day Trend Signal strategy from the PineScript indicator in the terminal common files folder.

The previous day/week high-low strategy and the rolling-manifold branch are legacy research unless the user explicitly asks to revisit them.

Current implementation process:

1. Implement the PineScript strategy in MQL5 incrementally.
2. Draw chart markers first and do not place trades initially.
3. Implement ATR momentum candle markers first.
4. Add relative volume markers next.
5. Add the daily trend filter and final signal triangles after visual marker behavior is confirmed.
6. Add trade logic only after explicit user approval.

Current MQL5 state: `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5` implements ATR momentum candle markers only, compiles cleanly, and places no trades.
