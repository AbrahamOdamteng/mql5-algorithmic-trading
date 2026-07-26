# Session Start Context

Read this file first at the start of a new assistant session.

Do not echo file contents back to the user. After reading the required files, just confirm understanding unless the user asks for a summary.

## Required Reading For Current Work

Read these files first:

- `docs/README.md`
- `docs/three-day-trend-signal.md`
- `docs/ephemeral-manifold-generator.md`
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

The current active strategy implementation is the Three Day Trend Signal strategy from the PineScript indicator in the terminal common files folder.

The current active research direction is the Ephemeral Manifold Generator. The generator/pipeline is the product; selected manifolds are disposable. The baseline process is per-symbol, monthly rolling `36`-month IS plus `3`-month validation, deterministic selection of exactly one frozen manifold per symbol, and a single `3`-month OOS measurement. Alpha-decay slices are disabled for the current run. These are generator hyperparameters to test empirically, not settled optimal values.

The previous day/week high-low strategy and the rolling-manifold branch are legacy research unless the user explicitly asks to revisit them.

Current implementation process:

1. Implement the PineScript strategy in MQL5 incrementally.
2. Draw chart markers first and do not place trades initially.
3. Implement ATR momentum candle markers first.
4. Relative volume markers have been added using tick volume.
5. Trade logic currently executes only when ATR momentum and RelVol occur together, producing square markers.
6. Add the daily trend filter and final signal triangles after visual marker behavior is confirmed.

Current MQL5 state: `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5` implements ATR momentum candle markers, relative volume markers using tick volume, and optional market orders only when ATR momentum and relative volume occur together, producing square markers. Blue/red momentum-only circles and orange RelVol-only diamonds do not trade. Trade sizing uses fixed starting-balance risk via `g_StartingBalance=100000.0` and `g_RiskPercentOfBalance=1.0` by default, not fixed lots. Daily trend filter and final long/short signal triangles are not implemented yet.

Latest compile status: after square-only trade gating was added, MetaEditor compiled `ThreeDayTrendSignalEA.mq5` with `0 errors, 0 warnings`.

Latest EURUSD generator note: first six windows of `tdts_eg_eurusd_2017_is36m_val3m_oos3m_step1m` tested multiple validation selection modes. Current best is `PositiveLowestTrades`, with `3 / 6` profitable OOS windows, net OOS `+9,214.41`, worst DD `22.65%`, and `465` trades. Later OOS starts from `2020.10.01` through `2020.12.01` remain weak across modes.

Important testing note: the `2026-07-18` EURUSD H1 genetic results in `docs/experiment-log.md` used the older fixed `0.10` lot sizing and predate RelVol plus square-only trade gating. Treat those rankings as superseded historical evidence.

Latest rolling-manifold testing note: `tdts_rm_2018_5y_1y_1y` belongs to the older EURUSD-discovery plus cross-symbol-promotion framing. Keep it as historical evidence only. Future rolling research should use the per-symbol ephemeral-generator process in `docs/ephemeral-manifold-generator.md` unless the user explicitly asks to revisit the older branch.
